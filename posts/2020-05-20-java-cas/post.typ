#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "理解Java并发(3)：CAS",
  date: "2020-05-20",
  tags: ("Hotspot", "JVM", "并发编程", "Concurrent", "~理解Java并发", "刨根问底"),
  lang: "zh",
)

CAS：Compare and
Swap，即比较再交换。jdk5增加了并发包java.util.concurrent.\*,其下面的类使用CAS算法实现了区别于synchronouse同步锁的一种乐观锁。

= 实现机制
<实现机制>
在Java中很多原子操作是通过CAS实现的，是一种无锁的方式，比如AtomicIntger的自增操作：

```java
public class AtomicInteger extends Number implements java.io.Serializable {
    private static final long serialVersionUID = 6214790243416807050L;

    // setup to use Unsafe.compareAndSwapInt for updates
    private static final Unsafe unsafe = Unsafe.getUnsafe();
    private static final long valueOffset;

    static {
        try {
            valueOffset = unsafe.objectFieldOffset
                (AtomicInteger.class.getDeclaredField("value"));
        } catch (Exception ex) { throw new Error(ex); }
    }

    private volatile int value;
    // ...
    public final int getAndIncrement() {
        return unsafe.getAndAddInt(this, valueOffset, 1);
    }
    // ...
}
```

这里的操作调用了Unsafe类来实现，而这个Unsafe类里面的实代码是这样的：

```java
public final native boolean compareAndSwapInt(Object var1, long var2, int var4, int var5);
public final int getAndAddInt(Object var1, long var2, int var4) {
    int var5;
    do {
        var5 = this.getIntVolatile(var1, var2);
    } while(!this.compareAndSwapInt(var1, var2, var5, var5 + var4));
    return var5;
}
```

而最终是用到了native的方法compareAndSwapInt，这部分的源码可以在OpenJDK源码中找到，而最终是会调用到#link("https://www.felixcloutier.com/x86/cmpxchg")[CMPXCHG]这样到CPU指令来完成CAS。

```cpp
UNSAFE_ENTRY(jboolean, Unsafe_CompareAndSwapInt(JNIEnv *env, jobject unsafe, jobject obj, jlong offset, jint e, jint x))
  UnsafeWrapper("Unsafe_CompareAndSwapInt");
  oop p = JNIHandles::resolve(obj);
  jint* addr = (jint *) index_oop_from_field_offset_long(p, offset);
  return (jint)(Atomic::cmpxchg(x, addr, e)) == e;
UNSAFE_END
```

其中，源码位于：

- #link("http://hg.openjdk.java.net/jdk8/jdk8/hotspot/file/tip/src/share/vm/prims/unsafe.cpp")[openjdk8/unsafe.cpp]
- #link("http://hg.openjdk.java.net/jdk8/jdk8/hotspot/file/tip/src/share/vm/runtime/atomic.cpp")[openjdk8/atomic.cpp]

= ABA问题
<aba问题>
使用CAS一个问题就是可能出现A-B-A问题，因为CAS到逻辑就是，假设更新到时候判断出值跟期望的一致那么就会进行更改；但实际值跟期望的一致并不能代表值没有发生过变化。可能的场景就是，值被改成别的然后又改回来了，就是从A-B，然后又变成A。

解决这个问题的思路在于，想办法标记出变化。通常的做法是利用版本号（而不是值），保证版本号每次都会变化。JDK中提供了AtomicStampedReference来解决A-B-A问题，实现如下：

```java
 public boolean compareAndSet(V   expectedReference,
                              V   newReference,
                              int expectedStamp,
                              int newStamp) {
     Pair<V> current = pair;
     return
         expectedReference == current.reference &&
         expectedStamp == current.stamp &&
         ((newReference == current.reference &&
           newStamp == current.stamp) ||
          casPair(current, Pair.of(newReference, newStamp)));
 }
```

References:

- https:/\/docs.huihoo.com/javaone/2006/java\_se/JAVA%20SE/TS-3412.pdf
- https:/\/fliphtml5.com/tzor/bqxz/basic
- https:/\/www.artima.com/insidejvm/ed2/index.html
- #link("https://wiki.openjdk.java.net/display/HotSpot/Synchronization")[OpenJDK Wiki - Synchronization]
- https:/\/www.zhihu.com/question/53826114
- #link("https://blogs.oracle.com/dave/biased-locking-in-hotspot")[Biased Locking in HotSpot]
- http:/\/gee.cs.oswego.edu/dl/jmm/cookbook.html
