#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "浅析Java中的InvokeDynamic",
  date: "2019-12-24",
  tags: ("刨根问底", "探索分析", "JVM"),
  lang: "zh",
)

Java语言在被编译成class文件后，在class文件中，有专门的一个#link("https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-4.html#jvms-4.4")["常量池"(Constant Pool)]区域来存储一些运行所需要的常量，包括一些写死的变量（比如定义一个字符串`String str = "Hello world"`以及一些符号，例如类和方法的的名称等）。在JVM(se7)规范中，有以下这些类型的常量：

```bash
CONSTANT_Class                           CONSTANT_Long            
CONSTANT_Fieldref                        CONSTANT_Double          
CONSTANT_Methodref                       CONSTANT_NameAndType     
CONSTANT_InterfaceMethodref              CONSTANT_Utf8            
CONSTANT_String                          CONSTANT_MethodHandle    
CONSTANT_Integer                         CONSTANT_MethodType      
CONSTANT_Float                           CONSTANT_InvokeDynamic       
```

大部分我们顾名思义，都可以知道是大概是干啥的，比如字符串啊，数字啊，方法名称之类的；但是可以注意到最后面一个是称之为`CONSTANT_InvokeDynamic`的常量，这个就有点陌生了。那么，这是一个什么样的常量？什么情况下会出现这个呢？

= `invokedynamic`指令
<invokedynamic指令>
在JVM规范中有说，`CONSTANT_InvokeDynamic`常量是用来给`invokedynamic`指令指定一系列的参数的，那么有必要先了解一下`invokedynamic`这个指令了。这是Java
7引入的一个新指令，也是自Java 1.0以来第一次引入新的指令。

== Java7之前的`invoke-`指令
<java7之前的invoke-指令>
实际上，在此之前，已经有一些列的`invoke`开头的指令了：

- `invokevirtual`：用来调用类的实例方法，也就是最普遍的方式
- `invokestatic`：用来调用静态方法
- `invokeinterface`：用来调用通过接口调用的方法
- `invokespecial`：用来调用一些编译时就能够确定的，包括初始化(`<init>`)、类的私有方法，以及父类的方法(`super.someMethod()`)

拿一个简单的Java程序来看看是怎么回事：

```java
// Foo.java
public class Foo {
    public static void main(String[] args) {
        long now = System.currentTimeMillis();            //静态方法调用

        ArrayList<String> arrayList =  new ArrayList<>(); //构造函数将被调用
        List<String> list = arrayList;

        arrayList.add("hello");                           //调用类实例方法
        list.add("world");                                //通过接口调用
    }
}
```

通过`javac Foo.java && javap -v Foo`可以查看编译后生成的class文件，里面可以找到`invoke`相关的指令调用：

```
public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: ACC_PUBLIC, ACC_STATIC
    Code:
      stack=2, locals=5, args_size=1
         0: invokestatic  #2                  // Method java/lang/System.currentTimeMillis:()J
         3: lstore_1
         4: new           #3                  // class java/util/ArrayList
         7: dup
         8: invokespecial #4                  // Method java/util/ArrayList."<init>":()V
        11: astore_3
        12: aload_3
        13: astore        4
        15: aload_3
        16: ldc           #5                  // String hello
        18: invokevirtual #6                  // Method java/util/ArrayList.add:(Ljava/lang/Object;)Z
        21: pop
        22: aload         4
        24: ldc           #7                  // String world
        26: invokeinterface #8,  2            // InterfaceMethod java/util/List.add:(Ljava/lang/Object;)Z
        31: pop
        32: return
```

这样就比较好理解了，就跟我们平常调用函数一样，

- `System.currentTimeMillis()`静态函数的调用生成了`invokestatic`指令，这个指令的参数是静态方法（包含类名和方法名）
- `ArrayList`的构造方法调用生成了`invokespecial`指令，这里在`new`指令之后接着使用`invokespecial`指令来进行初始化操作
- 通过`ArrayList`的实例方法`add`调用生成了`invokevirtual`指令
- 而通过`List`接口的`add`方法调用生成了`invokeinterface`指令

尽管已经有了以上的四种指令，这些指令都有一个特点，那就是不管是什么方法，是静态还是实例方法，是子类还是父类的方法，在编译的时候已经能够确定出到底会调用到哪个方法了。有没有一种可能，就是我在编译的时候不能确定，而是在运行的时候才能确定呢？

