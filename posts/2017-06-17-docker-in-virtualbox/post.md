几年前在公司复杂维护机房的时候，就开始关注Docker这种基于容器的虚拟化技术了，当时并没有选择Docker，因为几年前docker刚起步还不是很成熟，不敢采用这样的技术（当然关键是自己不了解也能力不够）。当时采取的是KVM和Virtual Box，问题也很明显，因为一台物理机（Dell T320 32GRAM)开个四五台Virtual Box虚拟机就有点吃不消了，想做到专机专用，也是很困难的事情。当时的主要目的是想把Oracle、WebSphere等吃内存的东西隔离出来。

现在有机会接触到Docker了，有必要认真的学习下了。貌似在Mac上Docker实际上是运行在虚拟的Linux中的，因此决定使用虚拟机来运行Docker，以下是我的配置：

* Mac Book Pro, OSX
* Virtual Box, Ubuntu-server 16.04.2 X64 LTS, 4G Ram, 30G HDD，网卡桥接

好了，首先是安装Docker，参考[官方文档](https://docs.docker.com/engine/installation/linux/ubuntu/#install-docker)

```bash
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install docker-ce
```
好了，这样就安装成功了。来下载一些[docker镜像](https://hub.docker.com/)吧，我们在后面可能慢慢会用到（先这样设想吧）：

* oracle/openjdk:8 选用Oracle的JDK8镜像来部署SpringBoot应用
* gitlab/gitlab-ce 用来搭建私有的GIT仓库
* sonatype/nexus3 用来搭建私有的Docker镜像库
* gocd/gocd-server 用来搭建gocd作CICD
* node 用来运行NodeJS的前端
* percona 用来提供MySQL服务
* mongo 用来提供MongoDB服务

```bash
docker pull oracle/openjdk
docker pull gitlab/gitlab-ce
docker pull sonatype/nexus3
docker pull gocd/gocd-server
docker pull node
docker pull percona
docker pull mongo
```
你会发现太慢了，是不是?幸好可以有加速的方式，可以试用[DaoCloud](https://www.daocloud.io/mirror#accelerator-doc)的加速器。
```bash
sudo vim /etc/docker/daemon.json
```
输入以下内容:
```json
{
    "registry-mirrors": [
        "http://1729****.m.daocloud.io"
    ],
    "insecure-registries": []
}
```
重启Docker：
```bash
sudo /etc/init.d/docker restart
```