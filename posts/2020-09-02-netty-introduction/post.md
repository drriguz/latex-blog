Netty是一个高性能的异步事件驱动的网络应用框架，本质上是对NIO进行了高层的抽象，使得可以轻松的创建服务器和客户端，极大简化了诸如TCP和UDP套接字的操作。



# 入门
## 核心概念

![Netty architecture](https://netty.io/3.8/guide/images/architecture.png)

Netty中的一些核心概念：

* `Channel`对应到Socket
* `EventLoop`用来控制流、多线程处理以及并发
* `ChannelFuture`用来实现异步通知

## ECHO server
最简单的例子是构建一个echo server，发过来什么同样返回什么。

首先需要实现一个Handler，定义如何处理消息：
```java
public class EchoServerHandler extends ChannelInboundHandlerAdapter {
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        // handler需要去释放msg对象(引用计数）
        // 这里不用去手动release msg，因为writeAndFlush里面已经处理了
        ctx.writeAndFlush(msg);
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

然后利用`ServiceBootStrap`来启动
```java
public class EchoServer {
    private final int port;

    public EchoServer(int port) {
        this.port = port;
    }

    public void run() throws InterruptedException {
        EventLoopGroup bossGroup = new NioEventLoopGroup();
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        try {
            ServerBootstrap bootstrap = new ServerBootstrap();
            bootstrap.group(bossGroup, workerGroup)
                    .channel(NioServerSocketChannel.class)
                    .childHandler(new ChannelInitializer<SocketChannel>() {
                        @Override
                        protected void initChannel(SocketChannel ch) throws Exception {
                            ch.pipeline().addLast(new EchoServerHandler());
                        }
                    })
                    .option(ChannelOption.SO_BACKLOG, 128)
                    .childOption(ChannelOption.SO_KEEPALIVE, true);

            ChannelFuture f = bootstrap.bind(port).sync();
            f.channel().closeFuture().sync();
        } finally {
            workerGroup.shutdownGracefully();
            bossGroup.shutdownGracefully();
        }
    }

    public static void main(String[] args) throws InterruptedException {
        new EchoServer(9999).run();
    }
}
```
# 基本原理
## EventLoop与Server Channel、Channel
其运行原理如图：

![EventLoopGroup and Channels](https://dpzbhybb2pdcj.cloudfront.net/maurer/Figures/03fig04_alt.jpg)

* 左边只有一个ServerChannel，代表服务器上监听某个端口的套接字，所以实际上也只需要一个EventLoop就可以了
* 右边代表建立的客户端连接，每一个连接都对应到一个EventLoop，当有很多个连接的时候，这些连接是会共享其中的EventLoop的。

## ChannelPipeline

每次建立连接的时候，都会调用`ChannelInitializer`，这个类负责安装一些自定义的`ChannelHandler`到`ChannelPipeline`中。
实际上的程序可能对应到多个入站和出站的ChannelHandler，它们的执行顺序是由它们被添加的顺序所决定的，类似这样：

![Channel Pipeline](https://dpzbhybb2pdcj.cloudfront.net/maurer/Figures/03fig03_alt.jpg)

## ChannelHandler
ChanelHandler又有很多的类型，比如：

* 编码器和解码器, 例如`ByteToMessageDecoder`、`ProtobufEncoder`等
* `SimpleChannelInboundHandler<T>`，用来处理简单的逻辑比如收到消息后完成业务逻辑，只需要实现其中的`void channelRead0(ChannelHandlerContext ctx, I msg)`方法即可

## Bootstrap
前面使用`ServerBootstrap`类来启动了服务器上的socket监听，如果是客户端程序可以使用`Bootstrap`类来完成。一个比较明显的区别就是，客户端程序只需要一个`EventLoopGroup`而服务端通常会需要两个。

Ref:

* [Netty User guide for 4.x](https://netty.io/wiki/user-guide-for-4.x.html)
* [Netty in Action](https://livebook.manning.com/book/netty-in-action)