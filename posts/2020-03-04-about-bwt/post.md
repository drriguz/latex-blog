最近听一个医学专业的同学提到了在进行基因分析中用到BWT算法，觉得挺有意思的，正巧赶上这次疫情在家，于是想研究一下这个算法。这个算法的核心思想在于，调整原来的字符串中字符的顺序（而不改变其长度及内容）从而更多的将重复的字符排列到一起，这样有助于其他的压缩算法获得更高的压缩比。这个算法在基因分析中大有用处也就顺理成章了，想想DNA的双链表示大概都是G-T-A-C会有很多这样的字符，那么运用BWT应该可以有比较好的效果。


# 算法实现
考虑一个字符串，要想将相同的字符排列到一起，那么最简单的办法就是，将字符串中的字符进行排序。可是单纯的排序之后，虽然还是那么多字符，但是丢失了一个重要的信息就是字符原来的顺序，而BWT的核心思想就是在于排序并想办法保存字符的顺序信息。

## 编码
编码方式如下：

* 将 ${\displaystyle \$}$ 作为字符串结尾标记加入到原字符串（记为 ${\displaystyle S}$ )末尾
* 将字符串从左到右进行轮换，对于一个长度为 ${\displaystyle N}$ 的字符串，产生 ${\displaystyle N}$ 个新的字符串，记为 ${\displaystyle S_{n}}$ 
* 将 ${\displaystyle S, S_{1}...S_{n}}$ 进行字典序排序， ${\displaystyle \$}$ 权值最小放在最前面，也即 ${\displaystyle S_{n}}$ 在第一个
* 取排序后的所有字符串的最后一个字符，生成一个新的字符串（记为${\displaystyle S^{"}}$ )，即编码完成

以字符串`banana`举例来说：

$$
S = banana, N = 6\\
\begin{cases}
S_{0} = banana\color{blue}{$}\\
S_{1} = anana\color{blue}{$}b\\
S_{2} = nana\color{blue}{$}ba\\
S_{3} = ana\color{blue}{$}ban\\
S_{4} = na\color{blue}{$}bana\\
S_{5} = a\color{blue}{$}banan\\
S_{6} = \color{blue}{$}banana
\end{cases}
\xrightarrow[\text{字典序排序}]{}
\begin{cases}
S_{6} = \color{blue}{$}banana\\
S_{5} = a\color{blue}{$}banan\\
S_{3} = ana\color{blue}{$}ban\\
S_{1} = anana\color{blue}{$}b\\
S_{0} = banana\color{blue}{$}\\
S_{4} = na\color{blue}{$}bana\\
S_{2} = nana\color{blue}{$}ba
\end{cases}
\xrightarrow[\text{获取最后一个字符}]{}
\begin{cases}
S_{6} = $banan\color{red}{a}\\
S_{5} = a$bana\color{red}{n}\\
S_{3} = ana$ba\color{red}{n}\\
S_{1} = anana$\color{red}{b}\\
S_{0} = banana\color{red}{$}\\
S_{4} = na$ban\color{red}{a}\\
S_{2} = nana$b\color{red}{a}
\end{cases}\\
S^{"} = BWT(banana) = annb$aa
$$

可以看出，转换后的字符串`annb$aa`比原来的字符串重复相连的字符的确更多了。实际上[bzip](http://www.bzip.org/)就是应用了BWT结合进行压缩的：

> bzip2 compression program is based on Burrows–Wheeler algorithm.

BWT转换后的重复相连字符更多并不绝对，有时候可能转换后的情况反而更糟，比如这个例子：

$$
BWT(appellee) = e$elplepa
$$

反而不如原始字符串了。

## 解码
### 利用还原矩阵法
解码的过程分为以下几步：

* 根据编码后的字符串 ${\displaystyle S^{"}}$ ，得到还原矩阵
* 根据还原矩阵，逐个还原出原来的顺序

根据编码的过程我们知道，实际上是这样的对应：
$$
\begin{cases}
S_{6} = \color{green}{$}banan\color{red}{a}\\
S_{5} = \color{green}{a}$bana\color{red}{n}\\
S_{3} = \color{green}{a}na$ba\color{red}{n}\\
S_{1} = \color{green}{a}nana$\color{red}{b}\\
S_{0} = \color{green}{b}anana\color{red}{$}\\
S_{4} = \color{green}{n}a$ban\color{red}{a}\\
S_{2} = \color{green}{n}ana$b\color{red}{a}
\end{cases}
\xrightarrow[\text{还原矩阵}]{}
\begin{pmatrix}
$ & a\\
a & n\\
a & n\\
a & b\\
b & $\\
n & a\\
n & a
\end{pmatrix}
$$

得到这个矩阵非常简单，直接将字符串 ${\displaystyle S^{"}}$ 排个序就可以得到：

$$
\begin{cases}
------a\\
------n\\
------n\\
------b\\
------$\\
------a\\
------a
\end{cases}
\xrightarrow[\text{排序}]{}
\begin{cases}
------$\\
------a\\
------a\\
------a\\
------b\\
------n\\
------n
\end{cases}
\xrightarrow[\text{还原矩阵}]{}
\begin{pmatrix}
$ & a\\
a & n\\
a & n\\
a & b\\
b & $\\
n & a\\
n & a
\end{pmatrix}
$$

在这样的一个还原矩阵中，每一个字符对应的就是它最末尾的字符。解码的过程如下：

* 从左边列的 ${\displaystyle S}$ 开始，找到对应的字符作为下一个字符 ${\displaystyle C_{n}}$
* 根据 ${\displaystyle C_{n}}$ 这个字符，在左边列找到对应的字符，其对应的字符即 ${\displaystyle C_{n-1}}$
* 以此类推，直到结尾
* 如果出现了多个相同的字符，那么就从上到下按顺序找就可以了

$$
\begin{pmatrix}
\color{red}{$} & \color{red}{a}\\
a & n\\
a & n\\
a & b\\
b & $\\
n & a\\
n & a
\end{pmatrix}
\xrightarrow[\text{\$a}]{}
\begin{pmatrix}
\color{gray}{$} & \color{gray}{a}\\
\color{red}{a} & \color{red}{n}\\
a & n\\
a & b\\
b & $\\
n & a\\
n & a
\end{pmatrix}
\xrightarrow[\text{\$an}]{}
\begin{pmatrix}
\color{gray}{$} & \color{gray}{a}\\
\color{gray}{a} & \color{gray}{n}\\
a & n\\
a & b\\
b & $\\
\color{red}{n} & \color{red}{a}\\
n & a
\end{pmatrix}
\xrightarrow[\text{\$ana}]{}
\begin{pmatrix}
\color{gray}{$} & \color{gray}{a}\\
\color{gray}{a} & \color{gray}{n}\\
\color{red}{a} & \color{red}{n}\\
a & b\\
b & $\\
\color{gray}{n} & \color{gray}{a}\\
n & a
\end{pmatrix}
\xrightarrow[\text{\$anan}]{}
\begin{pmatrix}
\color{gray}{$} & \color{gray}{a}\\
\color{gray}{a} & \color{gray}{n}\\
\color{gray}{a} & \color{gray}{n}\\
a & b\\
b & $\\
\color{gray}{n} & \color{gray}{a}\\
\color{red}{n} & \color{red}{a}\\
\end{pmatrix}
\xrightarrow[\text{\$anana}]{}
\begin{pmatrix}
\color{gray}{$} & \color{gray}{a}\\
\color{gray}{a} & \color{gray}{n}\\
\color{gray}{a} & \color{gray}{n}\\
\color{red}{a} & \color{red}{b}\\
b & $\\
\color{gray}{n} & \color{gray}{a}\\
\color{gray}{n} & \color{gray}{a}\\
\end{pmatrix}
\xrightarrow[\text{\$ananab}]{}
\begin{pmatrix}
\color{gray}{$} & \color{gray}{a}\\
\color{gray}{a} & \color{gray}{n}\\
\color{gray}{a} & \color{gray}{n}\\
\color{gray}{a} & \color{gray}{b}\\
\color{red}{b} & \color{red}{$}\\
\color{gray}{n} & \color{gray}{a}\\
\color{gray}{n} & \color{gray}{a}\\
\end{pmatrix}\\
S^{'} = \$ananab\\
S = reverse(S^{'}) \\= banana\$
$$

### 变种
另一种方式可能更清晰，但实质上是一回事，只是做法看着不一样。在上述构建还原矩阵的过程中，我们实际已知的是最后一列的数据，那么，如果我们想办法把其他的列都构建出来，就可以得到原来的字符串了。

$$
\begin{cases}
------a\\
------n\\
------n\\
------b\\
------$\\
------a\\
------a
\end{cases}
\xrightarrow[\text{想办法变成这样}]{}
\begin{cases}
S_{6} = \color{green}{$}banan\color{red}{a}\\
S_{5} = \color{green}{a}$bana\color{red}{n}\\
S_{3} = \color{green}{a}na$ba\color{red}{n}\\
S_{1} = \color{green}{a}nana$\color{red}{b}\\
S_{0} = \color{green}{b}anana\color{red}{$}\\
S_{4} = \color{green}{n}a$ban\color{red}{a}\\
S_{2} = \color{green}{n}ana$b\color{red}{a}
\end{cases}
\xrightarrow[\text{然后拿到S6就可以了}]{}
S_{6} = \color{green}{$}banan\color{red}{a}
$$

过程是这样的：
$$
\begin{cases}
------a\\
------n\\
------n\\
------b\\
------$\\
------a\\
------a
\end{cases}
\xrightarrow[\text{将最后一列排序，作为第一列}]{}
\begin{cases}
$-----a\\
a-----n\\
a-----n\\
a-----b\\
b-----$\\
n-----a\\
n-----a
\end{cases}
$$

得到这个之后，从又到左得到`a$,na,na,ba,$b, an, an`，再将其排序作为第二列, 以此类推：

$$
\begin{cases}
------a\\
------n\\
------n\\
------b\\
------$\\
------a\\
------a
\end{cases}
\rightarrow
\begin{cases}
$-----a\\
a-----n\\
a-----n\\
a-----b\\
b-----$\\
n-----a\\
n-----a
\end{cases}
\rightarrow
\begin{cases}
a$\\
na\\
na\\
ba\\
$b\\
an\\
an
\end{cases}
\xrightarrow[\text{排序}]{}
\begin{cases}
$\color{green}{b}\\
a\color{green}{$}\\
a\color{green}{n}\\
a\color{green}{n}\\
n\color{green}{a}\\
n\color{green}{a}\\
b\color{green}{a}
\end{cases}
\xrightarrow[\text{得到第三列}]{}
\begin{cases}
$b----a\\
a$----n\\
an----n\\
an----b\\
ba----$\\
na----a\\
na----a
\end{cases}\\
\rightarrow
\begin{cases}
a$b\\
na$\\
nan\\
ban\\
$ba\\
ana\\
ana
\end{cases}
\rightarrow
\begin{cases}
$b\color{green}{a}\\
a$\color{green}{b}\\
an\color{green}{a}\\
an\color{green}{a}\\
ba\color{green}{n}\\
na\color{green}{$}\\
na\color{green}{n}
\end{cases}
\xrightarrow[\text{得到第三列}]{}
\begin{cases}
$ba---a\\
a$b---n\\
ana---n\\
ana---b\\
ban---$\\
na$---a\\
nan---a
\end{cases}
\xrightarrow[\text{如此反复，最终得到全部列}]{}
$$

# 代码实现
看似复杂的操作，没想到用python可以写的如此简单，不过不见得一看就懂...
```python
EOL = '$'

def encode(source):
    source = source + EOL
    table = [source[i:] + source[:i] for i in range(len(source))]
    table.sort()

    return ''.join([row[-1] for row in table])

def decode(encoded):
    length = len(encoded)
    table = [''] * length

    for i in range(length):
        table = sorted([encoded[m] + table[m] for m in range(length)])
        print(table)
    s = [row for row in table if row.endswith(EOL)][0]
    return s.rstrip(EOL)
```

解码的这个循环不大好理解，打出来一看就懂了：
```
['$', 'a', 'a', 'a', 'b', 'n', 'n']
['$b', 'a$', 'an', 'an', 'ba', 'na', 'na']
['$ba', 'a$b', 'ana', 'ana', 'ban', 'na$', 'nan']
['$ban', 'a$ba', 'ana$', 'anan', 'bana', 'na$b', 'nana']
['$bana', 'a$ban', 'ana$b', 'anana', 'banan', 'na$ba', 'nana$']
['$banan', 'a$bana', 'ana$ba', 'anana$', 'banana', 'na$ban', 'nana$b']
['$banana', 'a$banan', 'ana$ban', 'anana$b', 'banana$', 'na$bana', 'nana$ba']
```

* [维基百科-Burrows-Wheeler变换](https://zh.wikipedia.org/wiki/Burrows-Wheeler%E5%8F%98%E6%8D%A2)
* [BWT](https://www.cs.cmu.edu/~ckingsf/bioinfo-lectures/bwt.pdf)