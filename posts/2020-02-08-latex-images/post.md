在LaTeX中插入图片有些类似于Markdown中的方式。


# Figure和图片
可以使用Figure的方式插入图片：

```latex
\usepackage{graphicx} % 需要导入graphicx包

\begin{figure}[h!]
	\includegraphics[width=\linewidth]{src/1.jpg}
	\caption{冠状病毒的示意图}
	\label{fig:virus}
\end{figure}

```
这样生成的效果如图所示：
<img src="/images/Latex-image-figure.png" style="width:400px">

值得注意的是，在LaTeX中，图片和表格等是浮动元素，Tex会自动帮你找个地方放着。据说这样做的原因是因为它希望你专注在写作内容上面，等你完成了内容再回头来调整格式。因为没有这种经验，所以不确定这样是否是最好的方式，不过我们可能更习惯直接放在我们想放的位置上，所以这里是必须的：

```latex
begin{figure}[h]
```

这里后面有一个`h!`，有这样一些可用的参数：

* $h$ere: 就放在这里
* $t$op： 放在页面顶部
* $b$ottom: 页面底部
* $p$age: 放在单独的页面
* $!$(Override)：强制放在指定的位置

虽然我们已经用了`h!`来强制将图片放在页面的位置，但是很有可能页面余下的空间并不足以放入这张图片，这个时候，这个选项会失效。如果依然确定要将图片放入到下面，可以引入`float`包，使用`H`选项：

```latex
\usepackage{float}

\begin{figure}[H]
```

就像下面这样：

<img src="/images/Latex-image-float-H.png" style="width:400px">

# 多张图片排版
如果要将多张图片排版到一起，可以有多种方法。

## 使用`subfig`包

[subfig](https://ctan.org/pkg/subfig)是一个可以支持嵌套Figure或者表格的包，这个包是`subfigure`包的替代品，后者已经被弃用了。

```latex
\usepackage{subfig}

\begin{figure}
	\centering
	\subfloat[信息锅]{
		\includegraphics[width=0.4\linewidth, height=80pt]{src/3.jpg}
	}
	\subfloat[硬气功]{
		\includegraphics[width=0.4\linewidth, height=80pt]{src/4.jpg}
	}
	\caption{两种气功流派}
	\label{fig:qg}
\end{figure}
```

这样排版出来的效果如下：

<img src="/images/Latex-subfig.png" style="width:400px">

## 使用`subfloat`包

[subfloat](www.ctan.org/pkg/subfloat)是另一个包，用法如下：

```latex
\begin{subfigures}
\begin{figure}
	\centering
	\fbox{
		\includegraphics[width=0.4\linewidth, height=80pt]{src/3.jpg}
	}
	\caption{信息锅}
\end{figure}
\begin{figure}
	\centering
	\fbox{
		\includegraphics[width=0.4\linewidth, height=80pt]{src/4.jpg}
	}
	\caption{硬气功}
\end{figure}
\end{subfigures}
```
这样出来的效果是这样：
<img src="/images/Latex-subfloag.png" style="width:400px">

两张图片不在一行，没有找到怎么把他们放到一起的方法，也不知道是否支持。

## 使用`subcaption`包

另有使用[caption](http://www.ctan.org/pkg/caption)和[subcaption](http://www.ctan.org/pkg/subcaption)包结合的方式。`subcaption`包更加新一些，可能更适合选用。

```latex
\usepackage{caption}
\usepackage{subcaption} 

\begin{figure}
\centering
\subcaptionbox{信息锅}{
	\includegraphics[width=0.40\textwidth, height=80pt]{src/3.jpg}
}
\hfill
\subcaptionbox{硬气功}{
	\includegraphics[width=0.40\textwidth, height=80pt]{src/4.jpg}
}
\caption{两种气功流派}
\end{figure}
```
注意subcaption包貌似和前面两种方法中的某一种可能不兼容。效果如下：
<img src="/images/Latex-subcaption.png" style="width:400px">

如果去掉`\hfill`之后，效果基本上和第一种差不多了。

参考：

* [Image from \includegraphics showing up in wrong location?](https://tex.stackexchange.com/questions/16207/image-from-includegraphics-showing-up-in-wrong-location)
* [Figures: What is the difference between using subfig or subfigure](https://tex.stackexchange.com/questions/122314/figures-what-is-the-difference-between-using-subfig-or-subfigure)