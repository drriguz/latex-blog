Knative是一个开源的Serverless平台，它实现了一套架构无关的Serverless系统。本文介绍其安装及入门使用。


# 安装Knative

## Option 1：使用Docker Desktop + minikube + quickstart

体验Knative时，首先需要在本机进行安装。基于以下的环境进行安装：

* Windows 11
* Docker Desktop
* minikube

之所以这样选择，是因为首先Docker Desktop最为流行，minikube（以及kind）是Knative/Tekton官方例子中推荐的选择，因此肯定是兼容的。之前更多时候我青睐于k3s，因为k3s是真正的production-ready的轻量级k8s版本，但是因为Knative有单独的网络层，在k3s上安装时需要特别处理一下，考虑到复杂性还是用minikube吧。minikube必须要Docker或者其他的运行时支持。

```bash
# 先启动docker desktop
minikube start
```

minikube启动时会下载一些镜像，因此如果没有翻墙很可能下载不了。另外有时候会出现卡死的情况，
解决方式是，删掉重新来过：

```bash
minikube delete
rm -rf ~/.minkube
minikube start
```

### 使用quickstart插件安装Knative

Knative支持一种叫quickstart的插件安装机制，可以比较方便的开启一个本地环境。完整的安装过程可以参考[官方文档](https://knative.dev/docs/getting-started/quickstart-install/)，仅列出安装的文件：

* kn.exe
* kn-func.exe
* kn-quickstart.exe

这些都需要加入到系统Path之中。然后运行安装：

```bash
kn quickstart minikube
```

这一步后还需要执行一个命令，并保证其始终运行（可以单独开一个Terminal窗口执行）：

```bash
minikube tunnel --profile knative
```

安装成功后，应该可以能够列出Knative profile:

```bash
minikube profile list
```

![](images/Knative-profile.png)

## Option 2：使用WSL2 + Docker（Linux） + minikube安装（推荐）
使用Docker Desktop有一个不好的地方是，容器不能直接在宿主机上访问，
因此直接在Linux中部署Docker和Minikube是不能直接访问到k8s的host上的。
所以直接在WSL中安装docker和minikube，这样可以更容易使用。

### 安装Docker

```bash
sudo apt-get update
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

sudo service docker start
```

注意WSL2默认不支持Systemd，因此只能使用service xx start/stop方式启动和停止。

### 安装Kubectl

```bash
sudo apt-get install -y apt-transport-https
sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl
```

### 安装Minikube
选择Minikube作为本地Kubernetes开发有以下优点：

* 跨平台支持（Windows/Mac/Linux）
* 默认支持K8s的基本特性，如Service、Ingress、PV、LB等
* 支持创建多个集群
* 支持Nvidia GPU，对机器学习友好

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb
```

注意：Minikube依赖Docker 服务，必须启动起来。

### 创建K8s集群

```bash
minikube start -p kfaas-cluster \
    --memory=8192 \
    --cpus=6 \
    --driver=docker \
    --kubernetes-version=v1.25.6 \
    --disk-size=50g \
    --insecure-registry='10.0.0.0/24'
```

### 启用Registry插件

```bash
minikube -p kfaas-cluster addons enable registry
```

### 创建和配置默认的Namespace
至此，Kubernetes部署完成，可以创建一个Namespace用来进行开发测试用，并配置为默认的命名空间，例如：

```bash
kubectl create namespace develop
kubectl config set-context --current --namespace=develop
```

### 安装Knative

CRD定义是安装Knative Serving或者Knative Eventing的依赖项，因此需要先安装。

```bash
kubectl apply \
  --filename https://github.com/knative/serving/releases/download/knative-v1.9.0/serving-crds.yaml \
  --filename https://github.com/knative/eventing/releases/download/knative-v1.9.0/eventing-crds.yaml
```
完成后，可以查看已经安装的API版本，例如：

```bash
kubectl api-resources --api-group='serving.knative.dev'
```
其中，Knative主要有以下一些API组：

* serving.knative.dev
* messaging.knative.dev
* eventing.knative.dev
* sources.knative.dev

安装Knative Serving

```bash
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.9.0/serving-core.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.9.0/eventing-core.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.9.0/in-memory-channel.yaml
kubectl apply -f https://github.com/knative/eventing/releases/download/knative-v1.9.0/mt-channel-broker.yaml
```
安装后，需耐心等待各个资源创建成功。

```bash
kubectl get pods -n knative-serving
kubectl get pods -n knative-eventing
```

Knative官方提供了Kourier的Ingress实现（目前已经GA）。

```bash
kubectl apply -f https://github.com/knative-sandbox/net-kourier/releases/download/knative-v1.9.0/kourier.yaml
kubectl patch configmap/config-network \
  -n knative-serving \
  --type merge \
  -p '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'
ksvc_domain="\"data\":{\""$(minikube -p kfaas-cluster ip)".nip.io\": \"\"}"
kubectl patch configmap/config-domain \
    -n knative-serving \
    --type merge \
    -p "{$ksvc_domain}"
```
### 安装Knative CLI
```bash
wget https://github.com/knative/client/releases/download/knative-v1.9.0/kn-linux-amd64
sudo mv kn-linux-amd64 /usr/local/bin/kn
sudo chmod +x /usr/local/bin/kn
```



# Hello World!
## Knative Functions
通过func命令（或者kn func）来创建一个Function，这里以Python为例：

```bash
kn func create -l python helloworld

cd helloworld
kn func run
```

这里运行时会提示提供一个registry名称，暂时可以随便输入一个即可。第一次运行需要进行构建，
这个构建过程稍微会需要一点时间。运行后，会启动8080端口，可以在浏览器访问：

![](images/Knative-func-helloworld.png)


## Hello world（WSL+Minikube方式部署）
```bash
kn service create helloworld-go --image gcr.io/knative-samples/helloworld-go
```

访问：注意这里不能直接通过URL访问，需要使用Kurior的SVC并设置Header。

```bash
curl -H "Host: helloworld-go.develop.192.168.49.2.nip.io" http://192.168.49.2:32117
```

参考：

* https://www.archcloudlabs.com/projects/diving-into-kubernetes/
* https://www.reddit.com/r/kubernetes/comments/v1a6ay/running_kubernetes_locally_and_minikube_vs/
* https://docs.google.com/spreadsheets/d/1ZT8m4gpvh6xhHYIi4Ui19uHcMpymwFXpTAvd3EcgSm4/edit#gid=0
* https://knative.dev/docs/getting-started/quickstart-install/
* https://docs.docker.com/engine/install/ubuntu/#install-from-a-package
* https://redhat-developer-demos.github.io/knative-tutorial/knative-tutorial/index.html
* https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
* https://github.com/knative/serving/issues/11624
* https://github.com/knative-sandbox/net-kourier/issues/992
* https://knative.dev/docs/install/yaml-install/serving/install-serving-with-yaml/#install-a-networking-layer