Accroding to the mysql manual, the binary log( also known as binlog) is a very powerful feature that enables the recording of "events" that describe database changes. Those changes could be table modification or data change, and may also contain some statements which may potentially made changes such as `DELETE` which no matched items.

This kind of feature enables mysql in replication from master to slave servers by sending events contained in binlogs, and also data recovery. Except for that, it could also be used in CDC(change-data-capture) since it's event based, an example usage could be found in the cdc-component in [Eventuate™](https://eventuate.io/).



# binary log configuration

## enable mysql binlog

By default the binlog feature is not enabled by mysql, we can enable this by adding the following settings to `my.cnf` file:

```ini
[mysqld]
log-bin=mysql-bin
server_id=1
```

Since MySQL5.7, the `server_id` must be specified if binlog is enabled, and this value should be unique among the cluster. Then we can find binlog like the following:

```
mysql> show binary logs;
+------------------+-----------+
| Log_name         | File_size |
+------------------+-----------+
| mysql-bin.000001 |       154 |
+------------------+-----------+
1 row in set (0.00 sec)
```

## binlog format

There are 3 kinds of binlog format supported by mysql:

* STATEMENT: statement-based logging
* ROW: row-based logging
* MIXED: in mixed mode

By default, the statement-based binlog format is used, and that could be changed by settings:

```ini
[mysqld]
log-bin=mysql-bin
server_id=1
binlog_format="ROW"
```

But be aware that the statement-based binlog may cause inconsistency in replication, accroding to the warning in mysql manual:

> When using statement-based logging for replication, it is possible for the data on the master and slave to become different if a statement is designed in such a way that the data modification is nondeterministic; that is, it is left to the will of the query optimizer. In general, this is not a good practice even outside of replication. 

So in general maybe it's better to use row-based logging, however that could result in larger binlog files.

# events in binlog

## View events in binlog

We can show the events contained in binlog use `show binlog events` command:

```
mysql> show binlog events in 'mysql-bin.000001';
+------------------+-----+----------------+-----------+-------------+---------------------------------------+
| Log_name         | Pos | Event_type     | Server_id | End_log_pos | Info                                  |
+------------------+-----+----------------+-----------+-------------+---------------------------------------+
| mysql-bin.000001 |   4 | Format_desc    |         1 |         123 | Server ver: 5.7.30-log, Binlog ver: 4 |
| mysql-bin.000001 | 123 | Previous_gtids |         1 |         154 |                                       |
+------------------+-----+----------------+-----------+-------------+---------------------------------------+
2 rows in set (0.00 sec)
```

So let's try to find what happens when we do some operation in database. We'll create a new database and table, then insert a single record to the table by using the following commands:

```sql
create database test;
use test;
create table foo(
    id int not null primary key,
    remark varchar(100)
);
insert into foo(id, remark) values(1, 'hello world!');
```

After this we'll find the following events has been appended to the binlog:

```
| mysql-bin.000001 | 219 | Query          |         1 |         313 | create database test                                                             |
| mysql-bin.000001 | 313 | Anonymous_Gtid |         1 |         378 | SET @@SESSION.GTID_NEXT= 'ANONYMOUS'                                             |
| mysql-bin.000001 | 378 | Query          |         1 |         520 | use `test`; create table foo(
id int not null primary key,
remark varchar(100)
) |
| mysql-bin.000001 | 520 | Anonymous_Gtid |         1 |         585 | SET @@SESSION.GTID_NEXT= 'ANONYMOUS'                                             |
| mysql-bin.000001 | 585 | Query          |         1 |         657 | BEGIN                                                                            |
| mysql-bin.000001 | 657 | Table_map      |         1 |         706 | table_id: 116 (test.foo)                                                         |
| mysql-bin.000001 | 706 | Write_rows     |         1 |         760 | table_id: 116 flags: STMT_END_F                                                  |
| mysql-bin.000001 | 760 | Xid            |         1 |         791 | COMMIT /* xid=26 */                                                              |
+------------------+-----+----------------+-----------+-------------+----------------------------------------------------------------------------------+

```

## event types

As we already see, there are different kinds of events shown in binlog such as `Query` and `Table_map`. Actually there are many more types than that, here are parts of them:

Event type         Description
------------------ -------------------------------------------------
UNKNOWN_EVENT      never occurs
START_EVENT_V3     a descriptor at each begging of binlog, and is replaced by  FORMAT_DESCRIPTION_EVENT since MySQL 5.0
QUERY_EVENT        occurs when an updating statement is done
STOP_EVENT         occurs when mysqld stops
INTVAR_EVENT       occurs each time when a AUTO_INCREMENT field is used
TABLE_MAP_EVENT    map the table defination to a number, happens before row operations 
WRITE_ROWS_EVENT   insert records
UPDATE_ROWS_EVENT  update rows
DELETE_ROWS_EVENT  delete rows

For more detailed explaination about event types, please refer to [Event Meanings](https://dev.mysql.com/doc/internals/en/event-meanings.html).

References:

- [MySQL 5.7 Reference Manual - Replication and Binary Logging Options and Variables](https://dev.mysql.com/doc/refman/5.7/en/replication-options.html)
- [MySQL 5.7 Reference Manual - The Binary Log](https://dev.mysql.com/doc/refman/5.7/en/binary-log.html)