== 鸭子类型（#strong[#emph[Duck Typing]]）
<鸭子类型duck-typing>
这就是所谓的#link("https://zh.wikipedia.org/wiki/%E9%B8%AD%E5%AD%90%E7%B1%BB%E5%9E%8B")[鸭子类型]了，可能叫#strong[#emph[Duck
typing]]其实更好理解一点，这个名称来源自#link("https://zh.wikipedia.org/wiki/%E9%B8%AD%E5%AD%90%E6%B5%8B%E8%AF%95")[鸭子测试]:

#quote(block: true)[
"当看到一只鸟走起来像鸭子、游泳起来像鸭子、叫起来也像鸭子，那么这只鸟就可以被称为鸭子。"
]

// Remote image removed: https://devopedia.org/images/article/24/2998.1514520209.jpg
// #figure(image("https://devopedia.org/images/article/24/2998.1514520209.jpg", alt: "A humorous and apt representation of duck typing. Source: Mastracci, 2014."),
//   caption: [
//     A humorous and apt representation of duck typing. Source: Mastracci,
//     \2014.
//   ]
// )

我们知道，Java是一个强类型的语言，有很多的类型检查，比如你要调用某个接口，而被调用的对象没有实现这个接口那么是无法完成的。而Duck
Typing正如上面这个图片形象的表示，我并不关心对象本身是个什么东西，而关心这个对象是否支持我所需要的所有属性或者方法。维基百科上的这个伪代码可以更直接的解释：

```
function calculate(a, b, c) => return (a+b)*c

example1 = calculate (1, 2, 3)
example2 = calculate ([1, 2, 3], [4, 5, 6], 2)
example3 = calculate ('apples ', 'and oranges, ', 3)
```

这些对象没有使用继承或者其他的方式相互发生联系，但只要它们支持`+`和`*`这两个方法，调用就可以成功。`invokedyanmic`指令从某种程度上来说，就是为了支持#emph[Duck
typing]。

看到这里可能细心的读者会注意到，咦，这东西看着好像`lambda`?

没错，事实上`lambda`的确是跟`invokedynamic`有关的，但有意思的是`lambda`是直到Java
8才推出（#link("https://www.jcp.org/en/jsr/detail?id=335")[JSR 335: Lambda Expressions for the JavaTM Programming Language])。在此之前，是无法通过`javac`编译器生成包含这个指令的class的。`invokedynamic`指令是在#link("https://jcp.org/en/jsr/detail?id=292")[JSR 292: Supporting Dynamically Typed Languages on the JavaTM Platform]中被引入的，可以注意到，原本是为了支持基于JVM的动态语言，并不是说要在Java中来做Duck
typing，这样就比较合理了。

当然借助于一些字节码操作框架（例如#link("http://www.csg.is.titech.ac.jp/~chiba/javassist/")[Javassit]、#link("http://asm.ow2.org/")[ASM]等，是可以手动创造出含有`invokedynamic`的class的，不过会有些麻烦。

== lambda与invokedynamic
<lambda与invokedynamic>
如果我们用支持`lambda`的Java
8是可以很容易的创建出一个包含`invokedynamic`常量和指令的class的，比如下面这个例子：

```java
import java.util.function.*;

public class Hello {

    public static void main(String[] args) {
        Supplier<String> welcome = () -> "Hello world!";
        System.out.println(welcome.get());
    }
}
```

当查看编译后的class文件会发现有下面的部分：

```
Constant pool:
   #1 = Methodref          #9.#20         // java/lang/Object."<init>":()V
   #2 = InvokeDynamic      #0:#26         // #0:get:()Ljava/util/function/Supplier;

public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: ACC_PUBLIC, ACC_STATIC
    Code:
      stack=2, locals=2, args_size=1
         0: invokedynamic #2,  0              // InvokeDynamic #0:get:()Ljava/util/function/Supplier;
```

一个就是在常量池中可以看到一个InvokeDynamic类型的常量，指向了`Supplier.get()`方法；另一个就是在`main`方法中对lambda的调用，被编译成`invokedynamic`指令。

