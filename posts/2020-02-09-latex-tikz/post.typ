#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "LaTeX(3)：使用TikZ绘制图形",
  date: "2020-02-09",
  tags: ("TikZ", "其他", "TeX", "~LaTeX入门", "LaTeX"),
  lang: "zh",
)

#link("https://www.ctan.org/pkg/pgf")[PGF]是一个用来进行图形绘制的（底层）包，TikZ是利用这个包实现的用户友好的接口。所以通常在LaTeX中会用TikZ来进行矢量图形的绘制。

= 基本概念
<基本概念>
== 基本语法
<基本语法>
要使用tikz进行图形绘制只需要简单引入tikz宏包，并将绘制代码包含在一个上下文中就可以了:

```latex
\usepackage{tikz}

\begin{tikzpicture}
% ...
\end{tikzpicture}
```

同样如果希望把图片作为一个figure，那么再套一层:

```latex
\usepackage{graphicx}
\usepackage{tikz}

\begin{document}
    \begin{figure}[h]
    \begin{tikzpicture}
        \draw (0, 0) -- (1, 1);
    \end{tikzpicture}
    \caption{这是一条直线}
    \end{figure}
\end{document}
```

== 坐标系和缩放
<坐标系和缩放>
默认情况下TikZ使用的是笛卡尔坐标系，即是这样：

另外，TikZ提供了一个缩放的选项，可以用来缩放图形，所以不必要担心绝对坐标的问题：

```latex
\begin{tikzpicture}[scale=0.5]
```

甚至还可以针对x轴和y轴分别设置缩放：

```latex
\begin{tikzpicture}[xscale=0.5, yscale=0.3]
```

在TikZ中，默认的单位是厘米(cm)。如果希望改变这个值，可以这样设置：

```latex
\begin{tikzpicture}[x=2cm,y=1.5cm]

% 或者
\begin{tikzpicture}[x={(2cm,0cm)},y={(0cm,1.5cm)}]
```

= 图形绘制
<图形绘制>
== 直线
<直线>
绘制直线：

```latex
\draw (0, 0) -- (1, 1);
```

绘制折线：

```latex
\draw (0, 0) -- (1, 1) -- (2, 2) -- (1, 0) -- (0, 3);
```

绘制背景网格:

```latex
\draw[help lines] (0,0) grid (3,3);
```

=== 箭头
<箭头>
如果希望绘制箭头也十分方便：

```latex
\draw [->] (0,0) -- (2,0);        %→
\draw [<-] (0, -0.5) -- (2,-0.5); %←
\draw [|->] (0,-1) -- (2,-1);     %带尾巴的箭头
\draw [<->] (0, 0) -- (1, 1);     %双向箭头
```

=== 线的粗细
<线的粗细>
线的粗细可以用如下来表示：

```latex
\draw [ultra thin] (0, 1) -- (2, 1)
```

总共可用的粗细如下：

或者直接指定线的粗细，默认的单位是点:

```latex
\draw [line width=12] (0,0) -- (2,0);
\draw [line width=0.2cm] (4,.75) -- (5,.25);
```

除此之外另一个选项是`[help lines]`，用来绘制灰色的参考线。

```latex
\draw [help lines] (0, 5) -- (0, 0) -- (5, 0);
\draw [line width=2pt] (0, 0) -- (5, 5);
\draw [very thin] (0, 3) -- (4, 0);
\draw [thin] (0, 2) -- (5, 2);
```

=== 样式及颜色
<样式及颜色>
样式可以分为：

- 虚线 `\draw [dashed]`
- 实线 `\draw [dotted]`

颜色有很多直接可以用的颜色表示，类似css一样：

#quote(block: true)[
red, green, blue, cyan, magenta, yellow, black, gray, darkgray,
lightgray,brown, lime, olive, orange, pink, purple, teal, violetand
white
]

一个较为完整的例子:

```latex
\begin{tikzpicture}
    \draw [help lines] (0, 5) -- (0, 0) -- (5, 0) node [right=3]{Nice sample!};
    \draw [dashed, red, line width=2pt] (0, 0) -- (5, 5);
    \draw [blue, very thin] (0, 3) -- (4, 0);
    \draw [dotted, thin] (0, 2) -- (5, 2);
\end{tikzpicture}
```

== 几何图形
<几何图形>
=== 矩形
<矩形>
```latex
\draw [blue] (0,0) rectangle (1.5, 1);
```

=== 网格
<网格>
```latex
\draw [blue] (0,0) grid (1.5, 1);
```

=== 圆
<圆>
```latex
\draw [red, ultra thick] (3, 0.5) circle [radius=0.5];
```

=== 弧线
<弧线>
```latex
\draw [gray, ultra thick] (6,0) arc [radius=1, start angle=45, end angle= 120];
```

这个弧线的表示方法比较有意思，代表从(6,
0)出发，半径为1，初始角度为45°，当变成120°的时候停止。另一种方法：

```latex
\draw[very thick] (0,0) to [out=90,in=195] (2,1.5);
```

表示从(0,0)开始， 到(2, 1.5)这个点，起始角度为90°，到达的角度为195°。

感觉很难控制这个….

=== 圆角折线
<圆角折线>
加多一个`rounded corners`就可以把折线变成圆角的了：

```latex
\draw [<->, rounded corners, thick, purple] (0,2) -- (0,0) -- (3,0);
```

- #link("https://www.latex-tutorial.com/tutorials/tikz/")[Draw pictures in LaTeX - With tikz/pgf]
- #link("http://cremeronline.com/LaTeX/minimaltikz.pdf")[A very minimal introduction to TikZ∗]
