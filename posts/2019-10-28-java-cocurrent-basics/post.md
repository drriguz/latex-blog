线程是操作系统中进行运算调度的最小单位，它是一个单一顺序的控制流，不论是对于单核还是多核的CPU，都能比较有效的提高程序的吞吐率。在Java中，创建一个线程的唯一方法是创建一个`Thread`类的实例，并调用`start()`方法以启动该线程。然而当多个线程同时执行时，如何保证线程之间是按照我们期待的方式在运行呢？Java提供了多种机制来保证多个线程之间的交互。


# 同步(Synchronization)与监视器(Monitor)机制
显而易见最基本最常见的和多线程有关的就是同步`synchronized`关键字了，它底层是使用Monitor实现的。那么究竟什么是`Monitor`呢？根据JavaSE Specification的描述，在Java中，每一个对象都有一个与之关联的monitor，允许线程可以去`lock`或者`unlock`这个monitor。实际上：

* `monitor`是独立于Java语言之上的一个概念（没想到还有另外一个名字`管程`），保证在运行线程之前获取互斥锁
* 在Java中，任何对象(`java.lang.Object`)都可以允许作为一个monitor，所以会有`wait`、`notify`之类的方法

`synchronized`可以作用于代码块或者方法上。如果作用在代码块上，它会尝试去lock这个对象的monitor，如果不成功将会等待直到lock成功。而当执行完毕后，无论是否出现异常，都将会释放这个锁。

如果作用在方法上，唯一的区别在于，如果是实例方法，那么将使用这个实例作为monitor，也就是`this`；如果是静态方法，那么使用的是所在类的`Class`对象。

# Wait/Notify
每一个Object都包含一个等待线程的集合(Wait set)。当对象创建的时候，这个队列是空的，当调用`Object.wait()`、`Object.nofity()`以及`Object.nofityAll()`方法的时候，会自动添加或者移除队列中的线程。或者当线程的中断状态发生改变的时候，也会引起变化。

## Wait 
调用`wait`方法将使当前线程休眠直到另一个线程通过`notify`或者`notifyAll`来唤醒。当前线程必须持有该对象的锁，调用`wait`后即释放锁。当线程被唤醒时，需要重新取得锁并继续执行。然而，线程被唤醒有可能是因为“虚假唤醒”（spurious wakeups）导致，所以通常都需要将`wait`检测的逻辑包括在一个loop中：

```java
synchronized (obj) {
    while (<condition does not hold>)
        obj.wait();
    // Perform action appropriate to condition
}
```
所谓虚假唤醒就是说，本来不该唤醒的时候唤醒了。究其原因是在操作系统层面就性能和正确性做出了权衡，放弃了正确性而选择让程序自己去处理。

> Spurious wakeups may sound strange, but on some multiprocessor systems, making condition wakeup completely predictable might substantially slow all condition variable operations.

## Notify
调用`notify`将唤醒一个正在等待持有该对象锁的线程，如果有多个对象在等待的话，将会随机唤醒其中的一个。

被唤醒的线程必须等到当前线程释放锁之后，才能开始执行；也就是说`notify`执行完之后，并不会立即释放锁，而是需要等到同步块执行完。

如果调用`notifyAll`的话，所有等待的线程将被唤醒，但同一时间有且仅有一个线程能取到锁并继续执行。

## Interruption
当调用`Thread.interrupt`时，线程的中断状态呗设置为true。如果该线程在某个对象的waitSet中，则将会被从等待队列中移除，并在取得锁之后抛出`InterruptedException`。实际上，如果线程正在执行的是一些底层的blocking函数例如`Thread.sleep()`, `Thread.join()`, 或者 `Object.wait()`的时候，那么线程将抛出`InterruptedException`，并且`interrupted`状态会被清除；否则只会将`interrupted`状态设置为`true`。

如果一个处于等待队列中的线程同时收到中断和通知，那么可能的行为是：

* 先收到通知，正常唤醒。这时候，`Thread.interrupted`将为`true`，
* 抛出`InterruptedException`并退出

同样，如果有多个线程处于对象m的等待队列中，然后另一个线程执行`m.notify`，那么可能：

* 至少有一个线程正常退出wait
* 所有处于等待队列中的线程抛出`InterruptedException`而退出

需要注意的是，当一个线程中断了另一个线程的时候，被中断的线程并不是需要立即停止执行，程序可以选择在停止之前做一些清理工作之类的。通常如果捕获了`InterruptedException`只需要重新抛出即可，有些时候不能重新抛出的时候，需要将当前线程标记为`interrupted`使得上层堆栈的程序可以选择处理，

```java
try {
    while (true) {
        Task task = queue.take(10, TimeUnit.SECONDS);
        task.execute();
    }
}catch (InterruptedException e) { 
    Thread.currentThread().interrupt();
}

```

# 线程的生命周期
每一个线程有一个生命周期，包含多个状态：

* New: 线程创建还未开始执行，线程创建完之后即为此状态
* Runnable: 在JVM中正在执行的状态。当线程start之后，即变为runnable状态
* Blocked: 线程等待获取锁而被阻塞
* Waiting: 线程等待其他线程
* Timed Waiting: 有超时的等待
* Terminated: 线程已被退出

![Life cycle of a thread](https://www.baeldung.com/wp-content/uploads/2018/02/Life_cycle_of_a_Thread_in_Java.jpg)

# Sleep / Yield

当调用线程的`sleep`方法将导致线程暂时停止执行，值得注意的是并不会释放锁。而当线程的`yield`方法被调用时，意味着通知CPU当前线程可以“暂缓”执行的，实际很少使用。

>It is rarely appropriate to use this method. It may be useful
	      for debugging or testing purposes, where it may help to reproduce
	      bugs due to race conditions. 

# Context switching

在多线程中，CPU会为每个线程分配时间片区执行，即执行当前线程的一部分操作之后，操作系统需要从当前线程切换到其他线程中去。通常在下列的情况下会出现context switching:

* 多任务处理（即多个线程正常执行）
* 中断， 


那么在这个切换的过程中，会发生一些什么事情呢？



参考：

* [Chapter 17. Threads and Locks](https://docs.oracle.com/javase/specs/jls/se7/html/jls-17.html)
* [What's a monitor in Java?](https://stackoverflow.com/questions/3362303/whats-a-monitor-in-java)
* [管程](https://zh.wikipedia.org/wiki/%E7%9B%A3%E8%A6%96%E5%99%A8_(%E7%A8%8B%E5%BA%8F%E5%90%8C%E6%AD%A5%E5%8C%96))
* [Do spurious wakeups in Java actually happen?](https://stackoverflow.com/questions/1050592/do-spurious-wakeups-in-java-actually-happen)
* [Why does pthread_cond_wait have spurious wakeups?](https://stackoverflow.com/questions/8594591/why-does-pthread-cond-wait-have-spurious-wakeups)
* [Dealing with InterruptedException](https://www.ibm.com/developerworks/java/library/j-jtp05236/index.html)
* [Enum Thread.State](https://docs.oracle.com/javase/7/docs/api/java/lang/Thread.State.html)
* [Life Cycle of a Thread in Java](https://www.baeldung.com/java-thread-lifecycle)
* [Context switch](https://en.wikipedia.org/wiki/Context_switch)
* [How long does it take to make a context switch?](https://blog.tsunanet.net/2010/11/how-long-does-it-take-to-make-context.html)