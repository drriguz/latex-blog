#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "使用Spring Cloud Contract进行契约测试",
  date: "2017-08-10",
  tags: ("框架", "Spring", "闲话编程", "微服务"),
  lang: "zh",
)

研究了一下契约测试，这个概念听着很高端，其实解决的是一个很古老的问题：系统间的接口定义。以前我们做系统同其他系统对接的时候需要定义接口，需要去设计，去确认；尤其是当下微服务比较盛行的时候，我们自己的系统之间也增加了接口，伴随着敏捷开发的流程，很多时候接口在一开始根本都不会去设计，想到哪改到哪…..于是就出现了所谓的契约测试的东西。

先来说说契约测试解决的问题吧：

- consumer在依赖的provider接口没有实现的时候可以用stub模拟
- provider可以测试自身的接口是否满足接口定义
- consumer和provider都以契约为准，但接口有变动时修改契约，否则测试通不过…\~
- 可以对边界进行测试

大概就是这样吧，我觉得前两条是最重要的Feature，举个例子，比如我们有一个Vehicle的服务，用来根据vin(车辆底盘号）来获取车辆的信息；一个Costomer的服务需要调用这个服务来获取客户的车辆信息。我们的Vehicle接口如下：

```java
@GetMapping("/vehicle/{vin}")
VehicleDetail getVehicleDetail(@PathVariable String vin){
   VehicleDetail item = this.vehicleService.getVehicle(vin);
   if(item == null)
       throw new VehicleNotFoundException();
   return item;
}
```

我们在Vehicle服务中定义一个契约：

```groovy
Contract.make {
    request {
        method 'GET'
        url value('/vehicle/WDC1660631A7506890')
    }
    response {
        status 200
        body([
                vin           : 'WDC1660631A7506890',
                brand         : 'Audi X5',
                owner         : 'James 王',
                registeredDate: 1502347667000,
                mileage       : 1200
        ])
        headers {
            header('Content-Type': value(
                    producer(regex('application/json.*')),
                    consumer('application/json')
            ))
        }
    }
}
```

这样我们在执行gradle的`generateContractTests`任务的时候会自动生成一个契约测试，我们在测试Vehicle服务的时候，只需要Mock我们的Service，返回对应的模拟信息：

```java
@Before
public void setUp() throws Exception {
    VehicleDetail i = new VehicleDetail();
    i.setVin("WDC1660631A7506890");
    i.setOwner("James 王");
    i.setBrand("Audi X5");
    i.setRegisteredDate(new Date(1502347667000L));
    i.setMileage(1200);
    RestAssuredMockMvc.webAppContextSetup(context);

    given(vehicleService.getVehicle("WDC1660631A7506890")).willReturn(i);
}
```

刚刚的契约是一个很固定的数据，我们还可以加上正则表达式的检测：

```groovy
Contract.make {
    request {
        method 'GET'
        url value(consumer(regex('/vehicle/[A-Z0-9]{18}')),
                producer('/vehicle/WDC1660631A7506890'))
    }
    response {
        status 200
        body([
                vin           : $(producer(regex(/[A-Z0-9]{18}/))),
                brand         : $(producer(anyNonBlankString())),
                owner         : $(producer(anyNonBlankString())),
                registeredDate: $(producer(regex(/[1-9][0-9]{11,12}/))),
                mileage       : $(producer(regex(/[1-9][0-9]{0,10}/)))
        ])
        headers {
            header('Content-Type': value(
                    producer(regex('application/json.*')),
                    consumer('application/json')
            ))
        }
    }
}
```

以及异常情况下的测试：

```groovy
Contract.make {
    request {
        method 'GET'
        url value(consumer(regex('/vehicle/\\w.+')),
                producer('/vehicle/XXXXX'))
    }
    response {
        status 404
    }
}
```

这样每一个groovy文件都会对应着生成一个测试，达到我们测试Provider的目的。那么，对于客户端来说，怎么测试呢？很简单，我们执行gradle的`install`命令，会把生成的stub包放到本地的gradle源中，我们在客户端测试的时候可以这么写：

```java
@RunWith(SpringRunner.class)
@SpringBootTest
@AutoConfigureStubRunner(ids = "com.riguz:foo:+:stubs:10000", workOffline = true)
public class CustomerServiceTest {

    @Autowired
    private CustomerService customerService;

    @Test
    public void shouldReturnCustomerDetail(){
        CustomerInfo info = this.customerService.getCustomerInfo("123");
        System.out.println(info);
        assertEquals(1, info.getVehicles().size());
        // ...
    }
}
```

对应着`~/.m2/repository/com/riguz/foo/1.0-SNAPSHOT/foo-1.0-SNAPSHOT-stubs.jar`，`+`表示取最新版本，`10000`是端口号，也就是模拟出了一个远程的服务端。这样如果契约有修改的话，取到新的契约stubs包也会跟着修改了。

另外，如果单纯的想模拟一个服务端怎么办？有办法，我们在provider中执行gradle的`generateClientStubs`命令后，会生成一个mappings目录，在`build/stubs/....`下面。里面有一些json文件，例如我们的：

```json
{
  "id" : "5dd47b81-a184-4b9e-be02-b6e22c409c81",
  "request" : {
    "url" : "/vehicle/WDC1660631A7506890",
    "method" : "GET"
  },
  "response" : {
    "status" : 200,
    "body" : "{\"vin\":\"WDC1660631A7506890\",\"brand\":\"Audi X5\",\"owner\":\"James \\u738b\",\"registeredDate\":1502347667000,\"mileage\":1200}",
    "headers" : {
      "Content-Type" : "application/json"
    },
    "transformers" : [ "response-template" ]
  },
  "uuid" : "5dd47b81-a184-4b9e-be02-b6e22c409c81"
}
```

我们可以通过wiremock-standalone来启动一个模拟的服务端。

```bash
java -jar wiremock-standalone-2.7.1.jar
# 启动后会自动创建一个mappings目录，把我们生成的mappings目录中的内容拷贝进去，再重新运行即可
```

这样访问`http://localhost:8080/vehicle/WDC1660631A7506890`就可以得到我们的契约里面写的模拟数据了。

好了，如果有疑问请参考#link("https://github.com/soleverlee/spring-contract-example.git")[完整的代码]，建议参考末尾的参考文章，本文不过是跟着写了一下而已。

总结一下吧，其实并没有感觉到Contract
Test有多高端，不过很适用与微服务+敏捷开发这种场合。来说说我觉得不足的地方：

- 契约测试依然是测试，无法替代设计，如果设计的接口是一坨\*测试的再好又有什么呢；并不是反对测试，而是感觉但凡重视测试的同时容易轻视设计（或者说测试能力要比设计能力强太多…)
- 如果是同三方系统对接，如何来操作呢？
- 对于一些其他的客户端就勉为其难了，比如NodeJS的客户端，无法使用生成的stubs.jar文件，客户端怎么保证得到的东西是自己想要的结果?

参考文章:

- #link("https://specto.io/blog/2016/11/16/spring-cloud-contract/")[Consumer-Driven Contract Testing with Spring Cloud Contract]
- #link("http://cloud.spring.io/spring-cloud-contract/spring-cloud-contract.html")[Spring Cloud Contract Document]
