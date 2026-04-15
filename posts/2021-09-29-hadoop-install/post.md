作为一个从来没接触过大数据的小白，从0开始来学习一下Hadoop。首先是安装环境，官网给出了几种方式:

* Local (Standalone) Mode: 单机版的模式，运行在一个JVM进程
* Pseudo-Distributed Mode: 伪分布式模式，运行多个JVM进程来模拟分布式的环境
* Fully-Distributed Mode: 完全分布式部署在多台机器上

当然最理想的当然是真实的分布式部署了，在进行分布式部署之前，先来简单的单机版本部署一下，以便熟悉一下Hadoop相关的概念。



# 准备
## 环境安装
### VirtualBox
因为我们的目标是在本机实现分布式的部署，来模拟真实的集群环境，所以需要利用虚拟机来构建多个独立的系统。要做到这步有很多种方式，比如：

* KVM
* VirtualBox
* Multipass

其实我最开始尝试过Multipass，这货是Ubuntu推出的感觉比较新的样子，但是我用了一段时间之后莫名的出现了虚拟机无法启动的情况，可能跟MacOS兼容性还不是很好吧。所以比较靠谱和简单的选择是VirtualBox，不仅比较稳定（虽然在Mac上也遇到些Bug），而且还跨平台。

安装VirtualBox非常简单：

* ArchLinux: `sudo pacman -S virtualbox`
* Mac/Windows: 下直接下载二进制程序安装即可

### Vagrant
Virtualbox跟Docker这种容器平台相比一个劣势是系统的安装必须要从头开始。当然自己可以安装完成之后创建一个模板来复制虚拟机，终究比较麻烦。幸好有Vagrant这个工具可以帮助来管理虚拟机，可以快速的从仓库拉取镜像来创建一个虚拟机，以及自动化的配置多个机器、网络、安装脚本等，十分方便。

安装Vagrant:

* ArchLinux: `sudo pacman -S vagrant`
* Mac: `brew install vagrant
* Windows: 下直接下载二进制程序安装即可

安装完成之后，就可以用其来创建虚拟机了。它支持的所有镜像（它的术语叫box）可以在[公开仓库](https://app.vagrantup.com)中找到，后续我们将选用[Ubuntu 20.04 LTS官方版本](https://app.vagrantup.com/ubuntu/boxes/focal64)作为服务器基础镜像。

### 下载Hadoop
可以从[清华大学Hadoop镜像](https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop)下载Hadoop,当前最新的是[hadoop-3.3.1](https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-3.3.1/hadoop-3.3.1.tar.gz)。

## 系统安装

### 创建Ubuntu Server
利用Vagrant命令快速生成一个虚拟机：

```bash
mkdir hadoop-standalone
cd hadoop-standalone
vagrant init ubuntu/focal64
vagrant up
```

执行成功之后，就可以在VirtualBox中看到创建的这个虚拟机。然后可以通过Vagrant命令登录：

```bash
# 执行执行先cd到 hadoop-standalone 目录
vagrant status
vagrant ssh
```

### 安装必要软件
Hadoop运行在JVM之上，必须要安装Java环境。Hadoop 3.3+支持的Java版本是Java 8/Java 11，其中Java 11只支持运行而不支持编译。为简单起见，选择Java 8作为运行环境:

```bash
sudo apt-get update
sudo apt install openjdk-8-jdk
sudo apt-get install ssh
sudo apt-get install pdsh
```

### 配置SSH
需要配置ssh以便Hadoop可以无密码登录。
```bash
# 试一下是否能直接登录
ssh localhost

ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
```

### 拷贝文件到虚拟机

将hadoop文件上传到虚拟机中。也可以直接在虚拟机wget，这里主要考虑是为以后集群部署准备，避免多次下载。

```bash
vagrant upload ~/Downloads/hadoop-3.3.1.tar.gz
```

# 安装Hadoop
## 设置环境
```bash
tar -zxvf hadoop-3.3.1.tar.gz
cd hadoop-3.3.1
vim etc/hadoop/hadoop-env.sh

```
修改其中的JAVA_HOME环境变量：

```bash
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64

# 完成之后可以试一下
bin/hadoop
```

## 修改配置文件
修改下面这些配置文件（都是原样从官网抄的）：

etc/hadoop/core-site.xml:

```xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
```

etc/hadoop/hdfs-site.xml:

```xml
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
</configuration>
```

etc/hadoop/mapred-site.xml:

```xml
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
```

etc/hadoop/yarn-site.xml:

```xml
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>
    </property>
</configuration>
```

### 启动Hadoop

首先需要格式化hdfs

```bash
bin/hdfs namenode -format
```

启动：

```bash
sbin/start-dfs.sh
sbin/start-yarn.sh
```

启动之后，可以去访问Hadoop的站点（因为是在虚拟机里面，需要配置端口转发到宿主机）：

* ResourceManager - http://localhost:8088/
* NameNode - http://localhost:9870/

![ResourceManager](images/Hadoop-8088.png)


![NameNode](images/Hadoop-9870.png)

这样就算安装完成了。