在微服务实践中，也许一致性是最头疼的问题了，因为跨数据库的事物将变得十分困难。我们让每一个微服务的数据存储都私有化来实现服务之间的解耦，无可避免存在很多业务需要操作多个微服务的数据库，可能不仅仅是跨服务的不同表，还可能是不同的数据库类型。如果我们采用一个数据库可能事情就会简单了，但这就脱离了微服务的真正价值了。


现阶段解决分布式事物大致有这些方案：

* [2PC](https://en.wikipedia.org/wiki/Two-phase_commit_protocol)
* [3PC](https://en.wikipedia.org/wiki/Three-phase_commit_protocol)
* [Paxos](https://en.wikipedia.org/wiki/Paxos_(computer_science))和[Raft](https://raft.github.io/)
* [TCC](http://cdn.ttgtmedia.com/searchWebServices/downloads/Business_Activities.pdf)

姑且不论实现的复杂性，以上方案大多数可以实现[最终一致性](https://en.wikipedia.org/wiki/Eventual_consistency)。为什么说大多呢？因为太复杂了，我还没研究清楚...

而Event Sourcing目测是一个更简单的实现最终一致性的方案，采用Event Sourcing + CQRS来实现读写分离，具体是什么关系呢?这里引用一点：
>在CQRS中，查询方面，直接通过方法查询数据库，然后通过DTO将数据返回。在操作(Command)方面，是通过发送Command实现，由CommandBus处理特定的Command，然后由Command将特定的Event发布到EventBus上，然后EventBus使用特定的Handler来处理事件，执行一些诸如，修改，删除，更新等操作。这里，所有与Command相关的操作都通过Event实现。这样我们可以通过记录Event来记录系统的运行历史记录，并且能够方便的回滚到某一历史状态。Event Sourcing就是用来进行存储和管理事件的。

再来看一张图:

![CQRS](https://www.codeproject.com/KB/architecture/555855/CQRS.jpg)

参考文章:

* [基于Event Sourcing和DSL的积分规则引擎设计实现案例 ](https://mp.weixin.qq.com/s?__biz=MzA5Nzc4OTA1Mw==&mid=2659597948&idx=1&sn=754df1597fd042537be8c25d073d3c98&scene=0#rd)
* [Event-Driven Data Management for Microservices](https://www.nginx.com/blog/event-driven-data-management-microservices/)
* [CAP](https://en.wikipedia.org/wiki/CAP_theorem)
* [Focusing on Events](https://martinfowler.com/eaaDev/EventNarrative.html)
* [Retroactive Event](https://www.martinfowler.com/eaaDev/RetroactiveEvent.html)
* [Domain Event](https://www.martinfowler.com/eaaDev/DomainEvent.html)
* [Event-Sourcing+CQRS example application](https://github.com/cer/event-sourcing-examples)
* [领域驱动设计(Domain Driven Design)参考架构详解](http://kb.cnblogs.com/page/161050/)
* [CQRS, Task Based UIs, Event Sourcing agh!](http://codebetter.com/gregyoung/2010/02/16/cqrs-task-based-uis-event-sourcing-agh/)
* [Introduction to CQRS](www.codeproject.com/Articles/555855/Introduction-to-CQRS)
* [Event Sourcing in practice](https://ookami86.github.io/event-sourcing-in-practice/)
* [Event Sourcing vs Command Sourcing](http://thinkbeforecoding.com/post/2013/07/28/Event-Sourcing-vs-Command-Sourcing)