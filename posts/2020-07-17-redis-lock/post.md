Redis一个比较重要的应用场景就是分布式锁DLM (Distributed Lock Manager)。实际上已经有很多现成的redis库来完成这个功能了，但是可能实现途径有所差别，那么，正确的做法是什么呢？Redis官方建议了一个算法叫做`Redlock`，可以将其作为起点去实现更复杂的方案，来研究一下它的思路。



# 原则

要实现分布式锁得满足一些必要的条件：

* 互斥性：任意时刻只能有一个客户端能够成功获取锁
* 避免死锁：即使锁的持有者crash
* 容错性：只要redis集群大多数节点正常，客户端就能够获取或者释放锁

有一些常见的做法并不是安全的锁实现方式。

最简单的做法是，获取锁时，在redis创建一个带有过期时间的key。当需要释放锁时，删除这个key。这种做法无法避免单点故障，如果redis master宕机，则无法成功获取或者释放锁了。如果添加一个slave节点呢？很不幸也行不通，因为redis的主从复制是异步的，由此带来竞争：

* Client A 在master节点上获取了锁
* master节点在将数据同步到slave之前crash掉了
* slave提升为新的master
* Client B于是可以获取到相同的锁了（不满足互斥性）

# redis单机下的正确做法

在不考虑redis集群的情况下，如何正确的实现一个分布式锁呢？其实也比较简单：

加锁：

```bash
SET resource_name my_random_value NX PX 30000
```
其中，`NX`保证只有在key不存在的情况下才会被设置到redis中，`PX 30000` 设置了过期时间为30000毫秒。而key的值被设置为一个随机值，这个值必须在所有的客户端和加锁请求中唯一。之所以要这么做，是为了保证能够安全的释放锁，只有当key存在，且是由锁的持有者发起的解锁请求的时候，才删除这个key：

```lua
if redis.call("get",KEYS[1]) == ARGV[1] then
    return redis.call("del",KEYS[1])
else
    return 0
end
```

主要避免的一个问题就是，锁被其他的客户端给错误地释放了（有可能客户端释放锁的时候，因为某些原因锁已经过期了，但是其他的客户端已经获得了锁）。而锁的过期时间（或者说有效期），应该足够client完成操作，避免任务在进行的过程中其他客户端又获得了锁。

在单机的情况下以上就实现了一个较为完美的锁，如果要扩展到redis集群呢？

# Redlock 算法
(TBD)


* [Distributed locks with Redis](https://redis.io/topics/distlock)