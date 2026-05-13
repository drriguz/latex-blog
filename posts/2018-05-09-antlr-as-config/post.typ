#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "使用 Antlr 解析配置文件",
  date: "2018-05-09",
  tags: ("小实现", "闲话编程", "Antlr"),
  lang: "zh",
)

在纠结了一阵子 yml,ini,xml甚至 lua 等等
配置文件的格式后，还是决定使用antlr实现了一种我自定义的格式的解析。

这个格式是这个样子的:

```lua
// Here is some comment
shared {
    string _baseUrl = "http://localhost:8080";
    string domain   = "riguz.com";
    bool ssl        = false;
    int version     = 19;
    int subVersion  = 25;
    float number  = 19.25;

    string urls         = ["http://localhost:8080", "http://riguz.com:8080"];
    string domains      = ["riguz.com", "dr.riguz.com"];
    bool sslArray       = [true, false];
    int versionArray    = [19, 25];
    float numberArray   = [18.01, 19.25, 20.23];
};

scope dev_db {
    string url = ${domain} .. ":3306/mysql";
    string user = "lihaifeng";
    int connections = 10;
    string password = "iikjouioqueyjkajkqq==";
    string domains = ${domains};
};
```

其实是一个k-v形式的文本文件，支持的基本类型有：字符串、布尔值、整数、小数、数组。定义的方法类似于Java或者C语言，

```
string _baseUrl = "http://localhost:8080"
```

前面会限定数据类型。如果要定义数组，则用

```
bool sslArray       = [true, false];
```

这种形式。

然后使用scope区分不同的配置块。因为可能有些相同的配置会重名，这样我们利用不同的scope去区分就好了。考虑到有些配置中需要共同的变量的使用，所以定义了一个shared的scope，这个是写死的scope，其他scope中只能引用shared
scope中的变量。

字符串连接使用`..`操作符。这样可以组装字符串。详细的实现可以在#link("https://github.com/soleverlee/forks/tree/master/config/src/main")[forks的子项目config]中找到。

另外还实现了一个类似Play! Framework的路由定义文件的解析，长这个样子的:

```lua
controllers admin{
package com.riguz.forks.demo.controller
UserController
FileController
}

controllers {
package com.riguz.forks.demo.admin
UserController->AdminUserController
PostController
}

filters {
package com.riguz.forks.demo.filters
AuthorizationFilter
NocsrfFilter
}

routes admin {
+AuthorizationFilter
get  /users                 UserController.getUsers()
get  /users/:id             UserController.getUser(id: Long)
post /users                 UserController.createUser()
get  /users/:id/files/*name FileUserController.getFile(id: Long, name: String)
}
routes guest {
+NocsrfFilter
get /posts      PostUserController.getPosts()
get /posts/:id  PostUserController.getPost(id: String)
}

routes guest {
+NocsrfFilter
get /posts      PostUserController.getPosts()
get /posts/:id  PostUserController.getPost(id: String)
}
```

这个文件的解析也在上面的git中可以找到实现。通过Antlr可以很方便的把类似这样的文件解析出来，你甚至可以实现自己的领域语言。在实现过程中，遇到过一些问题，来说下问题吧。

首先是Antlr提供了Listener和Visitor两种方式，起初使用Listener来实现但是感觉比较麻烦，而使用Visitor则可以直接通过返回值来取得AST解析结果。我们解析一个文件的时候，是自顶向下的，一个个的去解析的，比如我们的配置文件的antlr语法定义如下：

```lua
script
    : shared? scope*
      EOF
    ;
```

其中shared又是这样的

```lua
shared
    : SHARED LBRACE (property SEMI)* RBRACE SEMI
    ;
```

也就是说 `shared { k=v...} ;`这样的形式，然后又开始到了property:

```lua
property
    : type NAME ASSIGN expression        #basicProperty
    | type NAME ASSIGN LBRACK
        expression? (COMMA expression)*
      RBRACK                             #arrayProperty
    ;
```

这样层层往下来看。然后解析的时候也是一样，我们首先有一个顶层的解析器：

```java
public class ScriptVisitor extends CfParserBaseVisitor<Map<String, ScriptVisitor.Scope>> {
    private static final Logger logger = LoggerFactory.getLogger(ScriptVisitor.class);

    @Override
    public Map<String, Scope> visitScript(CfParser.ScriptContext ctx) {
        ...
    }
```

这个Visitor负责解析语法文件中定义的script块，然后解析里面的scope：

```java
ScopeVisitor scopeVisitor = new ScopeVisitor(context);
        ctx.scope().forEach(scopeContext -> {
            logger.debug("Visit scope:{}", scopeContext.getText());
            Scope scope = scopeContext.accept(scopeVisitor);
            scopes.put(scope.name, scope);
        });
```

这样又实现一个ScopeVisitor去解析scope就好了。详细的实现就不多贴代码了。

另外一个问题是，对于错误的处理，我们在哪一步做？比如`bool s = "123";`这是错误的，我们其实可以在定义grammar的时候就避免这种错误来，但写起来会麻烦一些。目前的实现是在Visitor中去对逻辑进行判断的，前面只做语法检查就可以了。

参考:

- http:/\/jakubdziworski.github.io/java/2016/04/01/antlr\_visitor\_vs\_listener.html
