#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Mac上的LaTeX环境搭建",
  date: "2020-02-06",
  tags: ("TeX", "~LaTeX入门", "LaTeX", "其他"),
  lang: "zh",
)

一直希望能够自如的使用TeX来进行写作，但学习曲线还是比较高的，可惜断断续续一直没有能够入门。趁着这段时间疫情严重，待在家里又不想搞学习，那不如来重头开始学习一下吧。

= 一些相关的概念
<一些相关的概念>
TeX $\/t ɛ x\/$ 是高德纳（Donald Ervin
Knuth）教授编写的排版软件，通俗来讲就是跟Word差不多的东西，但是TeX就好像是Markdown一样，跟编程语言差不多，不是那种所见即所得的。以下是一些相关的概念：

== TeX Engine
<tex-engine>
TeX引擎就是实际可以运行TeX的二进制程序，主要有以下几种：

- Knuth的原始 TeX，只能支持plain
  tex格式，`tex <somefile>`这样。现在最新的版本是#link("ftp://ftp.cs.stanford.edu/pub/tex/tex14.tar.gz")[January 12, 2014发布的版本`3.14159265`]
- ε-TeX:
  1990s后期发布的对TeX的一组增强扩展，实际上除了原始的TeX引擎其他的引擎都已经默认支持了这些特性
- pdfTeX: pdfTeX包含了PDF
  和DVI格式的输出，被许多TeX的发行版用作默认的TeX引擎
- XeTeX: 同样包含了ε-TeX并原生支持Unicode和OpenType
- LuaTeX:
  基于pdfTeX并支持Luau脚本的TeX引擎，最初被作为pdfTeX的下一代版本但事实上形成了一个独立的分支。同样，它支持ε-TeX，使用UTF8，并能够支持嵌入Lua脚本

== TeX 格式
<tex-格式>
TeX是一个宏（macro）处理器，macro就像是编程语言中的函数一样，

```tex
\def\foo{bar}
```

上面这个指令会将所有的`\foo`替换成`bar`。基于TeX有不同的格式，实际上就是一些macro的集合，相当于提供了一些库供用户使用，主要有以下这些：

- Plain TeX：原始的TeX发行版包含的基本指令集
- LaTeX2e:
  LaTeX的最新稳定版本（最新的试验版本是LaTeX3），所有的TeX程序都支持LaTeX2e
- ConTex: 另一种TeX系统

== 发行版
<发行版>
TeX有许多种发行版，例如：

- #link("https://miktex.org/")[MiKTeX]: 支持Windows的一种发行版
- #link("http://tug.org/texlive/")[TeX Live]:
  许多Linux/Unix默认的TeX系统，也支持Windows和Mac
- #link("http://tug.org/mactex/")[MacTeX]: TeXLive的Mac版本

== 总结
<总结>
借用维基百科上的词条来总结一下吧，更加一目了然各个概念之间的区别：

#figure(image("images/tex-levels.png", alt: "TeX Concepts"),
  caption: [
    TeX Concepts
  ]
)

= Mac上的TeX环境
<mac上的tex环境>
Mac上推荐安装MacTeX。安装完成之后，可以看到一个TeXShop的编辑器，并可以在terminal中运行`tex`命令：

```
tex
This is TeX, Version 3.14159265 (TeX Live 2019) (preloaded format=tex)
**
```

然后就是选择编辑器了，网上有不少教程，基于VSCode或者Sublime
Text等的，在Mac上还有另一个选择就是Textmate了，在Textmate中安装`LaTeX`的Bundle即可，然后打开它的设置:

编写完成之后，使用Command + R运行即可预览：

值得注意的是，如果使用XeLaTeX要支持中文需要设置一下字体：

```tex
\documentclass{article}
\usepackage{fontspec}
\setmainfont{Hiragino Sans GB}
\begin{document}
 Hello，中国！
\end{document}
```

参考：

- #link("https://en.wikipedia.org/wiki/TeX#cite_note-13")[TeX]
- #link("https://tex.stackexchange.com/questions/49/what-is-the-difference-between-tex-and-latex")[What is the difference between TeX and LaTeX?]
- #link("http://tug.org/levels.html")[LaTeX vs.~MiKTeX: The levels of TeX]
- #link("https://www.latex-tutorial.com/tutorials/")[A simple guide to LaTeX - Step by Step]
