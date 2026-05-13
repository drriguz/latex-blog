#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "使用Vagrant来管理Virtualbox",
  date: "2019-12-13",
  tags: ("Vagrant", "云计算", "容器化"),
  lang: "zh",
)

一直以来我用Virtualbox都是手动创建虚拟机，然后安装操作系统，虽然这个过程本身并不复杂但是也要重复操作和花费时间。通过Vagrant可以像使用Docker一样，编写脚本来管理虚拟机的配置，还可以通过公共的镜像仓库来获取一些别人已经构建好了的镜像。

= 创建新的虚拟机
<创建新的虚拟机>
通过Vagrant有两种方法来创建新的虚拟机：

- 使用vagrant命令生成一个Vagrantfile
- 手动编写Vagrantfile

例如，创建一个ubuntu的镜像，使用#link("https://app.vagrantup.com/ubuntu/boxes/trusty64")[ubuntu/trusty64]这个镜像，可以首先通过如下的命令在当前文件夹下生成一个Vagrantfile：

```bash
vagrant init ubuntu/trusty64
```

生成的Vagrantfile如下：

```bash
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"
end
```

Vagrantfile就相当于Dockerfile，可以定义虚拟机的一些配置，除此之外还可以定义一些其他的参数。然后，要启动它可以这样：

```bash
vagrant up
```

值得注意的是，截止目前，最新的Virtualbox6.1是不被Vagrant支持的，只能使用6.0.x版本。创建完成之后就可以在Virtualbox的控制页面看到这个虚拟机了。

#figure(image("images/Virtualbox.png", alt: "Virtualbox"),
  caption: [
    Virtualbox
  ]
)

= 解决下载很慢的问题
<解决下载很慢的问题>
有时候
