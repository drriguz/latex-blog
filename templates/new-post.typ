#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "__TITLE__",
  date: "__DATE__",
  tags: ("__TAGS__",),
  lang: "en",
  summary: "A brief summary of the post.",
  author: "Riguz",
)

= Introduction

Write your introduction here.

= Main Content

Your main content goes here. You can use:

== Math

Inline math: $E = m c^2$.

Display math:
$ integral_{-infinity}^{infinity} e^{-x^2} dif x = sqrt(pi) $

== Code

```python
def hello():
    print("Hello, World!")
```

== Tables

#table(
  columns: 3,
  stroke: none,
  align: center,
  table.header(
    [*Name*], [*Value*], [*Unit*],
  ),
  table.hline(stroke: 0.5pt),
  [Speed of light], [$3 times 10^8$], [m/s],
  [Planck constant], [$6.626 times 10^(-34)$], [J·s],
  table.hline(stroke: 0.5pt),
)

= Conclusion

Write your conclusion here.