#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Vert.X(1)：简介",
  date: "2020-12-07",
  tags: ("Vert.X", "框架", "闲话编程"),
  lang: "zh",
)

最开始了解到Vert.X是在#link("https://www.techempower.com")[Web Framework Benchmarks]中看到，性能超群的一个web框架，但说实话知名度不是特别高。

#figure(image("images/Vert.x_Benchmark.png", alt: "Vert.X Benchmark"),
  caption: [
    Vert.X Benchmark
  ]
)

而官网介绍也谦逊的很，甚至都说自己不算一个web框架，而是一个"tool-kit"：

#quote(block: true)[
Eclipse Vert.x is a tool-kit for building reactive applications on the
JVM.
]

= 特点
<特点>
Vert.x采取的是事件驱动的非阻塞异步响应模型，而不是类似Servlet一样为每一个连接分配一个新的线程。这样做的好处就是可以利用少量的线程处理很多的并发连接。而采取blocking
IO的线程在等待IO操作完成的时候，线程会被挂起，而后唤醒。但是这个操作本身也是有一定的开销的，当线程数很大的时候这个开销就尤为明显。

简单来说，Vert.x就是JVM版本的NodeJS，但一个比较大的区别就是NodeJS是单线程模型的，而Vert.x可以有多个event
loop，因此能够更加有效的利用多核的优势。

Vert.x的另一个特点就是提供了多种语言的绑定（并不仅仅是简单的wrap一下，而且充分利用了各个语言的特点）：

- Java
- JavaScript
- Groovy
- Ruby
- Kotlin
- Scala

== 什么是响应式（Reactive）
<什么是响应式reactive>
根据#link("https://www.reactivemanifesto.org/")[The Reactive Manifesto]的定义，一个响应式的系统具有四个特点：
// #box(image("https://www.reactivemanifesto.org/images/reactive-traits.svg", alt: "Reactive manifesto"))

- Responsive：The system responds in a timely manner if at all possible.
- Resilient：The system stays responsive in the face of failure.
- Elastic: The system stays responsive under varying workload.
- Message-driven: Reactive Systems rely on asynchronous message-passing
  to establish a boundary between components that ensures loose
  coupling, isolation and location transparency.

== 组件
<组件>
Vert.x又包含了很多个部分：

=== Web组件
<web组件>
- Core: 包含底层的Http/TCP、文件等的访问功能。
- Web: 可以用来创建Web应用和微服务
- Web Client: http请求客户端
- Web API Contract: 用来实现契约先行的开发模式以及契约测试
- 其他: Web API Service, Web GraphQL Handler等，不过目前都还在Technical
  Preview阶段

=== 数据访问
<数据访问>
数据访问组件提供了一系列的异步访问client，当然也可以直接使用原始的数据库驱动。支持的数据库有：

- MongoDB client
- Redis client
- Cassandra client
- SQL Common
- JDBC client
- Reactive MySQL/DB2/PostgreSQL client(Technical preview)

=== Reactive
<reactive>
提供了各种创建响应式应用程序的组件。

- Vert.x Rx: 不喜欢回调可以使用RxJava风格的API
- Reactive streams: 可以与Akka/Project Reactor等其他reactive系统交互
- Vert.x Sync:
  用来部署使用fiber(纤程，一种轻量级的线程)的节点，可以编写串行化风格的代码
- Kotlin coroutines: 携程的支持，可以使用`async/await`或者channels。

=== Microservices
<microservices>
创建微服务的组件：

- service discovery
- circuit breaker
- config

=== MQTT
<mqtt>
提供了MQTT的server和client端组件。

=== Authentication and Authorisation
<authentication-and-authorisation>
认证授权相关：

- Auth common
- JDBC auth
- JWT auth
- Shiro auth
- MongoDB auth
- OAuth2
- \.htdigest Auth

=== Messaging
<messaging>
- AMQP client(Technical preview)
- STOMP client & Server
- RabbitMQ client
- AMQP bridge

=== 其他
<其他>
- Kafka client
- Mail client: SMTP 客户端
- Consul client
- JCA Adaptor
- Event Bus bridge:TCP/Apache camel
- Health check
- Metrics
- Shell
- Docker
- Vert.x Unit
- …

= 使用
<使用>
== Hello World
<hello-world>
```java
public class VertxEcho {
    public static void main(String[] args) {
        Vertx vertx = Vertx.vertx();

        vertx.createNetServer()
            .connectHandler(socket -> {
                socket.handler(buffer -> {
                    socket.write("Hello:" + buffer);
                });
            })
            .listen(3000);
    }
}
```
