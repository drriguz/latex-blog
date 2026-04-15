如何自动部署 springboot 的应用？

首先我们要做的是把GOCD的启动用户`go`加入到`docker`组中，这样就可以免`sudo`来执行docker的命令了
```bash
sudo gpasswd -a go docker
sudo /etc/init.d/docker restart
newgrp - docker
```
我们现在来通过GOCD部署一个eureka的服务端。eureka用作服务发现，包含server端和client端，每个微服务是一个client注册到server上。看看需要哪些包：
```groovy
dependencies {
    testCompile group: 'junit', name: 'junit', version: '4.12'
    compile group: 'org.springframework.boot', name: 'spring-boot-starter-web', version: '1.5.3.RELEASE'
    compile group: 'org.springframework.cloud', name: 'spring-cloud-starter-eureka-server', version: '1.3.1.RELEASE'
}
```
然后我们的程序写一句话就可以了：
```java
@EnableEurekaServer
@SpringBootApplication
public class EurekaServerApplication {
    public static void main(String[] args){
        SpringApplication.run(EurekaServerApplication.class, args);
    }
}
```
这样启动后就可以访问到eureka的web页面了，我们可以在application.properties中配置一些属性：
```properties
server.port=8761
eureka.client.register-with-eureka=false
eureka.client.fetch-registry=false
```
然后来想办法把应用打包到docker中。我们新建一个Dockerfile到src/main/docker中：
```lua
FROM oracle/openjdk:8
VOLUME /tmp
ADD eureka-server-1.0-SNAPSHOT.jar app.jar
RUN sh -c 'touch /app.jar'
ENV JAVA_OPTS=""
ENTRYPOINT [ "sh", "-c", "java $JAVA_OPTS -Djava.security.egd=file:/dev/./urandom -jar /app.jar" ]
```
然后在build.gradle中添加一个构建任务：
```groovy
buildscript {
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath("org.springframework.boot:spring-boot-gradle-plugin:1.5.2.RELEASE")
        classpath('se.transmode.gradle:gradle-docker:1.2')
    }
}
task buildDocker(type: Docker, dependsOn: build) {
    push = false
    applicationName = jar.baseName
    dockerfile = file('src/main/docker/Dockerfile')
    doFirst {
        copy {
            from jar
            into stageDir
        }
    }
}
```
这样当我们执行`gradle build buildDocker`命令的时候就会把springboot应用打包成docker镜像了。