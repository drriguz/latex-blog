OpenShift是红帽基于Docker和Kubernetes的云开发平台即服务（PaaS）。而[OKD(The Origin Community Distribution of Kubernetes )](https://www.okd.io/)即Openshift的开源版本。在本机上搭建一套完整的Openshift环境较为麻烦，有以下几种方式：

* Running in a Container
* Run the All-In-One VM with Minishift
* 使用Virtualbox构建Openshift集群



# 使用VirtualBox构建Openshift集群

按照[安装文档](https://docs.openshift.com/container-platform/3.11/install/index.html)应该可以在本地搭建一个集群，但是纯手动安装的话比较复杂，幸好有[Openshift Vagrant](https://github.com/eliu/openshift-vagrant)这个项目可以帮助我们简单的构建出一个集群环境。

## 集群规划

下面是计划搭建的最简单的单master、多node的一个集群配置：

Node                IP         Role               Instance
------------------- ---------- ------------------ ----------------
master.example.com  .100       node, master, etcd 4GMem, 2Core, 40GDisk
node1.example.com   .101       node               2GMem, 1Core, 40GDisk
node2.example.com   .102       node               2GMem, 1Core, 40GDisk

整个安装步骤可以分为这几步：

* 创建好master、node三个虚拟机
* 通过hosts文件设置好域名解析
* 在master、node上都安装docker依赖
* 配置在master上可以通过ssh访问到node01、node02
* 在master上安装ansible
* 在master上执行openshift-ansible部署openshift

## 定义虚拟机

如果手动从virtualbox安装虚拟机、再安装系统的话，需要耗费不少时间，通过Vagrant我们可以快速自动化地创建出这样的一个机器集群，类似从docker拉取image一样。定义这些只需要创建一个Vagrantfile：

```lua
Vagrant.configure("2") do |config|
    config.vm.box = "centos/7"
    config.vm.box_check_update = false

    config.vm.provider "virtualbox" do |vb|
        vb.memory = 2048
        vb.cpus = 1
    end

    config.vm.provision "shell", inline: <<-SHELL
        /vagrant/common.sh
    SHELL

    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.ignore_private_ip = false
  
    (1..2).each do |i|
        config.vm.define "node0#{i}" do |node|
            node.vm.network "private_network", ip: "#{NETWORK_BASE}#{i}"
            node.vm.hostname = "node0#{i}.example.com"
        end
	end
end
```

以上的配置定义了操作系统、内存和cpu，以及网络和域名设置，然后创建node01、node02。这里用到了vagrant的hostmanager插件，他会去修改宿主机以及虚拟机的hosts文件，增加域名映射。同时，可以把一些公共的依赖项安装脚本进行provision，例如安装docker。然后，还需要创建master节点：

```lua
config.vm.define "master", primary: true do |master|
        master.vm.network "private_network", ip: "#{NETWORK_BASE}0"
        # master.vm.hostname = "master.example.com"
        master.hostmanager.aliases = %w(master.example.com etcd.example.com nfs.example.com)
        master.vm.provider "virtualbox" do |vb|
            vb.memory = "4096"
            vb.cpus = 2
        end
end
```

创建了vagrantfile之后，就可以利用`vagrant up`命令来创建和启动这些虚拟机了。

![Virtualbox](images/Virtualbox-cluster.png)

这里master的域名配置有个坑，那就是hostnamanger会会生成一个master.example.com的ip映射在hosts文件里面，但是这个文件开头还有127.0.0.1 指向 master.example.com，像这样：

```lua
127.0.0.1       master.example.com      master
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

## vagrant-hostmanager-start
192.168.11.102  node02.example.com
192.168.11.100  master.example.com
192.168.11.101  node01.example.com
## vagrant-hostmanager-end
```

所以这里设置的`master.hostmanager.aliases`，同时要手动修改hostname：

```bash
hostnamectl set-hostname master.example.com
```

## 安装依赖项

各个节点上都需要安装docker环境，使用下面的命令安装：

```bash
yum -y install docker-1.13.1

# http://softpanorama.org/VM/Docker/Installation/rhel7_docker_package_dockerroot_problem.shtml

usermod -aG dockerroot vagrant

cat > /etc/docker/daemon.json <<EOF
{
    "group": "dockerroot"
}
EOF

systemctl enable docker
systemctl start docker
 ```

同时需要禁用掉SELinux：

```bash
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
```

而在master上需要装更多的依赖项：

```bash
yum install wget git net-tools bind-utils yum-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct

yum install unzip

yum -y install https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ansible-2.9.6-1.el7.ans.noarch.rpm
```

这里安装依赖项之前，可以考虑将Base源替换为163源，这样速度会稍微快一点。

## 配置ssh访问

应为整个集群安装是在master上进行的，但实际上有一些东西是需要操作node的，因此要配置好在master上能直接无密码登录到其他的node上。这里通过ssh私钥的形式来设置，首先在Vagrantfile中:

```lua
if File.exist?(".vagrant/machines/master/virtualbox/private_key")
    master.vm.provision "master-key", type: "file", source: ".vagrant/machines/master/virtualbox/private_key", destination: "/home/vagrant/.ssh/master.key"
end
if File.exist?(".vagrant/machines/node01/virtualbox/private_key")
    master.vm.provision "node01-key", type: "file", source: ".vagrant/machines/node01/virtualbox/private_key", destination: "/home/vagrant/.ssh/node01.key"
end
if File.exist?(".vagrant/machines/node02/virtualbox/private_key")
    master.vm.provision "node02-key", type: "file", source: ".vagrant/machines/node02/virtualbox/private_key", destination: "/home/vagrant/.ssh/node02.key"
end
```
然后通过下面的命令将文件拷贝过去：

```bash
vagrant provision --provision-with master-key,node01-key,node02-key
```

这一步的目的是因为Vagrant在创建这些node的时候，这个key还没有生成，只能在创建完之后才能成功拷贝过去。然后设置master的ssh配置：

```bash
# vagrant ssh master
#vim ~/.ssh/config
Host *
StrictHostKeyChecking no
```

到这一步，docker、ssh访问都应该是成功的，如果想检查是否配置成功，可以在master上测试：
```bash
vagrant ssh master
docker -v
ssh -i node01.key vagrant@node01.example.com
```

## 创建Inventory

通过ansible执行需要一个hosts文件，如下：

```ini
[OSEv3:children]
masters
nodes
etcd

[OSEv3:vars]
ansible_ssh_user=vagrant
ansible_become=true
openshift_deployment_type=origin
openshift_disable_check=disk_availability,memory_availability,docker_storage,docker_image_availability

[masters]
master.example.com ansible_ssh_private_key_file="/home/vagrant/.ssh/master.key"

[etcd]
master.example.com ansible_ssh_private_key_file="/home/vagrant/.ssh/master.key"

[nodes]
master.example.com containerized=false etcd_ip=192.168.11.100 openshift_node_group_name='node-config-master-infra'  ansible_ssh_private_key_file="/home/vagrant/.ssh/master.key"
node01.example.com openshift_node_group_name='node-config-compute' ansible_ssh_private_key_file="/home/vagrant/.ssh/node01.key"
node02.example.com openshift_node_group_name='node-config-compute' ansible_ssh_private_key_file="/home/vagrant/.ssh/node02.key"

```

这里有几点坑：
* `containerized=false etcd_ip=192.168.11.100 `这个如果不加会导致["Wait for control plane pods to appear" ](https://github.com/eliu/openshift-vagrant/issues/10)错误

这个文件保存到/etc/ansible/hosts。

## 安装

在master上面安装ansible:

```bash
yum -y install https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ansible-2.9.6-1.el7.ans.noarch.rpm
wget https://github.com/openshift/openshift-ansible/archive/openshift-ansible-3.11.187-1.zip
```

然后，最好把openshift-ansible里面的mirror修改成国内的，否则很可能安装不成功或者要花很长时间：

```bash
sed -i 's/mirror.centos.org/mirrors.163.com/g' openshift-ansible/roles/openshift_repos/templates/CentOS-OpenShift-Origin311.repo.j2
```

正是安装：

```bash
ansible-playbook /home/vagrant/openshift-ansible/playbooks/prerequisites.yml && ansible-playbook /home/vagrant/openshift-ansible/playbooks/deploy_cluster.yml
```

如果一切正常的话，就可以安装成功了。其中有几步比较耗时(大概十分钟左右），需要点耐心：

```
TASK [openshift_node : Install node, clients, and conntrack packages]
TASK [openshift_node : Check status of node image pre-pull]
```

成功之后，可以看到log：

```
PLAY RECAP ***********************************************************************************************************
localhost                  : ok=11   changed=0    unreachable=0    failed=0    skipped=5    rescued=0    ignored=0
master.example.com         : ok=622  changed=275  unreachable=0    failed=0    skipped=987  rescued=0    ignored=0
node01.example.com         : ok=130  changed=63   unreachable=0    failed=0    skipped=167  rescued=0    ignored=0
node02.example.com         : ok=130  changed=63   unreachable=0    failed=0    skipped=167  rescued=0    ignored=0


INSTALLER STATUS *****************************************************************************************************
Initialization               : Complete (0:00:18)
Health Check                 : Complete (0:00:04)
Node Bootstrap Preparation   : Complete (0:34:23)
etcd Install                 : Complete (0:00:32)
Master Install               : Complete (0:07:48)
Master Additional Install    : Complete (0:00:34)
Node Join                    : Complete (0:06:56)
Hosted Install               : Complete (0:00:56)
Cluster Monitoring Operator  : Complete (0:02:47)
Web Console Install          : Complete (0:01:45)
Console Install              : Complete (0:01:21)
Service Catalog Install      : Complete (0:07:53)
```

然后就可以访问` https://master.example.com:8443/`了：

![Openshift home](images/Openshift-welcome.png)

Reference:
* [OpenShift 3.9 多节点集群（Ansible）安装](https://blog.csdn.net/sun_qiangwei/article/details/80443943)