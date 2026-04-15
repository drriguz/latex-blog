一个Raft集群在程序启动的时候，其实就必须知道集群中所有其他节点的信息（ip，端口等），如果集群部署在Kubernetes中，怎么进行扩容呢？这是个矛盾的问题：一旦扩容，则集群中节点的信息会发生变化。

在Kubernetes中，使用StatefulSet可以解决这一问题。


# Apache Ratis中集群中Raft节点的创建

以Apache Ratis为例，在集群中创建Raft节点时，需要初始化一个RaftServer对象：

```java
RaftGroup raftGroup = RaftGroup.valueOf(RaftGroupId.valueOf(UUID.fromString("02511d47-d67c-49a3-9011-abb3109a44c1")), raftPeers)
RaftServer server = RaftServer.newBuilder()
        .setGroup(raftGroup)
        .setProperties(properties)
        .setServerId(id)
        .setStateMachine(stateMachine)
        .build()
```

其中，raftPeers即所有节点的信息，这个是提前就知晓的，包括其地址和端口号。比如，raft.node.01:6000。

# 使用StategulSet
## 什么是StategulSet

通常在Kubernates中部署节点使用Deployment部署时，每次重新部署Kubernates都会为其分配新的资源，包括名称、所依赖的pv等。也就是说，它是无状态的，每次创建的Pod都与之前的没什么关系。

而StatefulSet则未解决这一问题而设计，使用它能够创建出一组“稳定”的Pods。以一个Nginx集群为例：

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: k8s.gcr.io/nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

创建完成后，则可以看到部署的节点：

```
 ﮫ17ms⠀   kubectl get statefulset        powershell   80  18:02:55 
NAME   READY   AGE
web    3/3     5d18h
 ﮫ1.511s⠀   kubectl get pods
NAME    READY   STATUS    RESTARTS   AGE
web-0   1/1     Running   0          3d6h
web-1   1/1     Running   0          3d6h
web-2   1/1     Running   0          5d18h
```
可以看到，Kubernates为其创建了web-0~2三个实例，无论修改还是重新部署，这个名称是不会变化的，并且其分配的持久化卷也是相对固定的。

因此，我们通过StatefulSet可以：

* 保持pod的状态
* 预知所有pod的地址（名称）

这可以帮助实现Raft集群的创建。

## 节点间解析

还需要解决一个问题，就是在每个Pod中都需要能够访问其他节点。根据前面的规则可以知道其他节点的名称，如web-1，但是Kubernates并不支持在在节点中解析其他节点，如果我们在web-0中pingweb-1肯定是不通的。

要实现互相解析，需要使用headless-service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
```

创建headless-service之后，将可以使用`{podName}.{headlessSvcName}`的方式来解析，例如web-1.nginx：
```
 ﮫ224ms⠀   kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.232.0.1   <none>        443/TCP   181d
nginx        ClusterIP   None         <none>        80/TCP    5d18h

 ﮫ0ms⠀   kubectl exec -it web-0 -- /bin/bashowershell   99  14:28:24 
root@web-0:/# curl web-1.nginx
<html>
<head><title>403 Forbidden</title></head>
<body bgcolor="white">
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx/1.11.1</center>
</body>
</html>
root@web-0:/#
```
## 实现部署
### 程序中按名称创建RaftGroup
通过以上的方式，在知道集群副本数目、pod name、headless svc名称的情况下可以得到所有机器的地址。因此，可以将这些信息传入到程序中，根据这些构建RaftGroup：

```yaml
raft:
  group: "02511d47-d67c-49a3-9011-abb3109a44c1"
  dataStoragePath: /data/ratis-data
  id: dw-dynamic-service-0
  peers:
    size: 3
    pattern: dw-dynamic-service-%d
    port: 6000
```

```java
Map<String, RaftConfig.PeerConfig> peers = new HashMap<>();
for (int i = 0; i < clusterSize; i++) {
    String host = String.format(properties.getPeers().getPattern(), i);
    String address = String.format("%s:%d", host, properties.getPeers().getPort());
    peers.put(host, new RaftConfig.PeerConfig(address));
}
```

### 获取pod名称

可以通过metadata.name获取pod的名称，并作为环境变量传入到pod中。
```
env:
    - name: POD_NAME
        valueFrom:
        fieldRef:
            fieldPath: metadata.name
    - name: RAFT_ID
        value: {{ printf "$(POD_NAME).%s" (include "my-service.headless-svcname" .) }}
```

### helm部署

其他信息通过helm可以很容易生成出来，例如上面的应用的raft配置:

```
raft:
    group: {{ .Values.raft.group }}
    dataStoragePath: /data/ratis-data
    peers:
    size: {{ .Values.replicaCount }}
    pattern: {{ printf "%s-%%d.%s" (include "my-service.fullname" .) (include "my-service.headless-svcname" .) }}
    port: 6000
```