学习一下Hotspot中的锁实现。



# Head word

JVM 中对象头包含两部分信息，一个是Mark word，存储同步、GC等信息；另一部分是存该对象所属的类型的指针：

![Hotspot synchronization](https://wiki.openjdk.java.net/download/attachments/11829266/Synchronization.gif?version=4&modificationDate=1208918680000&api=v2)



# Hotspot锁实现
## 轻量级加锁过程（thin lock）
对于一个未锁定的对象，如果不允许偏向，那么当线程尝试给这个对象加锁的时候，首先尝试使用轻量级锁定，步骤如下：

* 首先在当前线程的桢栈中创建一个lock record信息，保存对象的mark word，然后尝试通过CAS把这个lock record的地址设置到对象的header word中
* 如果CAS成功，那么当前线程成功获取到锁，这时候最后两位是00，表示对象被轻量级锁定
* 如果CAS失败，这时候首先需要判断一下当前线程是否已经持有锁（存在当前线程递归获取锁的场景；但CAS比较的时候，比较的条件是按照对象未锁定的场景去比较的，所以即使对象已经被轻量级锁定了，在CAS之前根本没有去判断），如果是则表明当前线程已经取得锁，可以继续执行
* 如果不是，那么说明有两个线程同时尝试锁定一个对象，这时候需要膨胀为重量级锁

```c++
// bytecodeInterpreter.cpp
 if (!success) {
   markOop displaced = rcvr->mark()->set_unlocked();
   mon->lock()->set_displaced_header(displaced);
   if (Atomic:: (mon, rcvr->mark_addr(), displaced) != displaced) {
     // Is it simple recursive case?
     if (THREAD->is_lock_owned((address) displaced->clear_lock_bits())) {
       mon->lock()->set_displaced_header(NULL);
     } else {
       CALL_VM(InterpreterRuntime::monitorenter(THREAD, mon), handle_exception);
     }
   }
 }
```

而当线程运行完成之后，还需要把对象的mark word还原回去：

* 从线程的栈中获取原来的mark word，尝试使用CAS设置到对象上
* 如果成功，那么不需要做其他事情
* 如果失败，表明已经膨胀为重量级锁了，需要通知到等待线程

对于同一个线程递归锁定的场景，如果上一步CAS失败发现已经被自己持有锁，这个时候在栈上的lock record中设置为0，个人理解是如果设置为0那么在解锁的时候，可以控制不采用CAS恢复对象mark word，而是等到第一个lock操作对应的unlock操作的时候去恢复。

## 偏向锁（Store-Free Biased Locking）
轻量级加锁解决的问题就是，多个线程交替地去获取锁，但实际没有并发争用。在实际的软件中，还有许多场景是，一个对象在生命周期内由始至终只有一个线程会去锁定，那么，在这这种情况下是否可以避免反复的CAS操作，而是直接”偏向“让原来持有锁的线程获取锁呢？

Java对象初始化的时候的header word有会有一个是否允许偏向的标志位：

* 如果该类可以使用偏向锁，则对象包含thread id（初始化位0），biased_lock=1表示允许偏向
* 如果该类不可以使用偏向锁，则对象包含一个hash code，biased_lock被设置位0表示不允许偏向

那么，在尝试加锁的过程中，如果发现允许偏向，则步骤如下：

* 尝试通过CAS，将当前线程ID、epoch等替换到对象头中，这是唯一的一次CAS操作，称之为initial lock
* 当线程持有对象的偏向锁之后，后续该线程的加锁和解锁无需额外的CAS操作或者更新对象头

而当一个线程尝试对一个偏向其他线程的对象加锁的时候，需要撤销偏向锁，并把现场恢复成好像是通过thin lock锁住这个对象一样。这时候进行的步骤如下：

* 停止偏向锁持有线程到安全点
* 遍历偏向锁的持有线程的栈，调整lock record为thin lock的模式；并把最开始的lock record设置到对象的header中
* 恢复线程，按照thin lock的方式执行（包括膨胀机制）



Reference:

* https://docs.huihoo.com/javaone/2006/java_se/JAVA%20SE/TS-3412.pdf
* https://fliphtml5.com/tzor/bqxz/basic
* https://www.artima.com/insidejvm/ed2/index.html
* [OpenJDK Wiki - Synchronization](https://wiki.openjdk.java.net/display/HotSpot/Synchronization)
* https://www.zhihu.com/question/53826114
* [Biased Locking in HotSpot](https://blogs.oracle.com/dave/biased-locking-in-hotspot)
http://gee.cs.oswego.edu/dl/jmm/cookbook.html
* [Eliminating synchronization-related atomic operations with biased locking and bulk rebiasing](https://www.semanticscholar.org/paper/Eliminating-synchronization-related-atomic-with-and-Russell-Detlefs/356a2d9859520c9161d67828d45e758a24ecce20)
* https://www.javazhiyin.com/24364.html
* https://pdfs.semanticscholar.org/b8e4/cb0c212fd799522817b914ffcd24470f707e.pdf?_ga=2.218049237.2144104280.1590746224-418849090.1590746224