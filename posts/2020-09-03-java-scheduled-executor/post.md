除了ThreadPoolExecutor之外，还有一种`ScheduledExecutorService`支持按照一定的延迟或者固定的间隔来执行任务。

```java
ScheduledExecutorService executorService = Executors
	  .newSingleThreadScheduledExecutor();
```


譬如实现一个定时运行的任务：

```java
public class BeeperControl {
    private final ScheduledExecutorService scheduler =
            Executors.newScheduledThreadPool(1);

    public void beep() {
        scheduler.scheduleAtFixedRate(() -> {
            System.out.println("beep");
        }, 3, 2, TimeUnit.SECONDS);
    }

    public static void main(String[] args) {
        BeeperControl ctl = new BeeperControl();
        ctl.beep();
    }
}
```
#  Schedule模式
## FixedRate
FixedRate允许按照固定的速率来运行，例如：

```java
 scheduler.scheduleAtFixedRate(() -> {
            System.out.println("beep");
        }, 3, 2, TimeUnit.SECONDS); // 最开始延迟3秒；之后每2秒一次运行
```

假定开始时间为$T_0$，那么任务的运行时间为：

* $T_1 = T_0 + InitialDelay$
* $T_2 = T_1 + Period \times 1$
* $T_n = T_1 + Period \times (n - 1)$

但是这里存在一个问题，就是如果当任务的执行时间大于Period的时候，会怎样执行？

实际情形就是，如果执行时间超过了period, 那么在运行结束之后，下一个任务会立即执行。而Executor的行为是根据上面的公式创建并提交任务，也就意味着，假设period是2秒钟，而第一次执行花费了5秒，那么在这段时间之内不止一个（下一次的）任务被提交，那么后面若干次都会立刻执行，如下所示：

```
start:1599108257     开始时间
beep :(5)1599108260  第一次执行，花费5秒
beep :(1)1599108265  第二次执行，（以后每次都）花费1秒
beep :(1)1599108266  立即执行
beep :(1)1599108267  立即执行
beep :(1)1599108268  立即执行
beep :(1)1599108270  间隔2秒
beep :(1)1599108272
beep :(1)1599108274
beep :(1)1599108276
beep :(1)1599108278
beep :(1)1599108280
```

虽然我们实际上可以配置线程池，但是根据JDK文档描述，不会出现同时运行多个任务的情况：

> If any execution of this task takes longer than its period, then subsequent executions may start late, but will not concurrently execute.

所以实际上，这个线程池是为了配置多个scheduler使用的，也就是说，调用多次`scheduler.scheduleAtFixedRate`创建了很多任务，那么这些任务是有可能会同时执行的，这个时候，就会利用到线程池了。假设线程池中只有一个线程，那么如果两个任务都需要执行，而这时候第一个任务没有执行完成，是需要等到第一个任务执行完之后才能得到空闲的线程来执行第二个任务的。

## FixedDelay
FixedRate允许按照固定的间隔来运行，例如：

```java
 scheduler.scheduleAtFixedRate(() -> {
            System.out.println("beep");
        }, 3, 2, TimeUnit.SECONDS); // 最开始延迟3秒；之后每次在上一次完成之后延迟2秒执行
```

假定开始时间为$T_0$，第n次任务执行时间为$P_n$，那么任务的开始执行时间为：

* $T_1 = T_0 + InitialDelay$
* $T_2 = T_1 + P_0 + Delay$
* $T_n = T_(n-1) + P_(n-1) + Delay$

也就是说这个延迟是算上了程序运行的时间的。

# 与timer的区别

* Timer会受到系统时钟（改变）的影响
* Timer只有一个执行线程，对于长时间运行的任务会导致阻塞后续任务
* Timer中如果抛出异常那么直接就整个都结束了；而ScheduledThreadExecutor中默认处理了异常（会cancel抛出异常的任务），但是其他的任务还可以继续执行。

ref:

* [Java Timer vs ExecutorService?](https://stackoverflow.com/questions/409932/java-timer-vs-executorservice)