= invokedynamic的机制
<invokedynamic的机制>
来研究一下`invokedyanmic`到底是怎么工作的吧。要了解它怎么工作的，我们先要知道编译生成的class文件中有些什么。刚我们看到，class文件中有两个部分与之相关，一个是常量池中的InvokeDyanmic信息，另一个是方法字节码中的`invokedynamic`指令调用。实际上JVM在引入这个新指令的同时，也在常量池(Constant
Pool)和属性表(Attributes)中加入了与之相关的内容，也就是`CONSTANT_InvokeDynamic_info`和`BootstrapMethods_attribute`。得益于class文件的扩展性，这些改动实际上并没有改变class文件本身的结构，仅仅只是加了更多合法的选项在里边。

== 引导函数(Bootstrap method)表
<引导函数bootstrap-method表>
在class的`Attributes`（属性表）中新加入的一个`BootstrapMethods_attribute`属性，这个属性里面会存储一些函数的相关信息，而且是和`CONSTANT_InvokeDynamic`常量一一对应的。

```cpp
BootstrapMethods_attribute {
    u2 attribute_name_index;
    u4 attribute_length;
    u2 num_bootstrap_methods;
    {   u2 bootstrap_method_ref;
        u2 num_bootstrap_arguments;
        u2 bootstrap_arguments[num_bootstrap_arguments];
    } bootstrap_methods[num_bootstrap_methods];
}
```

每一个引导函数都包含几个重要的属性：

- bootstrap\_method\_ref:
  指向一个`CONSTANT_MethodHandle_info`引用，表明实际调用的方法信息
- bootstrap\_arguments: 对应这个函数的参数

这个引导函数通常是这个样子：

```java
static CallSite bootstrapMethod(MethodHandles.Lookup caller, String name, MethodType type);
```

这个函数返回一个调用点(#link("https://docs.oracle.com/javase/7/docs/api/java/lang/invoke/CallSite.html")[CallSite])对象，这个对象包含了方法调用所需要的一切信息，用来给`invokedynamic`指令使用。

在Java8的`java.lang.invoke.LambdaMetafactory`类中，对应也增加定义了两个用来支持调用lambda的引导函数：

```java
static CallSite altMetafactory(MethodHandles.Lookup caller, String invokedName, MethodType invokedType, 
                               Object... args);
static CallSite metafactory(MethodHandles.Lookup caller, String invokedName, MethodType invokedType, 
                            MethodType samMethodType, MethodHandle implMethod, MethodType instantiatedMethodType);
```

而在上面的例子中，这个引导函数是这样的：

```
BootstrapMethods:
  0: #22 invokestatic java/lang/invoke/LambdaMetafactory.metafactory:(Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodHandle;Ljava/lang/invoke/MethodType;)Ljava/lang/invoke/CallSite;
    Method arguments:
      #23 ()Ljava/lang/Object;
      #24 invokestatic Hello.lambda$main$0:()Ljava/lang/String;
      #25 ()Ljava/lang/String;
```

== InvokeDynamic常量
<invokedynamic常量>
InvokeDynamic常量的定义如下：

```cpp
CONSTANT_InvokeDynamic_info {
    u1 tag;
    u2 bootstrap_method_attr_index;
    u2 name_and_type_index;
}
```

其中`bootstrap_method_attr_index`指向一个引导函数(Bootstrap
method)的序号，`name_and_type_index`则表明方法的名称和描述。在上面的例子中，仅有一个引导函数，这个`bootstrap_method_attr_index`自然就是对应到这个引导函数了。而在`invokedynamic`指令调用的地方，是这样的：

```
invokedynamic #2,  0              // InvokeDynamic #0:get:()Ljava/util/function/Supplier;
```

其中这个`#2`即常量池中的`InvokeDynamic`常量。

== `invokedynamic`指令
<invokedynamic指令-1>
根据#link("https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-6.html#jvms-6.5.invokedynamic")[JVM的规范]中的描述可以看到`invokedynamic`指令的格式如下：

```
invokedynamic indexbyte1 indexbyte2 0 0
```

其中前两个操作数可以通过`(indexbyte1 << 8) | indexbyte2`的方式合成一个常量池中的索引值，也就是上面的`#2`，而另外两个操作数是固定的0。

= Labmda的JVM实现
<labmda的jvm实现>
刚才已经看到，Java中对lambda'的调用实际上通过`LambdaMetafactory.metafactory`来完成的，通过了解这个类的实现，可以一看lambda的究竟。

#figure(image("images/debug_metafactory.png", alt: "Debug metafactory"),
  caption: [
    Debug metafactory
  ]
)

在这个类里面创建了一个匿名类，并通过`UNSAFE.ensureClassInitialized(innerClass)`直接加载到JVM中，没有出现在class文件中，不过通过jvm参数可以输出出来：

