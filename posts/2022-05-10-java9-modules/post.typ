#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Java9模块(Modules)",
  date: "2022-05-10",
  tags: ("编程语言", "闲话编程"),
  lang: "zh",
)

Java9中引入的最重要的特性是模块化------Java Platform Module System
(JPMS)。实现模块化是一件非常有挑战性的事情，在此之前，已经有过一些非官方的解决方案例如OSGI。实际在2005年Java
7的时候#link("https://jcp.org/en/jsr/detail?id=277")[JSR 277: Java Module System]就提议要模块化Java
SE，后面该提议又被#link("https://jcp.org/en/jsr/detail?id=376")[JSR 376: Java Platform Module System]取代并推延到Java
8，又推延到Java 9，最终直到2017年Java 9推迟后才发布出来。

= 目标
<目标>
JSR 376中阐述了模块化Java SE平台的关键目标：

- 可靠的依赖配置：
  必须要能够通过模块化系统显式定义模块的依赖信息，能够在编译期和运行时都能够有效识别，并可以通过遍历所有模块的方式得到程序运行所需的所有模块信息。
- 高度封装性：只有当模块中的包显式暴露、且被其他模块显式依赖的时候才能使用。
- 对Java
  平台进行定制：可以对特定平台删除或者添加模块，从而实现Java平台的裁剪。
- 隐藏Java平台细节：一些不希望暴露给用户的方法可以通过模块化隐藏起来。
- 提高运行效率：在预知模块依赖的情况下，JVM有一些优化可以提高性能。

= 模块化的使用
<模块化的使用>
== JDK的模块
<jdk的模块>
JDK本身也拆分成了一系列的模块，可以通过命令列出来:

```bash
java --list-modules                                   

java.base@11.0.13
java.compiler@11.0.13
java.datatransfer@11.0.13
java.desktop@11.0.13
java.instrument@11.0.13
java.logging@11.0.13
java.management@11.0.13
...
```

== 如何创建一个模块
<如何创建一个模块>
创建模块十分简单，只需要添加一个特殊的module-info.java文件，并添加模块的描述信息(requires,
exports, provides..with, uses, opens)：

```java
module modulename {
    requires module.name;
}
```

- `requires`用来申明模块依赖于其他模块
- `requires static`用来申明编译时依赖（运行时是可选的）
- `requires transtive`表示如果A依赖某个模块B，那么依赖A的模块也隐式依赖B
- `exports`导出包下的public类型（包括嵌套的public和protected类型）
- `exports...to`仅导出给指定的模块
- `uses`申明该模块为服务的消费者（使用了某接口或者抽象类）
- `provides...with`申明模块为服务ud提供者（提供了实现）
- `opens`申明包对于其他模块在运行时（包括反射）可见
- `opens..to`申明包对于特定的模块模块在运行时（包括反射）可见
- `open`申明模块下的所有包均在运行时可见

```java
module my.module {
    exports com.my.package.name;
}

module my.module {
    export com.my.package.name to com.specific.package;
}
```

```java
module my.module {
    uses class.name;
}

module my.module {
    provides MyInterface with MyInterfaceImpl;
}
```

默认情况下，private在模块中是不可见的（即使通过反射的方式），因此如果想暴露出来，可以通过`open`来实现。

```java
module foo {
    opens com.example.bar;
}

module my.module {
    opens com.my.package to moduleOne, moduleTwo, etc.;
}

open module foo {
}
```

= Example：创建一个Java FX程序
<example创建一个java-fx程序>
首先，需要通过gradle插件来自动引入JavaFX的依赖项:

```groovy
plugins {
    id 'java'
    id 'application'
    id 'org.openjfx.javafxplugin' version '0.0.10'
}

javafx {
    version = "17.0.1"
    modules = [ 'javafx.controls' ]
}
```

然后，在module-info.java中申明依赖关系:

```java
module pulsar.browser {
    requires javafx.controls;
    exports com.riguz.pulsar.browser;
}
```

Ref:

- #link("https://www.oracle.com/hk/corporate/features/understanding-java-9-modules.html")[Understanding Java 9 Modules]
- #link("https://openjdk.java.net/jeps/200")[JEP 200: The Modular JDK]
