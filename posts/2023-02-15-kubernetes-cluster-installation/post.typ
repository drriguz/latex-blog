#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Kubernetes集群安装纪要",
  date: "2023-02-15",
  tags: ("云计算", "容器化"),
  lang: "zh",
)

以前基本上是在本地开发，
因此使用minikube之类的轻量级kubernetes环境十分方便。
但现在需要在真实的服务器上部署， 因此有机会体验一番，
实际感受是------比想象的要简单！

= 环境准备
<环境准备>
== 系统要求
<系统要求>
本次安装以Ubuntu 22.04.2为基础，
在分区时，特意给`/var`分区预留了较大的空间，
因为考虑到docker容器运行会需要缓存较多镜像之类。

Kubernetes集群安装要求机器关闭`/swap`分区，
由于本次安装系统时直接未启用swap，
因此不需要额外处理。若系统启用了swap分区， 需要进行禁用方可安装。

```bash
sudo swapoff  -a
sudo vim /etc/fstab # 注释掉swap相关的行
```

== 配置系统参数
<配置系统参数>
系统参数需要进行一些必要的配置：

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

其中，由于 修改完成后，确保其生效：

```bash
lsmod | grep br_netfilter
lsmod | grep overlay
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

正常情况下看到的应该类似下面这样的结果：

```
$ lsmod | grep br_netfilter
br_netfilter           32768  0
bridge                307200  1 br_netfilter
$ lsmod | grep overlay
overlay               151552  0
$ sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

== 安装containerd
<安装containerd>
在准备安装为Kubernetes的节点上各自执行以下命令，
安装containerd作为容器运行时：

```bash
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```

安装完成后，需要修改containerd配置文件（/etc/containerd/config.toml），使用systemd初始化一个默认配置文件并修改：

```bash
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

由于gcr镜像在国内无法下载，需要修改其中的一个镜像，
这里使用DockerHub上的镜像， 同时，需要修改`SystemdCgroup`为`true`：

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true

sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.6"
```

修改后，重启containerd：

```bash
sudo systemctl restart containerd
```

= 使用kubeadm安装Kubernetes
<使用kubeadm安装kubernetes>
== 安装kubeadm
<安装kubeadm>
在各个节点上均执行以下命令安装：

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl

curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -

sudo echo "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt-get install -y kubelet=1.25.6-00 kubeadm=1.25.6-00 kubectl=1.25.6-00
sudo apt-mark hold kubelet kubeadm kubectl
```

其中，指定了使用kubectl 1.25.6版本并通过`apt-mark`固定住版本，
是因为kubelet这些工具版本默认会使用最新的， 这里固定是项目所要求的。

== 创建Kubernetes集群
<创建kubernetes集群>
在master节点上执行以下命令：

```bash
sudo systemctl start kubelet
sudo systemctl enable kubelet

MASTER_IP="xx.xx.xx.xx"
NODENAME=$(hostname -s)
POD_CIDR="192.168.0.0/16"
KUBERNETES_VERSION="v1.25.6"

sudo kubeadm init \
  --image-repository=registry.aliyuncs.com/google_containers \
  --pod-network-cidr=$POD_CIDR \
  --kubernetes-version $KUBERNETES_VERSION \
  --apiserver-advertise-address $MASTER_IP \
  --node-name $NODENAME
```

其中`MASTER_IP`为其IP地址，该地址似乎不支持域名的方式。
注意必须要确保docker、kubelet服务已经启动。 否则，很可能会安装失败，
如果安装失败， 则可以删除之后， 重新开始：

```bash
sudo kubeadm reset
sudo rm -rf ~/.kube
```

== 生成Config
<生成config>
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

== 部署CNI插件
<部署cni插件>
部署Calico CNI插件：

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
```

注意这里需要用`create`而不是`apply`，
因其大小较大，apply方式限制`Too long: must have at most 262144 byte`。
安装后，等待其创建完成：

```bash
watch kubectl get pods -n calico-system
```

完成后，移除master节点上的污点：

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node-role.kubernetes.io/master-
```

== 添加worker节点
<添加worker节点>
在各个其他节点上执行：

```bash
sudo systemctl start kubelet
sudo systemctl enable kubelet
```

使用master节点的输出的命令来加入到集群中， 例如：

```bash
sudo kubeadm join xx.xx.xx.xx:6443 --token xnc87j.ia5dfxv418kxo6io \
        --discovery-token-ca-cert-hash sha256:ea1f579ffc8023522f571ac6bba52e05b5997c359e1b244d827932d56fee57cd \
        --node-name=k8s-worker
```

其中，可以通过`--node-name=k8s-worker`参数指定节点名称。
至此，安装完成。