```bash
java -Djdk.internal.lambda.dumpProxyClasses=/Users/hfli/Downloads/tmp Hello
```

这样会生成一个`Hello$$Lambda$1.class`的文件，反编译这个类可以看到如下的信息：

```java
final class Hello$$Lambda$1 implements Supplier {
    private Hello$$Lambda$1() {
    }

    @Hidden
    public Object get() {
        return Hello.lambda$main$0();
    }
}
```

这里实际是包装了一下`Supplier`接口，而具体调用的`Hello.lambda$main$0()`方法，可以在`Hello.class`文件中看到（需要使用`javap -p`选项输出私有方法):

```
private static java.lang.String lambda$main$0();
    descriptor: ()Ljava/lang/String;
    flags: ACC_PRIVATE, ACC_STATIC, ACC_SYNTHETIC
    Code:
      stack=1, locals=0, args_size=0
         0: ldc           #7                  // String Hello world!
         2: areturn
      LineNumberTable:
        line 6: 0
```

所以大致是这个样子的过程：

- 调用lambda时，首先通过找到对应的引导方法（也就是`metafactory()`)，开始执行
- JVM生成一个匿名类`Hello$$Lambda$1`，这个类中包含了lambda的实际实现
- 创建一个CallSite，绑定到一个MethodHandle指向这个匿名类的实现`Hello$$Lambda$1.get()`。这里引导方法就调用完成了
- 这个MethodHandle指向的方法被执行，调用到`Hello.lambda$main$0()`关联的字节码，得到最终的结果

值得注意的是，引导方法只需要执行一次，如果一个lambda执行了多次，那么只有第一次会去调用引导方法生成CallSite，以后都可以直接拿来使用了。

= 结语
<结语>
通过上面的描述，相信大家对`invokedynamic`有了一个粗略的了解，但要真正深入去了解的话，还是有很多东西需要去了解和研究的。虽然`invokedynamic`指令很强大，给了JVM的开发者很大的自由度，但实际上对于Java程序员来说，并没有太多可以操控的东西。如同上面提到的Duck
Typing，在C\#中可以这样：

```c#
Object obj = ...; // no static type available 
dynamic duck = obj;
duck.quack();     // or any method. no compiler checking.
```

可能我们永远也没法使用Java来完成同样的任务，也许有一部分人会比较失望，但本身这是一把双刃剑，我还是倾向#link("http://www.yinwang.org/blog-cn/2016/01/18/java")[给Java说句公道话]。而借助于JVM平台，我们实际上有了越来越多的选择，Scala,
Kotlin，Groovy等等。可以说从某个方面来讲，正是Java决策者对于每一个决策的慎重，才造就了今天Java程序员不愁饭吃的局面。

#quote(block: true)[
"When you have 9 million programmers using your language and out of
which 1 million programmers know where you live you have to decide
things differently."
------#link("https://www.youtube.com/watch?v=1OpAgZvYXLQ&t=1993s")[Venkat Subramaniam]
]

参考文章：

- #link("https://www.infoq.com/articles/Invokedynamic-Javas-secret-weapon/")[Invokedynamic - Java's Secret Weapon]
- #link("https://stackoverflow.com/questions/6638735/whats-invokedynamic-and-how-do-i-use-it")[What's invokedynamic and how do I use it?]
- #link("https://zh.wikipedia.org/wiki/%E9%B8%AD%E5%AD%90%E7%B1%BB%E5%9E%8B")[Duck Typing - Wiki]
- #link("https://devopedia.org/duck-typing")[Duck Typing]
- #link("http://blog.headius.com/2008/09/first-taste-of-invokedynamic.html")[A First Taste of InvokeDynamic]
- #link("https://www.javacodegeeks.com/2012/02/java-7-complete-invokedynamic-example.html")[Java 7: A complete invokedynamic example]
- #link("https://my.oschina.net/lt0314/blog/3146028")[你不知道Lambda的秘密和陷阱]
- #link("http://wiki.jvmlangsummit.com/images/9/93/2011_Forax.pdf")[JSR 292 Cookbook]
- #link("https://www.jianshu.com/p/d74e92f93752")[理解 invokedynamic]

邮件阅读体验不佳，如需更好体验可以移步
#link("https://riguz.com/it/java/java_invokedynamic/")[在线版本]
