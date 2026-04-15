我的加密软件有一个登录页面，需要用户输入主密码然后验证密码之后才能进入。因为密码转换(Key transform)过程中用到了Argon2算法，而这个算法没有原生的dart实现，所以必须要通过插件的形式来完成，为此我还专门做了一个插件[encryptions](https://pub.dev/packages/encryptions)。调用插件得到秘钥这个过程大概要花个1~4秒钟，最近在安卓真机上测试发现，这个过程中我的进度条竟然出现了卡顿，也就是说本来应该转圈圈的，结果一开始就卡住不动了，那我还需要这个加载动画干嘛呢？为此研究了一番，如何来解决这个问题。


# 背景
先还是大致介绍一下我的场景。如图所示：

![Blocked Login UI](images/login_blocked.gif)

点击完成之后，期待的情况应该是显示圈圈转动的，但很明显这个地方卡住了。代码实现是是采用的mobx作状态管理，然后使用插件调用的argon2的原生c代码。页面的部分如下：

```dart
children: <Widget>[
  _profileImage(),
  Observer(
    builder: (_) {
      return _userStore.isBusy ? _progressBar() : _input(context);
    },
  )
],
```
然后是登录事件的处理代码:

```dart
@action
Future<bool> login(ProtectedValue masterPassword) async {
  setBusy();
  bool success = false;
  try {
    final PasswordCredential credential =
        await _loginService.checkUserCredential(masterPassword);
    _errorMessage = null;
    _userCredential = credential;
    success = true;
  } catch (_) {
    _userCredential = null;
    _errorMessage = "密码验证失败";
  }
  setIdle();
  return success;
}
```

# 定位问题
## 使用flutter profile工具

这就让我犯迷糊了，不是用了future么，async/await这么厉害来着，为毛会卡住呢？因为本身我是dart和flutter的初学者，不清楚一些细节，所以一开始怀疑的是，在点击登录之后设置`busy`状态的这一个步骤没有生效导致的。因为本身用的是mobx框架来处理的，很自然就开始怀疑是不是这个玩意有bug？或者说是我的用法有些问题？然而搜索了很久也没有找到相关的问题，一度有些不知所措。

所以首先想搞清楚的是，到底是什么操作导致了卡顿呢？这时候想到flutter可能有性能分析的工具，能不能帮助定位到具体的代码行呢？于是在Profile模式下运行程序，这是相关的信息：

![Performance overlay](images/login_blocked_overlay.gif)

然后还有dev tools中的对应信息：

![Dart dev tools](images/dart_devtools.png)

很可惜从这个分析结果中我没有能找到对我有帮助的信息，唯一只能说确定的确会卡顿...

## 换个思路继续试
因为从这条路感觉已经走不通了，所以决定从其他的地方入手继续查。我注意到在登录的时候，偶尔会出现这样的日志：

```
I/Choreographer(15562): Skipped 107 frames!  The application may be doing too much work on its main thread.
```

这说明啥？说明的确是卡了....这时候我开始怀疑，如果在登录这个事件里面做的事情很多的情况下，即便我们用了async/await，是不是也会卡顿呢？为了屏蔽掉其他条件的干扰，我们需要将登陆事件变得简单一些：

```dart
oid onPasswordSubmitted(BuildContext context, String password) async {
  print('login with: ${password}');
  for(int i = 0; i < 100000; i++) {
  }
}
```
果然发现这样UI一样会卡住，甚至卡的更厉害了，根本连进度圈都出不来了。从这个结果来看，说明async/await并不能保证不会block住UI，顺着这个思路朝下找，于是就找到问题的根本原因了。

# 让事件在单独的线程中运行
## Flutter线程模型
原来dart跟JavaScript一样是一个单线程的模型，也就是是说，async/await里面的方法并不是在多个线程中取执行的，而是通过事件机制，在单线程中完成的。那么就很容易解释UI卡顿的场景了，UI更新和事件代码是交替执行的，如果其中事件执行的部分花费了较长时间，UI就没办法去更新，所以界面就会卡在那里，也就是日志里面所说的`Skipped 107 frames!  The application may be doing too much work on its main thread.`了。

![Dart event model](https://cdn.jsdelivr.net/gh/flutterchina/flutter-in-action/docs/imgs/2-12.png)

从dart的文档中可以了解到，dart内部有两个队列：

* event queue： 包含所有的外部事件例如IO、点击、绘制等
* microtask queue： 微任务通常来自于dart内部或者手动插入`Future.microtask(…)`

microstask队列的优先级是要高于事件队列的。这里我们的登录事件和UI更新都同在事件队列中，很显然是因为我们的登录事件耗时太长从而掉帧了，那么解决的方案也就是，可不可以在新的线程中执行我们的事件呢？

## Isolate机制
研究了一下发现在dart中不叫线程，如果想达到这种目的需要使用一个称之为`Isolate`的东西，大致相当于新开一个线程来处理。要使用Isolate有两种办法：

* 使用`compute`方法
* 使用`Isolate.spawn`（更低级的操作）

下面是一个例子：

```dart
Future<List<Photo>> fetchPhotos(http.Client client) async {
  final response =
      await client.get('https://jsonplaceholder.typicode.com/photos');

  // Use the compute function to run parsePhotos in a separate isolate.
  return compute(parsePhotos, response.body);
}
```

## Compute方法
看样子使用Isolate看似就像在Java中新建一个线程一样，然后就可以在线程中运行代码了。那我们直接把登录事件的处理挪进去不就得了么？然而实际情况是，这玩意并不是十分好用，有着诸多（恶心）的限制。先来看一下最简单直接的`compute`方法：

```dart
typedef ComputeCallback<Q, R> = FutureOr<R> Function(Q message);
```

这个方法有两个参数，一个是callback（相当于java中的Runnable，就是你要执行的方法)，另一个是message，相当于是参数。这些参数有着如下的限制：

* callback必须是顶级的方法或者`static`方法，不能是类的实例方法或者是闭包
* 只有一个参数，那么我的方法需要传多个参数怎么办？

这就有些尴尬了，不仅要求是静态方法，还限制了参数，而我们的事件处理中有很多的依赖项，这可咋放进去呢？那么很可能只能用另一种方式了。

## Isolate.spawn
这个就显得更为麻烦了，大致的用法是这样的：

```dart

var ourFirstReceivePort = new ReceivePort();             // 需要一个ReceivePort来接收消息
await Isolate.spawn(echo, ourFirstReceivePort.sendPort); // 创建一个Isolate
var echoPort = await ourFirstReceivePort.first;          // 等待执行完成并接收返回值

// 在Isolate中运行的代码需要将返回值通过sendPort发送过来
sendPort.send(...);
```
这个`spawn`方法如下：

```dart
external static Future<Isolate> spawn<T>(
      void entryPoint(T message), T message,
      {bool paused: false,
      bool errorsAreFatal,
      SendPort onExit,
      SendPort onError,
      @Since("2.3") String debugName});
```
同样有着如下的限制：

* 两个参数，一个entryPoint，另一个是这个entryPoint方法的唯一参数（也就是message)
* entryPoint方法必须是顶级方法或者静态方法
* message参数必须是基本类型、SendPort或者只包含这两者的list或者map。

