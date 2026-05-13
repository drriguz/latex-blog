#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "搭建GOCD Server",
  date: "2017-06-20",
  tags: ("Docker", "云计算", "容器化"),
  lang: "zh",
)

来部署一个#link("https://hub.docker.com/r/gocd/gocd-server/")[GOCD]的容器。

```bash
sudo docker pull gocd/gocd-server:v17.5.0
docker run -d \
    --name gocd \
    -p 8153:8153 \
    -p 8154:8154 \
    -v /home/docker/go/data:/godata \
    -v /home/docker/go/home:/home/go \
    gocd/gocd-server:v17.5.0
```

启动起来后，访问8153端口，这时可以看到添加pipeline的界面了。

安装#link("https://github.com/gocd-contrib/script-executor-task/releases")[Script Executor]插件：

```bash
cd /home/docker/go/data/plugins/external
wget https://github.com/gocd-contrib/script-executor-task/releases/download/0.3/script-executor-0.3.0.jar
chown 1000 script-executor-0.3.0.jar
sudo docker restart gocd
```

安装go-agent到Ubuntu宿主机上，参考#link("https://docs.gocd.org/current/installation/install/agent/linux.html")[GOCD文档]

```bash
echo "deb https://download.gocd.io /" | sudo tee /etc/apt/sources.list.d/gocd.list
curl https://download.gocd.io/GOCD-GPG-KEY.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install go-agent
```

注意，go-agent只能运行在jdk8上，如果装了jdk9是运行不起来的

```bash
dpkg -l | grep jdk
sudo apt-get autoremove openjdk-9-jre-headless
sudo apt-get install openjdk-8-jre-headless
sudo apt-get install go-agent
```

记得修改环境变量/etc/profile：

```bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/jre/lib:$CLASSPATH
export PATH=$JAVA_HOME/bin:$JAVA_HOME/jre/bin:$PATH
```

配置gocd的工作目录：

```bash
mkdir /home/gocd
chown -R go.go /home/gocd
chown go.go /usr/share/go-agent/*.jar

vim /etc/default/go-agent

GO_SERVER_URL=https://192.168.56.101:8154/go
AGENT_WORK_DIR=/home/gocd/${SERVICE_NAME:-go-agent}
DAEMON=Y
VNC=
```

下面我们就来建一个pipe line试试吧。

- 在Agents中启用我们的go-agent，并在Resource中添加一个LINUX的标签
- 新建一个Environment，把我们的这个agent加入进去
- 新建一个Pipeline，名称为hello，group为dev
- 选择Material的地方选择Git，填写http:/\/root:\*\*\*\*[citation]，其中root:\*\*\*\*为GIT的账号密码，如果是public的库则无需这样设置，可以check
  connection查看是否可以访问
- 新建一个Stage，名称为build，然后Initial Job中设置为Script
  Executor，可以随便执行个bash命令，例如`echo "Hello World!"`
  这样运行就可以看到pipeline绿了#sub[]\~
