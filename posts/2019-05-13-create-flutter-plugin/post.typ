#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "创建一个Flutter的插件",
  date: "2019-05-13",
  tags: ("Android", "Flutter", "移动端", "闲话编程"),
  lang: "zh",
)

最近需要在Flutter中实现AES加解密和KDF，但搜索了一下貌似网络上没有现成的库可以用，因此尝试手写了一个Flutter的插件，实现两个功能：

- AES256/CBC/NoPadding 加解密
- Argon2（Argon2d)

= 插件定义
<插件定义>
== 创建插件工程
<创建插件工程>
其实貌似也可以在Flutter项目中直接调用Platform
channel相关的实现，考虑到把这一部分剥离出来可以单独维护和造福后人，还是选择创建一个Plugin。首先需要创建一个插件的工程，通过如下的命令：

```bash
flutter create --org com.riguz --template=plugin encryptions
```

这样会生成一个项目，值得注意的是，这里Android会使用Java，IOS会使用Objective-C。但Objective-C对于我这种没有基础的人来说看着太麻烦了，我尝试了一些之后放弃了。于是需要切换成Swift。这里有一个小的方法可以只修改IOS的部分：

```bash
cd encryptions
rm -rf ios examples/ios
flutter create -i swift --org com.riguz .
```

删除ios的目录后执行这个命令，可以重新生成ios的工程，基于swift的。

== 定义Dart接口
<定义dart接口>
首先定义出我们要暴露的接口。举个例子，对于AES加密的函数，我们可以这样写：

```dart
class Encryptions {
  static const MethodChannel _channel = const MethodChannel('encryptions');

  static Future<Uint8List> aesEncrypt(
      Uint8List key, Uint8List iv, Uint8List value) async {
    return await _channel
        .invokeMethod("aesEncrypt", {"key": key, "iv": iv, "value": value});
  }
```

这里有几点值得注意的：

- MethodChannel是用来调用原生接口，后面各个平台会注册同名的MethodChannel。
- 调用原生方法通过方法名 +
  参数调用，参数的对应列表参见官方文档。这里我们希望的是Java中的byte\[\]
  类型，所以用Uint8List
- 参数通过key-value的map传递到原生接口，原生代码通过参数名取得参数值

= Platform实现
<platform实现>
== ios
<ios>
首先需要先build一下:

```bash
cd encryptions/example; flutter build ios --no-codesign
```

在Xcode中打开项目，有一个SwiftEncryptionsPlugin的类，在这个里面实现即可：

```swift
public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as! [String: Any];
    switch call.method {
    case "aesEncrypt", "aesDecrypt":
        let key = args["key"] as! FlutterStandardTypedData;
        let iv = args["iv"] as! FlutterStandardTypedData;
        let value = args["value"] as! FlutterStandardTypedData;
        
        do {
            let cipher = try handleAes(key: key.data, iv: iv.data, value: value.data, method: call.method);
            result(cipher);
        } catch {
            result(nil);
        };     
        // ...
    }
}
```

因为需要使用Argon2，需要在swift中调用原生c代码，试了一些办法都不行，后来发现其实比较简单，直接在Supported
Files中有一个encryptions-umbrella.h文件中加入引用，就可以直接调用了:

```c
#import "EncryptionsPlugin.h"
#import "argon2.h"
```

```swift
func argon2i(password: Data, salt: Data)-> Data {
    var outputBytes  = [UInt8](repeating: 0, count: hashLength);
    
    password.withUnsafeBytes { passwordBytes in
        salt.withUnsafeBytes {
            saltBytes in
            argon2i_hash_raw(iterations, memory, parallelism, passwordBytes, password.count, saltBytes, salt.count, &outputBytes, hashLength);
        }
    }
    
    return Data(bytes: UnsafePointer<UInt8>(outputBytes), count: hashLength);
}
```

== Android
<android>
在Android
Studio中打开工程（第一次打开是需要build的，`cd encryptions/example; flutter build apk`，
ios也类似）。Android中实现起来会简单一点，这里只说一下如何调用c原生代码：

首先在build.gradle中加入额外的步骤：

```groovy
externalNativeBuild {
    cmake {
        path "src/main/cpp/CMakeLists.txt"
    }
}
```

然后在CMakeLists.txt中指定编译步骤，我这里需要编译一个argon2的库，以及一个JNI调用的库。

```cmake
add_library(
        argon2
        SHARED

        argon2/src/argon2.c
        argon2/src/core.c
        argon2/src/blake2/blake2b.c
        argon2/src/encoding.c
        argon2/src/ref.c
        argon2/src/thread.c
)

add_library(
        argon2-binding
        SHARED

        argon2_binding.cpp
)

target_include_directories(
        argon2
        PRIVATE
        argon2/include
)

target_include_directories(
        argon2-binding
        PRIVATE
        argon2/include
)

find_library(
        log-lib
        log)


target_link_libraries(
        native-lib
        ${log-lib})

target_link_libraries(
        argon2-binding

        argon2
        ${log-lib})
```

然后就通过JNI调用到argon2的方法：

```java
public final class Argon2 {
    static {
        System.loadLibrary("argon2-binding");
    }
    
    // ...

    private native byte[] argon2iInternal(int iterations, int memory, int parallelism, final byte[] password, final byte[] salt, int hashLength);

    private native byte[] argon2dInternal(int iterations, int memory, int parallelism, final byte[] password, final byte[] salt, int hashLength);
}
```

详细的代码不再累述。

= Example
<example>
在example工程中，用dart调用一下这些接口，然后可以分别在Xcode和Android
Studio中运行起来，看一下不同平台是否都支持。不清楚是否有自动化的测试方法。

#figure(image("images/encryptions_example.jpeg", alt: "example"),
  caption: [
    example
  ]
)

如果想了解更多，#link("https://github.com/soleverlee/encryptions")[这里]是详细的代码。

参考:

- #link("https://flutter.dev/docs/development/platform-integration/platform-channels")[Writing custom platform-specific code]
- #link("https://flutter.dev/docs/development/packages-and-plugins/developing-packages")[Developing packages & plugins]
