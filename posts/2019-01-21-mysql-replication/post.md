MySQL设置Replication后，可以支持Master库上的修改自动同步到Slave库上。利用Docker可以在本机尝试这种特性。


# 配置Master
首先需要创建几个文件夹（略），用来挂载配置文件和数据。我们首先来配置Master库：

```ini
# master/cnf/my.cnf
[mysqld]

server-id=1
log-bin=/var/lib/mysql/mysql-bin.log
binlog_format=MIXED
expire_logs_days=7
max_binlog_size=50m
max_binlog_cache_size=256m
```

启动Master：

```bash
docker run --name mysql_master \
    --mount type=bind,src=/Users/hfli/mysql-replication/master/cnf/my.cnf,dst=/etc/my.cnf \
    --mount type=bind,src=/Users/hfli/mysql-replication/master/data/,dst=/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=1125482715 \
    -d mysql:5.7.24
```

然后需要登录到MySQL创建一个用来复制的用户

```mysql
create user 'replication' identified by '1153687060';
grant replication slave on *.* to 'replication'@'%' identified by '1153687060';
```

接下来需要看一下Master库的状态:

```
mysql> show master status;
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000003 |      696 |              |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
1 row in set (0.00 sec)
```

# 从库配置

```ini
# slave1/cnf/my.cnf
[mysqld]

server-id=2
```
启动docker：

```bash
docker run --name mysql_slave1 \
    --mount type=bind,src=/Users/hfli/mysql-replication/slave1/cnf/my.cnf,dst=/etc/my.cnf \
    --mount type=bind,src=/Users/hfli/mysql-replication/slave1/data/,dst=/var/lib/mysql \
    --link mysql_master \
    -e MYSQL_ROOT_PASSWORD=1125482715 \
    -d mysql:5.7.24
```

然后即可启动Replication:

```
mysql> change master to master_host='mysql_master',master_user='replication',master_password='1153687060',master_log_file='mysql-bin.000003',master_log_pos=696;
Query OK, 0 rows affected, 2 warnings (0.03 sec)

mysql> start slave;
Query OK, 0 rows affected (0.00 sec)

mysql> show slave status\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: mysql_master
                  Master_User: replication
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000003
          Read_Master_Log_Pos: 696
               Relay_Log_File: c17b953fb671-relay-bin.000002
                Relay_Log_Pos: 320
        Relay_Master_Log_File: mysql-bin.000003
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 0
                   Last_Error:
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 696
              Relay_Log_Space: 534
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File:
           Master_SSL_CA_Path:
              Master_SSL_Cert:
            Master_SSL_Cipher:
               Master_SSL_Key:
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Master_Server_Id: 1
                  Master_UUID: 83a0a667-1d50-11e9-b754-0242ac110002
             Master_Info_File: /var/lib/mysql/master.info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Master_SSL_Crl:
           Master_SSL_Crlpath:
           Retrieved_Gtid_Set:
            Executed_Gtid_Set:
                Auto_Position: 0
         Replicate_Rewrite_DB:
                 Channel_Name:
           Master_TLS_Version:
1 row in set (0.00 sec)
```

一个有趣的问题：如果我修改了从库，会产生什么影响？例如已经有重复的数据，那么同步的时候就会报错，我们通过Last_Error可以看到错误。

```
 Last_Errno: 1062
 Last_Error: Error 'Duplicate entry '2' for key 'PRIMARY'' on query. Default database: 'foo'. Query: 'INSERT INTO `foo`.`bar` (`id`, `remark`) VALUES ('2', 'existing')'
```