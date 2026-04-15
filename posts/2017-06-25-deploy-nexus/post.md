我们安装[Nexus](https://store.docker.com/community/images/sonatype/nexus3)来作为我们的Docker镜像仓库。

```bash
sodu docker pull sonatype/nexus3
mkdir /home/docker/nexus
chown -R 200 /home/docker/nexus
sudo docker run -d \
    --name nexus \
    -v /home/docker/nexus \
    -p 8081:8081 \
    sonatype/nexus3
```
安装完成后，可以访问192.168.56.101:8081，登录进去后，添加一个Docker Hosted源，比如http://192.168.56.101:8081/repository/cloud-images/

我们可以把项目中需要用到的文件传到Nexus上。我们新建一个`raw`格式的repository
```bash
curl --fail -u admin:admin123 --upload-file gradle-4.0-bin.zip 'http://192.168.56.101:8081/repository/files/'
```
这样就可以通过http://192.168.56.101:8081/repository/files/gradle-4.0-bin.zip 来访问我们这个文件了。