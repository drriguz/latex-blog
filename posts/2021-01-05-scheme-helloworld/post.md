最近准备创建一个简单的基于JVM的新语言，但在语法设计上犹豫不决，研究了一些资料后，觉得可能Lisp正是我所追求的清晰、简单、优雅的语法参考，因此决定深入了解一下Scheme。


# 开发环境配置
## 运行环境
编译安装[ChezScheme](https://github.com/cisco/ChezScheme)，据说是最好的scheme实现。

```bash
git clone https://github.com/cisco/ChezScheme.git
cd ChezScheme
./configure
make
sudo make install
```

完成之后应该就可以来写一个hello world了：

```
Chez Scheme Version 9.5.5
Copyright 1984-2020 Cisco Systems, Inc.

> (+ 1 1)
2
>
> (display "Hello world")
Hello world
```

## Visual studio code

需要安装两个插件

* vscode-scheme
* Code Runner

然后在settings中查找"Code-runner: Executor Map"，修改其中的scheme命令行：

```json
"code-runner.executorMap": {
    "scheme": "scheme --script"
}
```


参考：

* [Scheme 编程环境的设置](https://www.yinwang.org/blog-cn/2013/04/11/scheme-setup)