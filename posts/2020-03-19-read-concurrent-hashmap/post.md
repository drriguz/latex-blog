我们知道HashMap不是Thread-safe的，而HashTable内部采取了同步操作，是线程安全的。然而有趣的是你去看HashTable的文档，它会建议你：如果不要Thread-Safe你就用HashMap吧，否则你用ConcurrentHashMap好了。

一般如果对线程安全有要求，我们有如下的一些选择：

* ConcurrentHashMap
* Hashtable
* Collections.synchronizedMap



# Collections.synchronizedMap

这个实现很粗暴，实际上就是将Map的各个操作都进行了包装和同步：

```java
private static class SynchronizedMap<K,V>
        implements Map<K,V>, Serializable {
    private final Map<K,V> m;     // Backing Map
    final Object      mutex;  

    SynchronizedMap(Map<K,V> m) {
        this.m = Objects.requireNonNull(m);
        mutex = this;
    }
```

在构造函数中传入了原来的Map，以及一个对象锁（如果不传那就默认是this了）。然后，所有的操作都进行了同步处理：

```java
public boolean containsValue(Object value) {
    synchronized (mutex) {return m.containsValue(value);}
}
public V get(Object key) {
    synchronized (mutex) {return m.get(key);}
}
// ...
```

# HashTable

HashTable实现线程安全的方式与上面有些类似，对所有需要同步的地方直接进行了同步：

```java
public synchronized int size() {
    return count;
}
```

那么HashMap和HashTable有什么区别呢？除了同步之外，总结下来有以下几点：

* HashMap允许一个null的key，value也可以为null；但是HashTable不允许null作为key或者value
* HashMap是JDK1.2才引入的
* HashTable是基于Dictionary接口实现的

HashTable（以及ConcurrentHashMap）都是不允许null值作为Key和Vaule的，主要的原因是因为要支持并发，假设调用`get(key)`得到了null，你是不能确认是key不存在，还是说存在但是值为null。在非并发场景下可以通过`contains(key)`来判断是否真的存在，但是在并发场景下，很可能会被其他线程修改。在JDK注释中有这样的解释：

> The main reason that nulls aren't allowed in ConcurrentMaps (ConcurrentHashMaps, ConcurrentSkipListMaps) is that ambiguities that may be just barely tolerable in non-concurrent maps can't be accommodated. The main one is that if map.get(key) returns null, you can't detect whether the key explicitly maps to null vs the key isn't mapped. In a non-concurrent map, you can check this via map.contains(key), but in a concurrent one, the map might have changed between calls.

# ConcurrentHashMap
在Java1.7和1.8中ConcurrentHashMap实现差别较大，在1.7中采用分段锁的方式实现，将Map分为许多个Segment（Segment继承自ReentrantLock）,操作的时候，只会去占用某一个Segment，而其他的Segment不会受到影响。

而在1.8中直接使用CAS+ synchronized来实现。其在内存中的结构与HashMap几乎相同了。

## get操作

```java
public V get(Object key) {
    Node<K,V>[] tab; Node<K,V> e, p; int n, eh; K ek;

    // 得到最终的hash值（将高位混合到低位去避免哈希冲突）
    int h = spread(key.hashCode());
    if ((tab = table) != null && (n = tab.length) > 0 &&
        // (n-1) & h 计算出所在的index值（与HashMap相同）
        (e = tabAt(tab, (n - 1) & h)) != null) { 
        // 如果哈希值相同，则直接定位到节点，再判断是否equal即可
        if ((eh = e.hash) == h) {                
            // 这里比较key是否equal，单纯只凭hashCode是不够的。
            // 首先比较内存地址是否一致；然后再调用equals方法，是一种优化手段。
            if ((ek = e.key) == key || (ek != null && key.equals(ek)))
                return e.val;
        }
        /*
            Hash值的首位被用作标记位，为负数的hash值是特殊的节点（也就是红黑树化了）
        */
        // 如果根据哈希值没有匹配到，那证明可能有哈希冲突，为负数是红黑树则在树中查找
        else if (eh < 0)                         
            return (p = e.find(h, key)) != null ? p.val : null;
        // 否则是普通的链表，在链表中一直朝下找即可
        while ((e = e.next) != null) {           
            if (e.hash == h &&
                ((ek = e.key) == key || (ek != null && key.equals(ek))))
                return e.val;
        }
    }
    return null;
}
```

可见get操作没有加任何的锁，而是通过将`transient volatile Node<K,V>[] table;`将table设置为volatile来保证可见性的。

```java
transient volatile Node<K,V>[] table;

static class Node<K,V> implements Map.Entry<K,V> {
    final int hash;
    final K key;
    volatile V val;
    volatile Node<K,V> next;
    //...
}
```

## put操作

```java
final V putVal(K key, V value, boolean onlyIfAbsent) {
    if (key == null || value == null) throw new NullPointerException();
    int hash = spread(key.hashCode());
    int binCount = 0;
    for (Node<K,V>[] tab = table;;) {
        Node<K,V> f; int n, i, fh;
        // 因为是懒加载，第一次插入的时候可能需要初始化
        if (tab == null || (n = tab.length) == 0)
            tab = initTable();
        // 没有找到（节点之前不存在）
        else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) {
            // 尝试CAS插入节点到空桶中，如果失败，则会重新走上面的流程进来
            if (casTabAt(tab, i, null,
                         new Node<K,V>(hash, key, value, null)))
                break;                   // no lock when adding to empty bin
        }
        // 如果（后面的流程）插入到了红黑树中，会导致首节点改变，所以这个地方需要帮忙更改过来
        else if ((fh = f.hash) == MOVED)
            tab = helpTransfer(tab, f);
        else {
            V oldVal = null;
            // f为当前定位到的桶中的第一个节点，将其同步进行后续操作
            synchronized (f) {
                // 看看同步之前当前节点是否已经被更改了；如果是则需要重新开始轮回
                if (tabAt(tab, i) == f) {
                    // 普通链表
                    if (fh >= 0) {
                        binCount = 1;
                        for (Node<K,V> e = f;; ++binCount) {
                            K ek;
                            // 如果已经存在值
                            if (e.hash == hash &&
                                ((ek = e.key) == key ||
                                 (ek != null && key.equals(ek)))) {
                                oldVal = e.val;
                                if (!onlyIfAbsent)
                                    e.val = value;
                                break;
                            }
                            // 不存在则新增一个节点，插入到链表尾部
                            Node<K,V> pred = e;
                            if ((e = e.next) == null) {
                                pred.next = new Node<K,V>(hash, key,
                                                          value, null);
                                break;
                            }
                        }
                    }
                    // 按红黑树处理
                    else if (f instanceof TreeBin) {
                        Node<K,V> p;
                        binCount = 2;
                        if ((p = ((TreeBin<K,V>)f).putTreeVal(hash, key,
                                                       value)) != null) {
                            oldVal = p.val;
                            if (!onlyIfAbsent)
                                p.val = value;
                        }
                    }
                }
            }
            if (binCount != 0) {
                if (binCount >= TREEIFY_THRESHOLD)
                    treeifyBin(tab, i);
                if (oldVal != null)
                    return oldVal;
                break;
            }
        }
    }
    addCount(1L, binCount);
    return null;
}
```

* [Difference between HashMap and Hashtable](https://www.javatpoint.com/difference-between-hashmap-and-hashtable)