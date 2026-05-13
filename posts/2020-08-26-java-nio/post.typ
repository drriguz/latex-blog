#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Linux I/O模型与Java NIO",
  date: "2020-08-26",
  tags: ("NIO", "刨根问底", "探索分析"),
  lang: "zh",
)

I/O
即Input与Output，包含了文件的读写或者是网络的I/O。在Linux/Unix中有五种I/O模型：

- blocking I/O
- nonblocking I/O
- I/O multiplexing (select and poll)
- signal driven I/O (SIGIO)
- asynchronous I/O (the POSIX aio\_functions)

Java 从Java SE 1.4开始引入NIO，在Java 7推出了NIO
2。那么，不同的IO模型之间具体有什么差异，又该如何使用呢？

= I/O 模型
<io-模型>
在I/O操作中，通常是分为两个阶段的：

- 首先是等待数据就绪。
- 然后将数据从kernel复制到process

例如在socket中，第一个阶段就是等待从网络发送数据过来，然后存入内核的缓冲区。然后第二个阶段，将接收到的数据从内核缓冲区拷贝到用户程序中。

== 五种I/O模型
<五种io模型>
=== Blocking I/O
<blocking-io>
Blocking
I/O即阻塞式IO，在Linux中默认所有的socket都是blocking的。在这种模式下，两个阶段都是阻塞的。这个过程类似这样：

```cpp
data = recvfrom(socket)
```

=== Non-blocking I/O
<non-blocking-io>
将socket设置为non-blocking之后，如果数据没有就绪的时候不会阻塞住请求进程而是立即返回一个错误(`EWOULDBLOCK`)，这样请求进程可以不断尝试去获取是否有数据就绪（这个过程称之为#strong[#emph[polling]])。然而，在数据的拷贝阶段，这个过程还是blocking的。

```cpp
do {
    data = recvfrom(socket)
} while(data == EWOULDBLOCK)
```

=== I/O multiplexing
<io-multiplexing>
I/O
multiplexing(多路复用)是通过单个进程管理多个网络连接的一种方式，通常有`select`，`pool`和`epoll`等几种方式。在这种模式下，socket会被设置为non-blocking，通过不断轮询所有的socket，直到某个socket有数据则返回。

```cpp
while(true) {
    socket = select(sockets) // 这里如果没有一个socket是就绪的就会一直阻塞
    data = recvfrom(socket)  // 同样从内核拷贝数据到process的时候也是block的
}
```

一个更具体的例子：

```cpp
while(1){
    FD_ZERO(&rset);
    for (i = 0; i< 5; i++ ) {
        FD_SET(fds[i],&rset);
    }

    puts("round again");
    select(max+1, &rset, NULL, NULL, NULL);

    for(i=0;i<5;i++) {
        if (FD_ISSET(fds[i], &rset)){
            memset(buffer,0,MAXBUF);
            read(fds[i], buffer, MAXBUF);
            puts(buffer);
        }
    }   
}
```

除了使用`select`之外，还可以使用`pool`和`epoll`，但是本质上两个阶段都会block。看起来除了可以处理多个socket连接之外没啥好处，但是如果考虑到使用多线程的话，那么`recvfrom`可以在线程中处理，理论上可以提高吞吐。

=== Signal driven I/O
<signal-driven-io>
这种模式下首先将socket设置为singal-driven，然后通过`sigaction`注册一个回调。这个过程不是block的，一旦数据ready之后，一个`SIGIO`的信号会发送到process中，然后拷贝数据阶段依然是blocking的。

```cpp
handler = () -> {
    recvfrom(socket)
}
sigaction(socket, handler)
```

=== Asynchronous I/O
<asynchronous-io>
在AIO模式下，两个阶段都是nonblocking的，跟signal-driven
I/O模式的区别在于，前者是当数据ready之后通知应用去读取；而AIO是内核直接将数据拷贝到process完成之后通知process。

== 同步于异步、阻塞与非阻塞
<同步于异步阻塞与非阻塞>
同步异步、阻塞和非阻塞比较confusing, POSIX中是这样定义的：

- 同步I/O是指请求的进程被阻塞一直到操作结束
- 异步I/O不导致请求进程阻塞

根据这个定义，除了AIO之外，其他四种都是synchronous的，因为数据复制阶段（recvfrom)是阻塞的。

// Remote image removed: http://www.masterraghu.com/subjects/np/introduction/unix_network_programming_v1.3/files/06fig06.gif
// #figure(image("http://www.masterraghu.com/subjects/np/introduction/unix_network_programming_v1.3/files/06fig06.gif", alt: "I/O Models"),
//   caption: [
//     I/O Models
//   ]
// )

= Java中的I/O
<java中的io>
== blocking I/O
<blocking-io-1>
在Java中构建一个简单的Socket服务器，为每一个连接新建一个线程处理：

