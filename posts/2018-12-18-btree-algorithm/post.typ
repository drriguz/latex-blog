#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "B-Tree算法",
  date: "2018-12-18",
  tags: ("刨根问底", "算法"),
  lang: "zh",
)

B-Tree(区别于二叉树)是一种平衡多叉搜索树。

= B-Tree的定义
<b-tree的定义>
根据Knuth的定义，$m$阶的B-Tree有如下的特性：

+ 节点左边的元素都比它小，节点右边的元素都比它大
+ 每个节点最多有$m$个子节点
+ 除了根节点之外，非叶节点（没有孩子的节点）至少有$m\/2$个子节点
+ 如果根节点不是叶子节点则其至少有两个子节点
+ 包含$k$个子节点的节点共有$k - 1$个键
+ 所有的叶子节点的高度相同

一般表示B-Tree有两种表示方法：

- B-Tree of order $d$ or $M$
- B-Tree of degree or $t$

== Kuath: B-Tree of Order $d$
<kuath-b-tree-of-order-displaystyle-d>
其中$M = 5$ 表示每一个节点中#emph[至多有5个子节点]；则有如下的特性：
$  & M a x(c h i l d r e n)= 5\
 & M i n(c h i l d r e n)= c e i l(M\/2)= 3\
 & M a x(k e y s)= M a x(c h i l d r e n)- 1 = 4\
 & M i n(k e y s)= M i n(c h i l d r e n)- 1 = 2 $

== CLRS: B-Tree of min degree $t$
<clrs-b-tree-of-min-degree-displaystyle-t>
而$t = 5$ 则定义了一个节点中#emph[至少有5个子节点]
$  & M a x(c h i l d r e n)= 2 t = 10\
 & M i n(c h i l d r e n)= t = 5\
 & M a x(k e y s)= 2 t - 1 = 9\
 & M i n(k e y s)= t - 1 = 4 $

这里degree指的是一个节点中子节点的数目。CLRS中用的最小度，即节点中最少有多少个子节点。例如t=2即表示的是2-3-4
tree，每个子节点中可以有2、3或者4个children。

== CS673: B-tree of maximum degree k
<cs673-b-tree-of-maximum-degree-k>
而也有使用Max
degree的，例如#link("https://www.cs.usfca.edu/~galles/visualization/BTree.html")[DB Virtualization]里面，使用的就是最大度（即最多有k个子节点），则：

- 所有的interior node最少有k/2个children，最多有k个
- 2-3树即对应到maximum degree of 3

== 对应关系
<对应关系>
这些表示方法的对应关系如下：

#figure(
  align(center)[#table(
    columns: 4,
    align: (left,left,auto,left,),
    table.header([Kunth Order, k], [CLRS min degree], [CS673 max
      defree], [(min, max) children],),
    table.hline(),
    [k=0], [-], [-], [-],
    [k=1], [-], [-], [-],
    [k=2], [-], [-], [-],
    [k=3], [-], [t=3], [(2, 3)],
    [k=4], [t=2], [t=4], [(2, 4)],
    [k=5], [-], [t=5], [(3, 5)],
    [k=6], [t=3], [t=6], [(3, 6)],
    [k=7], [-], [t=7], [(4, 7)],
    [k=8], [t=4], [t=8], [(4, 8)],
    [k=9], [-], [t=9], [(5, 9)],
    [k=10], [t=5], [t=10], [(5, 10)],
  )]
  , kind: table
  )

可见Order实际等价于max degree。

= 算法复杂度
<算法复杂度>
根据B-Tree的定义（Min Degree t)，如果Btree的高度为$h$,
考虑最少含有多少个key, 则当：

- Root节点包含1个key
- 其他所有节点有且仅有有$t - 1$ 个key

这种场景时，所包含的key最少：

#figure(image("images/btree_height_3.gif", alt: "Btree of height 3"),
  caption: [
    Btree of height 3
  ]
)

设$S_h$为Btree第h层的节点数，容易看出:

- 当$d e p t h = 0$ 时，$S_0 = 1$
- 当$d e p t h = 1$ 时，$S_1 = 2$
- 当$d e p t h = 2$ 时，$S_2 = 2 dot.op t$
- 当$d e p t h = h$ 时，$S_h = 2 dot.op t^(h - 1)$

从$h = 1$开始，每一层的key数目即$S(k e y)_h= S_h dot.op(t - 1)$，根据等比数列求和公式即可算出总的key数目为：

$ M i n(k e y s) & = 1 + sum_(i = 1)^h(t - 1)dot.op 2 t^(i - 1)\
 & = 1 +(t - 1)sum_(i = 1)^h 2 t^(i - 1)\
 & = 1 + 2(t - 1)sum_(i = 1)^h t^(i - 1)\
 & = 1 + 2(t - 1)#scale(x: 180%, y: 180%)[(] frac(1 - t^h, 1 - t) #scale(x: 180%, y: 180%)[)]\
 & = 2 t^h - 1 $

设$n$ 为B-Tree的所有key数，则有：

$ n & gt.eq M i n(k e y s)\
 & = 2 t^h - 1 $

可以得：

$ h lt.eq l o g_t frac(1 + n, 2) $

其算法时间和空间复杂度如下：

#figure(
  align(center)[#table(
    columns: 3,
    align: (auto,left,center,),
    table.header([], [平均], [最坏],),
    table.hline(),
    [空间复杂度], [$O(n)$], [$O(n)$],
    [查找], [$O(l o g quad n)$], [$O(l o g quad n)$],
    [插入], [$O(l o g quad n)$], [$O(l o g quad n)$],
    [删除], [$O(l o g quad n)$], [$O(l o g quad n)$],
  )]
  , kind: table
  )

