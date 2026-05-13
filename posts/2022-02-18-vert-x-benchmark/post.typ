#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Vert.X(2)：Vert.x及SpringBoot在CPU密集型应用下的性能测试",
  date: "2022-02-18",
  tags: ("Vert.X", "框架", "闲话编程"),
  lang: "zh",
)

在#link("https://www.techempower.com")[Web Framework Benchmarks]中测试vert.x比Spring框架性能高上不少，但vert.x这种响应式框架借助异步编程实现，更多的性能体现实际上跟I/O相关。如果一个应用是I/O密集型的那么毫无疑问vert.x性能对于Springboot来说将是碾压式的，那么，对于几乎没有什么I/O操作的CPU密集型应用，vert.x和springboot谁将更胜一筹？

= 分析
<分析>
在实际进行测试之前，首先凭空思考一番。对于CPU密集型的应用，对性能的影响基本上可以忽略I/O模型所带来的加成了，那么更多的是框架本身的架构上。Springboot有一些缺点：

- 它是基于Servlet的，也就是一个请求将对应到一个线程；在高并发的情况下，系统创建的线程数是有上限的，而且线程数目越多，反而性能可能大幅降低
- Springboot本身的调用堆栈十分复杂

所以推测，即便是对于CPU密集型应用，vert.x仍然具有较为明显的优势，尤其是对于高并发的场景下，Springboot将更早到达极限。

= 测试准备
<测试准备>
虽然想当然的认为vert.x性能一定会要比Springboot高，但是毕竟没有数据说话，高到底又高多少呢？为此，我设计了一个性能测试，思路是用两种框架分别实现同样的逻辑，然后部署在docker中用jmeter进行测试。

== API接口实现
<api接口实现>
测试模拟了一个app的元数据管理系统，从内存中根据app
id拿到数据，并返回给客户端。

```java
@GetMapping("/api/v1/{app}")
public AppInfo getAppInfoV1(@PathVariable String app)
        throws JsonProcessingException, InvalidRequestException, AppNotFoundException {
    return service.getAppInfo(app);
}
```

为了增加一些复杂性，又引入了其他几个api，增加了一些小的东西在返回的结果上。

```java
@GetMapping("/api/v2/{app}")
public ResponseEntity<AppInfo> getAppInfoV2(@PathVariable String app)
        throws InvalidRequestException, AppNotFoundException {
    AppInfo info = service.getAppInfo(app);

    return ResponseEntity.ok()
            .header("Signature", service.getSign(info))
            .body(info);
}

@PostMapping("/api/v1/{app}")
public ResponseEntity<AppInfo> getAppInfoV1ByPost(@PathVariable String app,
                                                  @RequestBody Request request)
        throws InvalidRequestException, AppNotFoundException {
    AppInfo info = service.getAppInfo(app);

    return ResponseEntity.ok()
            .header("nonce", request.getNonce())
            .body(info);
}

@PostMapping("/api/v2/{app}")
public ResponseEntity<AppInfo> getAppInfoV2ByPost(@PathVariable String app,
                                                  @RequestBody Request request)
        throws InvalidRequestException, AppNotFoundException, JsonProcessingException {
    AppInfo info = service.getAppInfo(app);

    return ResponseEntity.ok()
            .header("Signature", service.getSign(info, request.getNonce()))
            .body(info);
}
```

为了使用同样的流程，我们将业务逻辑抽象成了一起，这样vert.x中实现也十分简单：

```java
Router router = Router.router(vertx);
router.get("/api/v1/:app")
        .handler(context -> {
            String app = context.pathParam("app");

            AppInfo info = service.getAppInfo(app);
            context.json(info);
        }).failureHandler(errorHandler);
```

== Docker部署
<docker部署>
为了模拟对资源的限制，使用Docker进行部署是一个十分方便的做法，如下我们将springboot和vertx分别部署在同样的配置下：

```yaml
version: "2.4"
services:
  app-springboot:
    build:
      context: ./springboot
      dockerfile: ./Dockerfile
    image: springboot-app:latest
    ports:
      - "8081:8080"
    mem_limit: 4096m
    cpus: 4.0
  app-vertx:
    build:
      context: ./vertx
      dockerfile: ./Dockerfile
    image: vertx-app:latest
    ports:
      - "8082:8080"
    mem_limit: 4096m
    cpus: 4.0
```

其中，限制内存为4G，CPU为4个单位。由于我们采取了Java11，可以自动感知内存的限制，所以无需单独为java设置内存参数。

== jmeter测试
<jmeter测试>
通过jmeter可以很方便的进行压力测试，其思路是，启动多个线程朝目标机器发送请求，并记录结果。

#figure(image("images/Jmeter-testplan.png", alt: "Jmeter配置"),
  caption: [
    Jmeter配置
  ]
)

值得注意的是，

- 使用asseration来对结果是否正确进行评估，默认情况下，jmeter根据返回码来判断；但有些场景我们其实是希望它出错的
- 使用csv数据源可以方便的将数据均匀化
- 使用`${__P(threads, 1)}`这种形式可以支持将变量从命令行传入

最终，我们测试的时候，需要使用命令行（而不是GUI）来进行测试，类似：

```bash
./apache-jmeter-5.2.1/bin/jmeter -n -t benchmark.jmx \
    -J threads=3000 \
    -J seconds=0 \
    -J loop=100 \
    -l result.jtl \
    -j result.log
```

= 测试结果
<测试结果>
以下是测试的结果:

#box(image("images/Vertx-qps.png"))

#box(image("images/Vertx-rt.png"))

#box(image("images/Vertx-mrt.png"))

#box(image("images/Vertx-err.png"))
