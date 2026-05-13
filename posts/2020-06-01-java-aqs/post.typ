#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "理解Java并发(5)：AQS",
  date: "2020-06-01",
  tags: ("AQS", "并发编程", "Concurrent", "~理解Java并发", "刨根问底"),
  lang: "zh",
)

AQS(AbstractQueuedSynchronizer)是一个机遇FIFO等待队列实现锁的框架，用来实现诸如ReentrantLock、Semaphore等。

```java
public abstract class AbstractQueuedSynchronizer
extends AbstractOwnableSynchronizer
implements Serializable
```

= 基本用法
<基本用法>
AQS在类里面维护了一个原子int类型的状态值（这个值的具体含义由子类去定义）。要使用AQS，推荐的做法是在在一个私有的内部类中去实现AQS，然后需要通过AQS本身提供的几个方法：

- `getState()`
- `setState(int)`
- `compareAndSetState(int, int)`

通过调用上述三个方法来维护同步状态，并实现这些方法：

- `tryAcquire(int)`：尝试获取状态
- `tryRelease(int)`：尝试释放状态
- `tryAcquireShared(int)`
- `tryReleaseShared(int)`
- `isHeldExclusively()`: 判断当前线程是否持有排它锁

而其他的同步操作、队列管理等，在AQS中已经完成了。

== 样例：实现简单的锁
<样例实现简单的锁>
在AQS的文档中给了一个基本的用法:实现一个不可重入的锁。首先需要的就是实现内部的类：

```java
class Mutex implements Lock, java.io.Serializable {
   private static class Sync extends AbstractQueuedSynchronizer {
     protected boolean isHeldExclusively() {
       return getState() == 1;
     }

     public boolean tryAcquire(int acquires) {
       assert acquires == 1; // Otherwise unused
       if (compareAndSetState(0, 1)) {
         setExclusiveOwnerThread(Thread.currentThread());
         return true;
       }
       return false;
     }

     protected boolean tryRelease(int releases) {
       assert releases == 1; // Otherwise unused
       if (getState() == 0) throw new IllegalMonitorStateException();
       setExclusiveOwnerThread(null);
       setState(0);
       return true;
     }
   }
   // ...
}
```

然后，加锁、解锁等操作都可以通过这个内部类来完成了：

```java
class Mutex implements Lock, java.io.Serializable {
   // ...
   private final Sync sync = new Sync();

   // 这里通过获取或者释放状态1（1表示锁定）来实现加锁和解锁的操作
   public void lock()                { sync.acquire(1); }
   public boolean tryLock()          { return sync.tryAcquire(1); }
   public void unlock()              { sync.release(1); }
   public Condition newCondition()   { return sync.newCondition(); }
   public boolean isLocked()         { return sync.isHeldExclusively(); }
   public boolean hasQueuedThreads() { return sync.hasQueuedThreads(); }
   public void lockInterruptibly() throws InterruptedException {
     sync.acquireInterruptibly(1);
   }
   public boolean tryLock(long timeout, TimeUnit unit) throws InterruptedException {
     return sync.tryAcquireNanos(1, unit.toNanos(timeout));
   }
 }
```

= 原理
<原理>
AQS内部是使用的基于CLH队列的同步机制。

#figure(image("images/AQS_queue.png", alt: "AQS CLH"),
  caption: [
    AQS CLH
  ]
)

== acquire获取状态
<acquire获取状态>
acquire意味着尝试通过获取某个状态从而获取到锁。acquire的过程如下：

- 首先尝试直接通过CAS的方式改变state，如果成功则直接获取到锁
- 如果上一步失败，那么表明其他线程获取到锁，则尝试将当前线程加入到队列末尾进行排队（同样加入到队列末尾也是通过CAS实现）
- 加入到队列后，中断当前线程（但具体线程如何处理中断要看线程自己了）

```java
public final void acquire(int arg) {
    if (!tryAcquire(arg) && acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```

```java
private Node addWaiter(Node mode) {
    Node node = new Node(Thread.currentThread(), mode);
    Node pred = tail;
    // 如果发现队列不为空，那么尝试一次性快速插入到尾部（如果失败的话则通过enq方法插入）
    // 在没有线程竞争的情况下，会比enq稍微快一点，enq里面还要处理队列为空的情况
    if (pred != null) {
        node.prev = pred;
        if (compareAndSetTail(pred, node)) {
            // 通过CAS设置tail成功，这时候tail已经是当前node，再把之前的tail（pred）连接到自己
            pred.next = node;
            return node;
        }
    }
    // enq的逻辑基本上与上面一样，区别在于1. 处理队列为空的情况，要插入到队列头部；2.CAS失败后会重试直到成功
    enq(node);
    return node;
}
```

```java
private Node enq(final Node node) {
    for (;;) {
        Node t = tail;
        if (t == null) {
            // 如果发现队列为空那么首先把head和tail都设置为空节点
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            node.prev = t;
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
```

== release操作
<release操作>
当释放锁的时候，会唤醒一个后继节点，这个节点通常是后一个节点（如果后一个节点cancel了则要从队列尾部遍历直到找到真正的后继节点）。

```java
public final boolean release(int arg) {
    if (tryRelease(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h);
        return true;
    }
    return false;
}
```

- #link("http://gee.cs.oswego.edu/dl/papers/aqs.pdf")[The java.util.concurrent Synchronizer Framework]