= B-tree算法实现
<b-tree算法实现>
== search操作
<search操作>
根据B-tree的定义，左边的key都比其小，右边皆比其大，则不应该存在重复的key。查找算法类似于2叉树的查找，步骤如下：

- 从根节点开始，依次同节点中$k_i$进行比较，如果大于或者等于$k_i$则停止
- 如果找到相等的key，则停止搜索
- 如果没有找到，则到下一级节点中进行查找；如果已经是叶子节点，则查找结束

#figure(image("images/Btree-order-5-search.png", alt: "在Btree中查找”5”"),
  caption: [
    在Btree中查找"5"
  ]
)

通常当$M$较小时，我们在节点中查找的时候只需要进行顺序查找即可；如果较大的情况下，可以进行二分查找提高搜索的效率。

```ruby
B-TREE-SEARCH(x, k)
  i ← 1
  while i ≤ n[x] and k ≥ key[x, i]
    do i ← i + 1
  if i ≤ n[x] and k = key[x, i]
    then return (x, i)
  if leaf[x]
    then return NIL
    else c = DISK-READ(c[x, i])
      return B-TREE-SEARCH(c, k)
```

== insert操作
<insert操作>
=== 节点的分裂
<节点的分裂>
在进行insert之前，需要考虑的就是，btree规定了一个节点中最大的child的数目，当一个节点中子节点的数目超过允许的最大值的时候，需要将节点拆分为两个。例如上面的例子，如果再插入20的话，如果直接插入则子元素已经超出了最大允许的数目：

#figure(image("images/Btree-order-5-split.png", alt: "在Btree中插入”20”"),
  caption: [
    在Btree中插入"20"
  ]
)

在上面的例子中，拆分之后，两个子节点的元素个数正好是平均的，但是，如果order为偶数的情况下是不平均的：

#figure(image("images/Btree-order-4-split.png", alt: "在Btree中插入”6”"),
  caption: [
    在Btree中插入"6"
  ]
)

值得注意的是，因为每次分裂高度会增加，同时会增加父元素的key个数，那么也可能导致父节点满。所以如果上层节点也满了的话，也是需要递归的分裂的：

#figure(image("images/Btree-order-4-multi-split.png", alt: "在Btree中插入”10”"),
  caption: [
    在Btree中插入"10"
  ]
)

=== 节点插入过程
<节点插入过程>
当order为奇数时，插入A\~Q的过程如下：

#figure(image("images/btree_order_5_insert.png", alt: "btree of order 5"),
  caption: [
    btree of order 5
  ]
)

当order为偶数时，插入A-J的过程如下：

#figure(image("images/btree_order_4_insert.png", alt: "btree of order 4"),
  caption: [
    btree of order 4
  ]
)

在Insert的过程中，一般的做法是先将元素插入到叶节点，这时候如果发现叶节点满了，需要将其Split，并将其中一个key提升到父节点中。同时，需要看父节点是否满，如果满了也需要进行拆分，直到根节点。但是这种做法需要插入后再回溯，比较难以实现。#link("http://staff.ustc.edu.cn/~csli/graduate/algorithms/book6/chap19.htm")[另一种方式]则是在插入的过程中，一旦发现节点已经满了，无法再容纳元素，则先将其拆分，然后再继续朝下查找。这样只需要查找一次，再最后插入到叶子节点的时候，能够保证不会溢出。

=== 抢占式分裂（Preemtive Split）
<抢占式分裂preemtive-split>
如上所说，在insert操作的时候，是先插入元素，然后再进行拆分的，这样可能插入之后还需要一直递归到上层节点进行拆分。例如下面的一个场景：

#figure(image("images/btree_order_4_insert_normal.png", alt: "btree of order 4"),
  caption: [
    btree of order 4
  ]
)

而Preemtive
Split正是在insert之前即进行拆分，当发现一个节点快要满了的时候，就先split之后再插入，自顶向下，不需要再回溯到上一层的节点。

#figure(image("images/btree_order_4_insert_preemtive.png", alt: "btree of order 4"),
  caption: [
    btree of order 4
  ]
)

从上面的例子可以看到，两种方式构造出的Btree在插入I之后其实是不大一样的，而当J插入之后则变成一致了。

== 创建一个空的B-tree
<创建一个空的b-tree>
```ruby
B-TREE-CREATE(T)
  x ← ALLOCATE-NODE()
  leaf[x] ← TRUE
  n[n] ← 0
  DISK-WRITE(x)
  root[T] ← x
```

== 删除操作
<删除操作>
= B-Tree变种
<b-tree变种>
- 2-3-4树：Order为4的B-tree又被称之为2-3-4 tree
  (每个非叶子节点有2个、3个或者4个子节点)
- 2-3树：Order为3的B-tree又被称之为2-3 tree
  (每个非叶子节点有2个或者3个子节点)
- B+-tree：A B-tree in which keys are stored in the leaves.
- B\*-tree：A B-tree in which nodes are kept 2/3 full by redistributing
  keys to fill two child nodes, then splitting them into three nodes.

参考资料:

- #link("https://en.wikipedia.org/wiki/B-tree")[Wikipedia - B-tree]
- #link("https://www.cs.usfca.edu/~galles/cs673/lecture/lecture11.pdf")[Graduate Algorithms CS673-2016F-11 B-Trees]
- #link("https://xlinux.nist.gov/dads/HTML/btree.html")[NIST B-tree]
- #link("http://staff.ustc.edu.cn/~csli/graduate/algorithms/book6/chap19.htm")[CHAPTER 19: B-TREES]
- #link("https://stackoverflow.com/questions/28846377/what-is-the-difference-btw-order-and-degree-in-terms-of-tree-data-structure")[What is the difference btw "Order" and "Degree" in terms of Tree data structure]
