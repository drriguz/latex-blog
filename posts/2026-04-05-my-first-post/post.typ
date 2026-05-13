#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "My First Post",
  date: "2026-04-05",
  tags: ("rust", "latex"),
  lang: "en",
  summary: "A brief summary of the post.",
)

= Introduction
<introduction>
Write your introduction here.

= Main Content
<main-content>
Your main content goes here. You can use:

== Math
<math>
Inline math: $E = m c^2$.

Display math: $ integral_(- oo)^oo e^(- x^2) d x = sqrt(pi) $

== Code
<code>
```python
def hello():
    print("Hello, World!")
```

== Tables
<tables>
#figure(
  align(center)[#table(
    columns: 3,
    align: (left,center,center,),
    table.header([#strong[Name]], [#strong[Value]], [#strong[Unit]],),
    table.hline(),
    [Speed of light], [$3 times 10^8$], [m/s],
    [Planck constant], [$6.626 times 10^(- 34)$], [J·s],
  )]
  , caption: [Example table]
  , kind: table
  )

== Figures
<figures>
= Conclusion
<conclusion>
Write your conclusion here.
