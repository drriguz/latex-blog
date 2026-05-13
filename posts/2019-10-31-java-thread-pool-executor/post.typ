#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "理解Java并发(2)：ThreadPoolExecutor解析",
  date: "2019-10-31",
  tags: ("刨根问底", "~理解Java并发", "并发编程", "Concurrent"),
  lang: "zh",
)

使用多线程技术可以有效的利用CPU时间，在同一个时间内完成更多的任务，但同时值得注意的是，线程创建本身也是有开销的，线程池使得我们可以重复的利用已经存在的线程，从而节省这一部分的开销，提高程序的效率。

= 线程数的限制
<线程数的限制>
首先一个问题是，我们在创建新的线程的时候，是不是线程越多就越好呢？实际上是不可能无限的创建新的线程的，总会有个限制，那么问题是这个限制是多大，或者说取决于什么呢？

== 操作系统的最大线程数
<操作系统的最大线程数>
首先希望搞清楚的一个问题就是，到底我们可以创建多少个线程呢？在linux上，可以通过以下的方式查看系统的最大线程数限制：

```
# cat /proc/sys/kernel/threads-max
15734
# ulimit -v
unlimited
```

据说是按照这个公式计算出来的:

```c
max_threads = mempages / (8 * THREAD_SIZE / PAGE_SIZE);
```

在windows上也比较类似，总结来说就是，每个系统的最大线程数都不尽相同，不仅与系统有关还与内存大小以及用户的设置有关系。

== JVM限制
<jvm限制>
JVM本身貌似没有对线程数进行限制，但同样不能无限制的创建线程否则会出现`java.lang.OutOfMemoryError: unable to create new native thread`。在JVM中有以下的一些参数可能会影响能创建的线程数：

- -Xms 设置堆的最小值
- -Xmx 设置堆的最大值
- -Xss 设置每个线程的stack大小

因为一个机器上的内存是一定的，所以如果`-Xss`设置的越大，单个线程所占用的栈空间越大，那么能创建的线程数就越少。一个比较有趣的事实是，能创建的最大线程数是跟`-Xmx`的值负相关的，即你设置的堆越大，反而能创建的最大线程数越少！这是别人的测试结果：

```
2 mb --> 5744 threads
4 mb --> 5743 threads
...
768 mb --> 3388 threads
1024 mb --> 2583 threads
```

原因就是堆空间越大，那么机器上剩下的内存就越少，即可以用来分配给线程栈上的内存就越少，所以会出现这样的结果。

= 线程池
<线程池>
在Java中线程的启动和停止是有开销的。这个开销主要包括：

- 为线程开辟栈空间（例如OpenJDK6在Linux上会使用`pthread_create`来创建线程，内部使用`mmap`分配内存)
- 通过操作系统的调用来创建和注册本地线程
- 保存线程的相关信息（JVM/native thread descriptors)到JVM中

根据网上的测试来看，通常使用线程池可以获得大幅的性能提升（亲测至少15倍）。而使用线程池相当于重用了已有的线程，避免了这部分开销。当任务越多越频繁的情况下，这部分开销越不可小觑。

== ThreadPoolExecutor
<threadpoolexecutor>
ThreadPoolExecutor
是一个利用线程池技术实现的多任务处理器，它的申明如下：

```java
public ThreadPoolExecutor(int corePoolSize,
                            int maximumPoolSize,
                            long keepAliveTime,
                            TimeUnit unit,
                            BlockingQueue<Runnable> workQueue) {
    this(corePoolSize, maximumPoolSize, keepAliveTime, unit, workQueue,
            Executors.defaultThreadFactory(), defaultHandler);
}
```

乍一看有很多个参数，那么该如何去配置呢？

=== CorePoolSize / MaximumPoolSize
<corepoolsize-maximumpoolsize>
线程池会根据这两个参数去管理池中的线程。当一个新的任务提交的时候，会遵循如下的规则：

- 如果池中线程数小于corePoolSize，哪怕有空闲的线程也会创建一个新的线程来
- 当吃中线程数超过corePoolSize但是小于MaximumPoolSize的时候，只有当workQueue满的时候才会创建新的线程

所以当corePoolSize和MaximumPoolSize一样的时候，实际上就是一个固定大小的线程池，相当于使用`Executors.newFixedThreadPool`:

```java
public static ExecutorService newFixedThreadPool(int nThreads) {
    return new ThreadPoolExecutor(nThreads, nThreads,
                                  0L, TimeUnit.MILLISECONDS,
                                  new LinkedBlockingQueue<Runnable>());
}
```

池中的线程默认只要当提交了新任务的时候才会创建，如果希望提前创建线程可以使用`prestartCoreThread`或者`prestartAllCoreThreads`。

=== Keep-alive 时间
<keep-alive-时间>
当池中的线程数多余corePoolSize的时候，超出部分的线程会在空闲一段时间之后被终止掉，这个时间就是keepAliveTime。如果设置为0那么一旦超出部分运行结束之后就会被终止掉，反之如果设置为`Long.MAX_VALUE`那么空闲线程就会一直存活。

默认情况下，只有超出corePoolSize的线程才会受到这个存活时间的影响，如果希望对于核心线程也能超时终止，那么可以使用`allowCoreThreadTimeOut`来控制。

=== workQueue
<workqueue>
工作队列用来持有提交的任务。规则如下：

- 如果当前池中的线程少于corePoolSize，则创建新的线程
- 如果大于corePoolSize，则倾向于将任务加入到workQueue中
- 如果无法将任务加入到队列中，则会创建新的线程，直到池中的线程数达到maximumPoolSize
- 如果超过maximumPoolSize，那么将会拒绝提交的任务

对于队列的选择也可以使用不同的策略：

- 使用`SynchronousQueue`可以直接将任务从队列转手到线程池，这个参数要配合将maximumPoolSize设置为无限大来配合使用。因为这个朝这个队列中插入一条数据将会阻塞一直到它被消费，也就是说读写操作要配套，实际上就是进行了一个数据交换，根本没有在队列中实际存储任务。如果maximumPoolSize太小可能会导致任务被拒绝。
- 使用无界的队列例如`LinkedBlockingQueue`，那么一旦线程超过corePoolSize的时候新线程都会被加入到队列中，也就是说maximumPoolSize根本不会生效了。
- 使用有界队列例如`ArrayBlockingQueue`，超过队列数的新任务将创建新的线程。那么这时候队列大小和线程数上限需要权衡配合。

References:

- #link("https://stackoverflow.com/questions/344203/maximum-number-of-threads-per-process-in-linux")[Maximum number of threads per process in Linux?]
- #link("https://eknowledger.wordpress.com/2012/05/01/max-number-of-threads-per-windows-process/")[Max Number of Threads Per Windows Process]
- #link("http://baddotrobot.com/blog/2009/02/26/less-is-more/")[Less is More]
- #link("https://stackoverflow.com/questions/5483047/why-is-creating-a-thread-said-to-be-expensive")[Why is creating a Thread said to be expensive?]
