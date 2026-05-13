#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "LaTeX(1)：章节和段落",
  date: "2020-02-07",
  tags: ("TeX", "~LaTeX入门", "LaTeX", "其他"),
  lang: "zh",
)

LaTeX适用于学术论文等的写作，在这类文章中一个很重要的部分就是段落和章节了。回想起当年使用Word写作的时候调整标题是何等的痛苦，那么在LaTeX中是怎样设置段落和章节的呢？

= 标题
<标题>
通过下面的命令可以生成一个默认的标题：

```latex
\title{一种新型冠状病毒的防治方法}
\author{Dr. Riguz}
\date{2020-02-07}

\maketitle % 生成标题页
\newpage   % 分页
```

这样效果如下：

= LaTeX段落层次
<latex段落层次>
LaTeX中可以分成如下的几个部分：

- section：一级标题
- subsection：二级标题
- subsubsection：三级标题
- paragraph：段落
- subpragraph：二级段落

下面是一个例子：

对应的代码如下，非常简洁：

```latex
\section{背景}
首先简要介绍一下这个项目的背景。
\subsection{冠状病毒简介}
冠状病毒是一个大型病毒家族，包括引起普通感冒的病毒以及严重急性呼吸综合征冠状病毒和中东呼吸综合征冠状病毒。这一新病毒暂时命名为2019新型冠状病毒（2019-nCoV）。
\subsection{现有的防治方法}
\subsubsection{居家隔离法}
待在家里不出门。
\subsubsection{自我安慰法}
反正也死不了。
\section{新的防治方法}
实在编不下去了：
\paragraph{气功}
是一种中华民族祖传的神功。气功又可以分为两种：
\subparagraph{硬气功}
可以开山断石，金钟罩铁布衫。
\subparagraph{内功}
可以运行体内的真气激发一种神奇的力量运行于经络之上。
```

= 生成目录
<生成目录>
== 目录
<目录>
想要生成目录页特别简单，一个命令就可以搞定：

```latex
\tableofcontents
\newpage
```

== 自定义级别
<自定义级别>
如果在生成目录的时候，只希望生成到特定的级别，可以这样设置：

```latex
\setcounter{tocdepth}{2}
\tableofcontents
```

这样生成的目录就只会到`subsection`级别。当然这样设置的话会对所有的内容生效，如果只是希望对某个章节生效怎么办呢？

```latex
\addtocontents{toc}{\setcounter{tocdepth}{1}}
\section{背景}

% ...
\addtocontents{toc}{\setcounter{tocdepth}{3}}
\section{新的防治方法}
```

可以像上面这样，在需要设置的章节之前设置，然后再其他地方恢复默认级别。

== 行距
<行距>
如果希望调整行距，可以使用

```latex
\doublespacing
\tableofcontents
\newpage
\singlespacing
```

单倍行距：

双倍行距：

== 图表目录
<图表目录>
另外，如果想对图表生成目录，可以采用：

```latex
\begin{appendix}
    \listoffigures
    \listoftables
\end{appendix}  
```

参考：

- #link("https://www.latex-tutorial.com/tutorials/sections/")[Using LaTeX paragraphs and sections]
- #link("http://yakeworld.myesci.com/node/1397")[xelatex中文换行]
- #link("https://www.ntg.nl/doc/biemesderfer/ltxcrib.pdf")[LATEX Command Summary]
