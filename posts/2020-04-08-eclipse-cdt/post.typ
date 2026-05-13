#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Mac上的C++/CMake开发环境抉择",
  date: "2020-04-08",
  tags: ("CMake", "开发环境", "闲话编程", "Eclipse", "C++"),
  lang: "zh",
)

之前写过一篇文章#link("../visual_studio_code_cpp_ide")[Visual Studio Code for C++ development on MacOS],
因为在Mac上一直没有找到免费且又比较好用的C++开发工具。但相比起Visual
Studio而言，Visual Studio
Code还是太简陋了。而今时不同往日了，现在比较倾向于使用CMake来构建项目，所以希望能支持CMake，所以又把各种开发工具尝试了一下。

= Eclipse CDT
<eclipse-cdt>
最近Eclipse-CDT又更新了一下，再次体验了一下，而且根据之前的经验，eclipse是直接支持CMake了的，所以是我的首选目标。

== 导入CMake工程
<导入cmake工程>
Eclipse
CDT默认是支持CMake的，所以不用使用cmake生成eclipse的工程，直接就可以用。新建项目的时候是可以直接选用CMake项目的，那么，怎么导入一个现有的CMake工程呢？

实际上，并不能使用"Import"来导入，而是要用"File -\> New -\> C/C++
Project -\> Empty or Existing CMake
Project"，然后就可以选择现有项目，导入到Eclipse中去了。是不是很坑？

#figure(image("images/CDT_import_cmake_project.png", alt: "Import project"),
  caption: [
    Import project
  ]
)

== 运行Google Test测试
<运行google-test测试>
可以直接在Eclipse中运行Google
Test，因为本身编译测试出来是一个应用，其实可以直接运行，但是eclipse集成的Unit
Test可以让结果更好看一点：

#figure(image("images/CDT_run_tests.png", alt: "Run tests"),
  caption: [
    Run tests
  ]
)

要运行这样的测试必须在Run Configuration中新建一个Unit
Test的目标，并选择编译出来的test程序。

== Mac下字体设置
<mac下字体设置>
Eclipse在Mac下有一个问题就是默认的UI字体实在太小了，看着眼睛疼。

#figure(image("images/CDT_smallfont.png", alt: "默认字体"),
  caption: [
    默认字体
  ]
)

有一个解决办法就是安装一个#link("https://www.bresink.com/osx/TinkerTool.html")[TinkerTool]，然后设置"Help
tags"字体的大小。参见这个#link("https://bugs.eclipse.org/bugs/show_bug.cgi?id=56558")[Bug]。

#figure(image("images/CDT_14px.png", alt: "更改后的字体"),
  caption: [
    更改后的字体
  ]
)

== 缺点
<缺点>
也许Eclipse最大的问题就在于调试了，动不动就卡死在96%上，或者好不容易进去了，却告诉你没有调试信息，要不要看汇编？尝试了很久也没有找到解决办法，除此之外，别的都能接受。但是这个问题很致命啊…
另外一个问题就是，（即使gdb支持的也不好），eclipse是不直接支持lldb的。

= Visual Studio Code
<visual-studio-code>
看来还是把希望寄托在Visual Studio Code上了。

== 安装插件
<安装插件>
有以下的几个插件需要安装：

- ms-vscode.cpptools: C/C++插件
- ms-vscode.cmake-tools: CMake tools
- webfreak.debug: Native debug插件

安装完成之后，就可以打开CMake工程了。使用Command+Shift+P打开命令窗口，可以看到有很多CMake相关的选项：

- CMake:Configure 配置支持CMake工程
- CMake:Clean 清理build
- …

也可以通过系统下面的状态栏来设置，设置好之后，一般长这个样子：

#figure(image("images/Vscode-cmaketools.png", alt: "Visual Studio Code"),
  caption: [
    Visual Studio Code
  ]
)

可以看到下面的状态栏已经集成了CMake的target。

== 调试
<调试>
=== 使用lldb-mi从状态栏启动调试
<使用lldb-mi从状态栏启动调试>
调试有两种方式：一种是通过状态栏下面的"调试"图标启动的，不需要launch.json，但是默认情况下是不能工作的，需要做如下设置：

新建`.vscode/settings.json`，将cpptools下面lldb-mi的路径配置进去，比如我的：

```json
{
    "cmake.debugConfig": {
        "miDebuggerPath": "/Users/hfli/.vscode/extensions/ms-vscode.cpptools-0.27.0/debugAdapters/lldb-mi/bin/lldb-mi"
    }
}
```

#figure(image("images/Vscode-debug-lldb-mi.png", alt: "lldb-mi"),
  caption: [
    lldb-mi
  ]
)

但是这个玩意感觉支持很有限，我调试Googletest测试的的时候就直接挂掉了。

=== 创建launch.json调试
<创建launch.json调试>
另外一个方式是创建launch.json，这样可以从左边的调试菜单那里开始：

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(gdb) Launch",
            "type": "cppdbg",
            "request": "launch",
            // Resolved by CMake Tools:
            "program": "${command:cmake.launchTargetPath}",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}/build",
            "environment": [],
            "externalConsole": true,
            "MIMode": "gdb",
            "MIDebuggerPath": "/Users/hfli/.vscode/extensions/ms-vscode.cpptools-0.27.0/debugAdapters/lldb-mi/bin/lldb-mi",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ]
        }
    ]
}
```

但上面照样使用的是lldb-mi，有着跟上面的方法同样的问题。换成gdb后就更是奇怪的到处乱跳了。

=== 使用CodeLLDB插件
<使用codelldb插件>
另一个选项就是使用CodeLLDB插件，安装完成之后配置`launch.json`：

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch debug",
            "type": "lldb",
            "request": "launch",
            "program": "${command:cmake.launchTargetPath}",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}/build",
            "environment": []
        }
    ]
}
```

这样终于不会在我调试googletest的时候死掉了，

#figure(image("images/Vscode-debug-codelldb.png", alt: "CodeLLDB"),
  caption: [
    CodeLLDB
  ]
)

= Qt Creator
<qt-creator>
= KDevelop
<kdevelop>
- #link("https://github.com/microsoft/vscode-cmake-tools/issues/965")[Can't debug in Visual Studio Code \#965]
- #link("https://vector-of-bool.github.io/docs/vscode-cmake-tools/debugging.html#debugging")[Target Debugging and Launching]
