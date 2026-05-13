#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "一个简单的ETL程序",
  date: "2020-05-04",
  tags: ("小实现", "MySQL", "ETL", "闲话编程"),
  lang: "zh",
)

这两天闲着没事准备玩一下社工库，网上有很多以前的社工库（这些都可以下载到，但是实际上已经没有什么太大的价值了，因为暴露时间太久，以及相关的网站都已经做了处理，所以别指望能够找到什么有价值的东西），通过社工库可以了解到的一个实际的数据就是，用户的设置的密码大都是什么样子的。我准备看一下搜云社工库，这个库大概4亿多条数据，主要目的是实践一下大量数据的处理。

= 还原原始数据库
<还原原始数据库>
这个库（下载地址请自行搜索）下载完成之后是一个`1.bak`（SQL
SERVER的备份文件）文件，接近30G，网上有详细的教程如何导入，总结起来大致如下:

- 安装SQL SERVER 2008 R2（标准版或者更高）
- 将1.bak复制到SQL SERVER的实例备份目录，否则会无法导入
- 因为还原后的数据库占用空间在130G，所以要保证数据库的存储磁盘空间足够

还原完成之后即可得到一个sgk的数据表，里面有423771078条数据。

= 导入到MySQl
<导入到mysql>
因为最终希望能够在MYSQL中使用数据，所以还得将数据迁移到MySQL中。最初的想法是直接将数据导出到csv，然后再通过MySQL导入csv。但是这个方法尝试了几次之后发现一些问题：

- 数据中可能存在一些非可见字符，导致导出后的csv格式混乱
- 莫名其妙的问题无法解析

索性就直接放弃了这种方式，而是通过手写ETL来完成迁移。于是设计了一个简陋的ETL程序，还挺有意思的。

== 整体架构
<整体架构>
ETL的主要目的是把数据从一个地方转移迁移到另一个地方，这其中可能进行一些其他的操作比如清洗或者格式转换。整体的思路是这样的：

- 有一个source（源数据）和destination（目标数据源）
- ETL执行的时候从源数据查询数据，然后保存到目标数据库中，为了提高效率，每次会查询一批数据，保存的时候也会一批一批保存
- 为进一步提高性能，ETL可以设定多个线程同时处理，为了避免冲突，每个线程不会处理同一条数据，是互斥的

== ETL Engine
<etl-engine>
```java
public class Engine {
    private static final Logger logger = LoggerFactory.getLogger(Engine.class);

    private final int threads;
    private final int totalCount;
    private final int batchSize;

    private final HikariDataSource source;
    private final HikariDataSource destination;

    private final AtomicLong rangeSelector = new AtomicLong(0);

    private final List<Thread> tasks = new ArrayList<>();

    public Engine(int threads, int totalCount, int batchSize) {
        this.threads = threads;
        this.totalCount = totalCount;
        this.batchSize = batchSize;
        this.source = new HikariDataSource(new HikariConfig("src/main/resources/source.properties"));
        this.destination = new HikariDataSource(new HikariConfig("src/main/resources/destination.properties"));
    }
```

这个ETL引擎担负管理任务的角色，有这些参数：

- threads: 可以设定多少个线程同时运行；
- totalCount:
  设定一个totalCount作为任务结束的条件（当然也可以在查询不到数据的时候结束)
- batchSize: 每一批的大小
- rangeSelector: 用来控制每个线程处理的数据，这里将直接用id来区分

同时直接初始化了两个数据库的连接池，这里选用的是Hikari连接池。

```java
public void run() throws InterruptedException {
    final CountDownLatch countDownLatch = new CountDownLatch(threads);
    for (int i = 0; i < threads; i++) {
        Thread thread = new Thread(new Task(source,
                destination,
                totalCount,
                rangeSelector,
                batchSize,
                countDownLatch));
        tasks.add(thread);
    }
    tasks.forEach(Thread::start);
    countDownLatch.countDown();
    countDownLatch.await();
}
```

核心逻辑就是，启动N个线程，然后一直等待到每个线程都结束，即完成了ETL任务。

== Task
<task>
Task对应到每个线程，每个线程处理的任务是一样的，只是处理的数据记录不同。

```java
public void run() {
    logger.info("ETL task {} running...", Thread.currentThread().getId());
    try (Connection sourceConn = source.getConnection();
         Connection destinationConn = destination.getConnection()) {
        while (true) {
            final long startId = rangeSelector.getAndAdd(batchSize);
            final long endId = startId + batchSize;
            if (startId > totalCount) {
                logger.info("Reached end of records:{} , task finished", startId);
                break;
            }
            job.doTransfer(sourceConn, destinationConn, startId, endId);
        }
    } catch (SQLException ex) {
        logger.error("Failed to get data source, ex");
    } finally {
        logger.info("ETL task {} finished.", Thread.currentThread().getId());
        countDownLatch.countDown();
    }

}
```

处理过程也很简单，拿到一个connection之后，根据rangeSelector得到要获取的id范围，然后委派给具体的Job去处理。当超出最大范围的时候，停止该线程。

== Job
<job>
Job对应到具体每条数据该如何传输，会稍微麻烦一点。但本质还是select然后insert，没什么技术含量。

```java
public class SeTransferJob implements TransferJob {
    private static final Logger logger = LoggerFactory.getLogger(SeTransferJob.class);
    private static final String query = "select * from sgk where id >? and id <=?";
    private static final String insertSqlTemplate = "insert into se_record_%d(id, user_name, email, password, salt, source, remark) values (?,?,?,?,?,?,?);";

    @Override
    public void doTransfer(Connection source, Connection target, long startId, long endId) {
        logger.info("Transferring records [{}, {}]", startId, endId);

        try {
            target.setAutoCommit(false);
        } catch (SQLException throwables) {
            throw new RuntimeException("Cannot open transaction");
        }
        long tableIndex = (startId / 10000000) + 1;
        String insertSql = String.format(insertSqlTemplate, tableIndex);
        try (PreparedStatement queryStatement = source.prepareStatement(query);
             PreparedStatement saveStatement = target.prepareStatement(insertSql)) {
            queryStatement.setLong(1, startId);
            queryStatement.setLong(2, endId);
            try (ResultSet result = queryStatement.executeQuery()) {
                while (result.next()) {
                    Record record = Record.from(result);
                    if (!record.isValid()) {
                        logger.warn("Found invaid record:{}", record);
                    } else {
                        record.attach(saveStatement);
                        saveStatement.addBatch();
                    }
                }
            }
            saveStatement.executeBatch();
            target.commit();
            logger.info("Records [{}, {}] -> se_record_{} commited", startId, endId, tableIndex);
        } catch (SQLException ex) {
            logger.error("Unexpected sql error:", ex);
            throw new RuntimeException(ex);
        }
    }
}
```

这里因为数据量太大，做了一个分区的处理，直接按照id来进行分区，每个表控制在千万以下。因此导入完成后，最终会有40多个表，每个表有接近1千万的数据。否则单表过大之后的插入性能会变得很低。

以上就是整个ETL的核心思想，还是有一定的扩展性的，哈哈。
