你如果以为，Java中谈到时间仅仅就意味着`java.util.Date`那就大错特错了，Java中的时间其实可以说五花八门，Java8发布后又增加了一些新的用来表示日期和时间的类，那么我们在构建应用程序的时候到底应该用哪个类来呢？彼此之间又有什么区别？



# 关于时间的表示
通常由于文化和地区的不同，世界上各个地方的人们对于时间的表达方式都不尽相同，比如在中国以前用农历和十二时辰来表示，而在西方是二十四小时制（巧合的是正好一个时辰能对应上两个小时，据称与”高合成数“有关）。那么在计算机领域，在表示时间的时候也有不同的表示方法，比较常见的有：

* 通过计算当前时间到Jan 01 1970(Unix Epoch)这一天（准确的说是00：00）经过的秒数来表示，例如 `1573090869`。
* 比较直接的方法就是直接以时分秒的形式表示当地时间，同时将当地的时区加进去，例如 `2001-07-04T12:08:56.235-07:00`

# Java中的时间类
抛开时间戳不谈，在Java中专门用来表示时间的其他类有：

Class                     Since       Description
------------------------- ----------- -----------------------
java.util.Date            JDK1.0      日期+时间
java.util.Calendar        JDK1.1
java.sql.Date                         只包含日期
java.sql.Time                         只包含时间
java.sql.Timestamp
java.time.Instant         JDK1.8     
java.time.LocalTime       JDK1.8
java.time.LocalDate       JDK1.8
java.time.OffsetTime      JDK1.8
java.time.OffsetDateTime  JDK1.8
java.time.ZonedDateTime   JDK1.8

在Java8之前，我们通常用`java.util.Date`来表示时间，虽然没啥需求实现不了的，但有着以下的问题：

* 时间类不统一，`java.util`和`java.sql`包中都有关于时间的类，而时间格式化的又在`java.text`包中，有点乱的很
* 所有时间的类都是mutable的，非线程安全

所以Java8开始对时间进行了修改，使用起来将更加方便。通常来讲，对于需要处理时区问题的系统，`OffsetDateTime`是一个较好的选择，即包含了时间信息，又包含了时区的信息，可以得到准确的时间表述。官方文档中也建议使用：

>It is intended that ZonedDateTime or Instant is used to model data in simpler applications. This class may be used when modeling date-time concepts in more detail, or when communicating to a database or in a network protocol.

在处理类似时间转换的时候，可以借助`ZonedDateTime`来实现。例如有一个`yyyyMMddHHmmss`格式的时间，但该时间是`CST`时间，这个时间有如下的特点：

* 在夏季时间相当于utc+5
* 在冬季相当于utc+6

而每年会有一个时间点去切换这个夏季时间和冬季时间（称之为day-saving)，而且不是一个固定的日期（大致相当于按照第几个星期几来算的），要想把这个时间转换为标准的时间描述，可以采取这样的方式:

```java
LocalDateTime localDateTime = LocalDateTime.parse(
    "20191010095425", DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
ZonedDateTime zonedDateTime = ZonedDateTime.of(
    localDateTime, TimeZone.getTimeZone("CST"));
OffsetDateTime result = zonedDateTime
    .toOffsetDateTime()
    .withOffsetSameInstant(ZoneOffset.UTC);
```

* [What's the difference between java 8 ZonedDateTime and OffsetDateTime?](https://stackoverflow.com/questions/30234594/whats-the-difference-between-java-8-zoneddatetime-and-offsetdatetime)
* [OffsetDateTime](https://docs.oracle.com/javase/8/docs/api/java/time/OffsetDateTime.html)
* [ZonedDateTime](https://docs.oracle.com/javase/8/docs/api/java/time/ZonedDateTime.html)