这样就更加有些尴尬了，如果我们希望调用一个实例方法怎么办呢？我的登录过程中的一个关键步骤是调用argon2，这个方法我希望能在单独的线程之中调用：

```dart
class Argon2Kdf implements Kdf {
  @override
  Future<Uint8List> derive(Uint8List password, Uint8List salt) async {
    Argon2 argon2 = new Argon2();
    return await argon2.argon2i(password, salt) as Uint8List;
  }
}
```
这个方法本身是一个实例方法，既然我们只能用顶级方法和实例方法，而且Argon2这个类也没有什么依赖，也罢，那就创建一个好了，没有问题，现在问题来了，我们需要的两个参数是password和salt，这个参数类型不是基本类型，不支持呢，咋办呢？

## Isolate中通信
原来isolate不像Java的线程一样可以使用共享内存，而是想actor模型一样，只能通过消息进行通信。那么，我们需要将参数转换为支持的基本类型，通过SendPort发送过去：

```dart
class Argon2Kdf implements Kdf {
  static final Argon2 argon2 = Argon2(iterations: 2);

  static void argon2Call(SendPort replyPort) async {
    final receivePort = ReceivePort();
    replyPort.send(receivePort.sendPort);
    final List<dynamic> params = await receivePort.first;
    final SendPort reportPort1 = params[0];

    final String passwordHex = params[1];
    final String saltHex = params[2];
    final Uint8List password = hex.decode(passwordHex) as Uint8List;
    final Uint8List salt = hex.decode(saltHex) as Uint8List;

    final Uint8List result = await argon2.argon2i(password, salt) as Uint8List;

    reportPort1.send(hex.encode(result));
  }

  @override
  Future<Uint8List> derive(Uint8List password, Uint8List salt) async {
    final ReceivePort response = ReceivePort();
    final isolate = await FlutterIsolate.spawn(argon2Call, response.sendPort);
    final SendPort sendPort = await response.first;
    final ReceivePort response1 = ReceivePort();
    sendPort.send([response1.sendPort, hex.encode(password), hex.encode(salt)]);
    final String result = await response1.first;

    isolate.kill();

    return hex.decode(result);
  }
}
```
这里有两点需要注意：

* 调用`await response.first`之后这个SendPort就自动解除订阅了，不能用来接收其他消息了
* Isolate.spawn不支持运行插件代码，所以用FlutterIsolate这个库来实现，而使用方法是一致的

如果直接使用`Isolate.spawn`会有如下的报错信息:

```
E/flutter (18071): [ERROR:flutter/runtime/dart_isolate.cc(808)] Unhandled exception:
E/flutter (18071): error: native function 'Window_sendPlatformMessage' (4 arguments) cannot be found
```

这样最终的效果就是:

![Login unblocked](images/login_unblocked.gif)

* [Dart asynchronous programming: Isolates and event loops](https://medium.com/dartlang/dart-asynchronous-programming-isolates-and-event-loops-bffc3e296a6a)
* [Move this work to a separate isolate](https://flutter.dev/docs/cookbook/networking/background-parsing#4-move-this-work-to-a-separate-isolate)
* [flutter_isolate](https://pub.dev/packages/flutter_isolate)
* [A Dart Isolates example (Actors in Dart)](https://alvinalexander.com/dart/dart-isolates-example)
* ['Window_sendPlatformMessage' (4 arguments) cannot be found](https://github.com/flutter/flutter/issues/26413)
* [Flutter - 'Window_sendPlatformMessage' (4 arguments) cannot be found](https://stackoverflow.com/questions/54127158/flutter-window-sendplatformmessage-4-arguments-cannot-be-found)
* [Cannot send regular Dart Instance to Isolate spawned with spawnUri](https://github.com/dart-lang/sdk/issues/35962)
* [Plugins crash with "Methods marked with \@UiThread must be executed on the main thread."](https://github.com/flutter/flutter/issues/34993)
* [Dart单线程模型](https://book.flutterchina.club/chapter2/thread_model_and_error_report.html)