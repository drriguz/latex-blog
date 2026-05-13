#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "调试JDK源码",
  date: "2020-01-25",
  tags: ("刨根问底", "探索分析", "JDK1.8", "Series-JDK-Source"),
  lang: "zh",
)

最近想要直接调试下JDK的源码却发现有些变量不能显示，像这样：

#figure(image("images/Intellij-no-debuginfo.png", alt: "IntelliJ"),
  caption: [
    IntelliJ
  ]
)

其原因是因为JDK中的rt.jar在release的时候没有附带调试信息。所以解决这个问题的思路是这样的：

- 重新编译你想要调试的类(`javac -g`)
- 将带调试信息的类覆盖原来的
- 重新进行调试

实际上，在IntelliJ中操作起来可能比较简单，可以分为以下几步：

- 将jdk的源码从JDK中拷贝出来，例如/Library/Java/JavaVirtualMachines/jdk1.8.0\_231.jdk/Contents/Home/src.zip
- 将源码解压，并将其中`java`,`javax`两个文件夹拷贝到一个空的Java工程中
- 编译源码，IntelliJ默认设置编译是包含了调试信息的。编译完成之后，将其#link("https://www.jetbrains.com/help/idea/packaging-a-module-into-a-jar-file.html#")[导出到jar包]中。
- 将导出的jar包（比如说rt\_debug.jar)放入到`$JAVA_HOME/jre/lib/endorsed`文件夹下面即可。如果这个目录不存在，手动创建一下。
- 重新进行调试即可。

#figure(image("images/Intellij-with-debuginfo.png", alt: "IntelliJ"),
  caption: [
    IntelliJ
  ]
)

事实上，这里利用了`endorsed-standards override mechanism`这一个JVM特性来重载了Java的类，这个特性已经在Java8中被deprecated了(#link("https://www.java.com/en/download/faq/release_changes.xml")[release notes for Java 8 Update 40 (8u40)])，但是Java8中仍然可用。

#quote(block: true)[
The endorsed-standards override mechanism and the extension mechanism
are deprecated and may be removed in a future release. There are no
runtime changes. Existing applications using the 'endorsed-standards
override' or 'extension' mechanisms are recommended to migrate away from
using these mechanisms.
]

Reference:

- #link("https://stackoverflow.com/questions/1313922/step-through-jdk-source-code-in-intellij-idea")[Step through JDK source code in IntelliJ IDEA]
- #link("https://stackoverflow.com/questions/18255474/debug-jdk-source-cant-watch-variable-what-it-is")[debug jdk source can't watch variable what it is]
