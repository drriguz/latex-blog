#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "IEEE 754浮点数转换",
  date: "2019-06-27",
  tags: ("刨根问底", "协议"),
  lang: "zh",
)

一个小数的二进制是怎么样的呢？我们先看看一个二进制的小数怎么转换成十进制：
$ 11101.01011_10 & = 1 times 2^4 + 1 times 2^3 + 1 times 2^2 + 0 times 2^1 + 1 times 2^0 + 0 times 2^(- 1) + 1 times 2^(- 2) + 1 times 2^(- 3) + 1 times 2^(- 4) + 1 times 2^(- 5)\
 & = 16 + 8 + 4 + 0 + 1 + 0 + 1 / 2 + 0 + 1 / 16 + 1 / 32\
 & = 29.34375 $

= IEEE 754
<ieee-754>
#link("https://en.wikipedia.org/wiki/IEEE_754")[IEEE 754]
标准中规定了浮点数在计算机中的表示方法，主要就是单精度(float)和双精度(double):

```
              S Exp      Fraction
Single(32bit) ▯▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯
Double(64bit) ▯▮▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯
```

其计算公式为：
$ x =(- 1)^times(1 + F r a c t i o n)times 2^((E x p o n e n t - B i a s)) $
其中，Bias为#link("https://zh.wikipedia.org/wiki/IEEE_754#%E6%8C%87%E6%95%B8%E5%81%8F%E7%A7%BB%E5%80%BC")[指数偏移值]，是一个固定值，即$B i a s = 2^(e - 1) - 1$
其中e为指数部分的比特长度。

- 单精度$B i a s = 2^7 - 1 = 127$
- 双精度$B i a s = 2^10 - 1 = 1023$

举个例子，刚才我们算出来的小数可以这样表示：

$ 29.34375 & = 11101.01011 = 11101.01011_2 times 2^0\
 & = 1.110101011_2 times 2^4\
 & =(- 1)^0times(1 + 0.110101011_2)times 2^(131 - 127)\
 & =(- 1)^0times(1 + 0.110101011_2)times 2^(10000011_2 - 127)\
 & =(- 1)^0times(1 + 0.110101011_2)times 2^(1027 - 1023)\
 & =(- 1)^0times(1 + 0.110101011_2)times 2^(10000000011_2 - 127)\
 $

因此在计算机中，表示为：

```
Float:
▯▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯
010000011110101011..............

Double:
▯▮▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯
010000000011110101011...........................................
```

不足的部分补上0，即：$0100000111101010110000000000000_2 = 41 e a c 000 16$

除了正常的浮点数外，还有几个比较特殊的：

#figure(
  align(center)[#table(
    columns: 2,
    align: (left,left,),
    table.header([Description], [Float(32bit)],),
    table.hline(),
    [Zero], [0 00000000 00000000000000000000000],
    [Negative Zero], [1 00000000 00000000000000000000000],
    [Infinity], [0 11111111 00000000000000000000000],
    [Negative Infinity], [1 11111111 00000000000000000000000],
    [Not a Number (NaN)], [0 11111111 00001000000000100001000],
  )]
  , kind: table
  )

= 十进制与二进制转换
<十进制与二进制转换>
计算方式为，将小数的整数部分与2取余倒序排列；将小数部分与2取整正序排列。例如，将3.14转换为float:

- 首先将整数部分直接转换为二进制 $3_10 = 11_2$
  - \$3\\mod2 = \\fbox{1}\$
  - \$1\\mod2 = \\fbox{1}\$
- 小数部分为0.14，不断乘以2后取整数部分，然后用小数继续乘以2直到值为1
  - \$0.14 \\times 2 = \\fbox{0}.28\$
  - \$0.28 \\times 2 = \\fbox{0}.56\$
  - \$0.56 \\times 2 = \\fbox{1}.12\$
  - \$0.12 \\times 2 = \\fbox{0}.24\$
  - \$0.24 \\times 2 = \\fbox{0}.48\$
  - \$0.48 \\times 2 = \\fbox{0}.96\$
  - \$0.96 \\times 2 = \\fbox{1}.92\$
  - \$0.92 \\times 2 = \\fbox{1}.84\$
  - …..
  - 重复以上步骤，得到$0.14_10 = 0.001000111101011100001010001111010 . . ._2$

= 舍入操作
<舍入操作>
对于尾数多余精度的情况，需要舍去多余的部分，但不是按照四舍五入的方式，而是按照"向偶舍入"的方式，意思就是，如果多余的部分大于0.5($0.5_10 = 0.1_2)$则最低位进1；如果小于0.5则舍去；如果正好是等于0.5则根据最低位判断，如果最低位是1则进位，否则舍去。这样按照统计学来看，对于一个小数有相同的机会进位或者被舍去。

例如对于上例中的3.14，我们可以得到：

$ 3.14 & = 11.001000111101011100001010001111010 . . ._2\
 & = 1.1001000111101011100001010001111010 . . ._2 times 2^1\
 & =(- 1)^0+(1 + 0.1001000111101011100001010001111010 . . ._2)times 2^(128 - 127)\
 & =(- 1)^0+(1 + 0.10010001111010111000010 10001111010 . . ._2)times 2^(10000000_2 - 127)\
 & approx(- 1)^0+(1 + 0.1001000111101011100001 1_2)times 2^(10000000_2 - 127) $

因此3.14的float表示为：

```
▯▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯
01000000010010001111010111000011
```

= 还原
<还原>
那么，对于一个存储在磁盘上的浮点数，我们怎么将它加载到内存中来？对于C来说，实际也是采用的IEEE754标准(float,
double)，所以实际上浮点数在内存中的表示是一致的，直接转换即可：

```cpp
struct ConstantFloat {
        mutable u4 bytes;
        float &getValue() const {
            return *reinterpret_cast<float *>(&bytes);
        }
    };
```

参考：

- #link("http://sandbox.mc.edu/~bennet/cs110/flt/dtof.html")[Decimal to Floating-Point Conversions]
- #link("http://cs.boisestate.edu/~alark/cs354/lectures/ieee754.pdf")[IEEE 754 FLOATING POINT REPRESENTATION]
- #link("https://www.h-schmidt.net/FloatConverter/IEEE754.html")[IEEE-754 Floating Point Converter]
- #link("https://www.rapidtables.com/convert/number/binary-to-decimal.html")[Binary to Decimal converter]
- #link("https://www.jianshu.com/p/e5d72d764f2f")[IEEE754表示浮点数]
- #link("http://www.binaryconvert.com/result_double.html?decimal=050057046051052051055053")[Online Binary-Decimal Converter]