```java
public class EchoServer {
    public static void main(String[] args) throws IOException {
        ServerSocket server = new ServerSocket();
        server.bind(new InetSocketAddress(9000));

        while (true) {
            Socket socket = server.accept();
            new Thread(clientHandler(socket)).start();
        }
    }

    private static Runnable clientHandler(Socket socket) {
        return () -> {
            try {
                BufferedReader reader = new BufferedReader(new InputStreamReader(socket.getInputStream()));
                PrintWriter writer = new PrintWriter(new OutputStreamWriter(socket.getOutputStream()));

                String line = "";
                while (!"/quit".equals(line)) {
                    line = reader.readLine();
                    writer.write(line + "\n");
                    writer.flush();
                }
            } catch (IOException ex) {
                ex.printStackTrace();
            }
        };
    }
}
```

== non-blocking I/O
<non-blocking-io-1>
Java NIO中主要有以下的一些类：

- #link("https://docs.oracle.com/javase/8/docs/api/java/nio/package-summary.html#buffers")[Buffers]:
  数据缓冲容器
- #link("https://docs.oracle.com/javase/8/docs/api/java/nio/charset/package-summary.html")[Charsets]:
  字符集编码和解码
- #link("https://docs.oracle.com/javase/8/docs/api/java/nio/channels/package-summary.html")[Channels]:
  可以进行I/O操作的连接
- Selectors, selection keys: 用来实现multiplexed, non-blocking I/O机制

其中，`Buffer`中可以存储固定大小的容器，而其中的`ByteBuffer`类比较特殊：

- 可以作为I/O操作的目标
- 可以分配为direct buffer，JVM会尝试进行原生的I/O操作以提高性能
- 可以直接map文件的一部分到buffer中(`MappedByteBuffer`)，支持一些额外的文件操作
- 可以自定义字节序

使用Nio实现一个EchoServer:

```java
public class NioEchoServer {
    public static void main(String[] args) {
        try (Selector selector = Selector.open();
             ServerSocketChannel serverSocket = ServerSocketChannel.open()) {
            serverSocket.bind(new InetSocketAddress(9999));
            serverSocket.configureBlocking(false);
            serverSocket.register(selector, SelectionKey.OP_ACCEPT);
            ByteBuffer buffer = ByteBuffer.allocate(4);

            while (true) {
                selector.select();
                final Set<SelectionKey> selectedKeys = selector.selectedKeys();
                Iterator<SelectionKey> iterator = selectedKeys.iterator();
                while (iterator.hasNext()) {
                    final SelectionKey key = iterator.next();
                    if (key.isAcceptable()) {
                        accept(selector, serverSocket);
                    } else if (key.isReadable()) {
                        readAndAnswer(buffer, key);
                    } else {
                        throw new RuntimeException("Unsupported operation");
                    }
                    iterator.remove();
                }
            }

        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private static void accept(final Selector selector,
                               final ServerSocketChannel serverSocket)
            throws IOException {
        SocketChannel client = serverSocket.accept();
        client.configureBlocking(false);
        client.register(selector, SelectionKey.OP_READ);
    }

    private static void readAndAnswer(final ByteBuffer buffer,
                                      final SelectionKey key)
            throws IOException {
        final SocketChannel client = (SocketChannel) key.channel();
        client.read(buffer);
        buffer.flip();
        String s = StandardCharsets.UTF_8.decode(buffer).toString();
        System.out.println("-> " + s);
        buffer.clear();
    }
}
```

== Asynchronous I/O
<asynchronous-io-1>
Java支持AIO，具体有这些类：

- `AsynchronousFileChannel`: 用于文件异步读写；
- `AsynchronousSocketChannel`: 客户端异步socket；
- `AsynchronousServerSocketChannel`: 服务器异步socket。

但性能上可能并没有太大的提升（Linux平台），以致于Netty中移除了对NIO.2的支持：

#quote(block: true)[
I don't think NIO.2 will have better performance than NIO, because NIO.2
still make use of select/poll system calls and thread pools to simulate
asynchronous IO. One example is that Netty removed NIO.2 support in
4.0.0, because the author think that NIO.2 doesn't bring better
performance than NIO in Linux platform.
]

See also:

- #link("http://www.masterraghu.com/subjects/np/introduction/unix_network_programming_v1.3/ch06lev1sec2.html")[6.2 I/O Models]
- #link("https://devarea.com/linux-io-multiplexing-select-vs-poll-vs-epoll/#.X0W520lS-L8")[Linux -- IO Multiplexing -- Select vs Poll vs Epoll]
- #link("https://medium.com/@clu1022/%E6%B7%BA%E8%AB%87i-o-model-32da09c619e6")[淺談I/O Model]
- #link("https://www.baeldung.com/java-nio-selector")[Introduction to the Java NIO Selector]
- #link("https://stackoverflow.com/questions/27541283/io-performance-selector-nio-vs-asynchronouschannelnio-2")[IO performance: Selector (NIO) vs AsynchronousChannel(NIO.2)]
