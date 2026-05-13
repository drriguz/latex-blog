#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Why I don't use lombok",
  date: "2018-01-10",
  tags: ("开发实践", "lombok", "annotation processing", "闲话编程"),
  lang: "zh",
)

很多人，如同我的同事，似乎觉得lombok这玩意就像神一样的存在，"极大"的方便了项目的开发。我个人是不喜欢这玩意的，很简单的理由：

- 生成getter/setter不是多么困难的事情，IDE很简单就能帮你搞定
- 我不喜欢为自己的IDE装一大堆插件，还要为项目手动开启一下Annotation
  Processing
- 代码不可见，意味着生成的getters/setter方法，以及\@AllArgConstructor生成的方法无法维护

当我把这些想法告诉同事的时候，同事们都觉得我脑子有问题，理由不充分，"lombok只是一个工具，只是没有找到使用工具的最佳实践"。实际上对于技术人员来说，想说服别人是很困难的事情，然而我们为什么要试图说服别人呢？没有多大的意义。相比于工具，有一些更重要的东西就是：经验和原则。

就我的经验，能简单的事情就不要复杂化，越是复杂越难以维护。当然也有人和我是相同的观点，看了一些有意思的关于为什么不用lombok的讨论，贴出来看看：

#quote(block: true)[
OK, let me put it one more time: this has caused me too many bugs. Let
me tell you my past experiences with Lombok, as this is the root of the
issue.

On one project, a new version of the Lombok plugin caused the IDE to
crash (I think this was Intellij). So nobody could work anymore. On
another project, Lombok made the CI server crash (and would have
probably caused the production server to crash), as it triggered a bug
in the JVM On a third project, we achieved 30% performance increase by
recoding the equals/hashcode from Lombok -\> In those 3 projects, some
developer gained 5 minutes, and I spent hours recoding everything. So
yes, a bad experience.

Then, for JHipster, the story is also that we can't ask people to
install a plugin on their IDE:

1st goal is to have a smooth experience: you generate the app and it
works in your IDE, by default 2nd goal is that you can use whatever IDE
you want. And some people have very exotic things, for example I just
tried https:/\/codenvy.com/ -\> no plugin for this one, of course

Oh, and I just got 2 more:

Lombok crashing with MapStruct Lombok making Jacoco fails, which meant
the project didn't pass the Sonar quality gate
]

参考阅读：

- https:/\/github.com/jhipster/generator-jhipster/issues/398
- https:/\/gist.github.com/ufuk/0ccb87185c22475c64d46801fa160777
- https:/\/stackoverflow.com/questions/3852091/is-it-safe-to-use-project-lombok
