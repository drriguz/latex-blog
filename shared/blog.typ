// Blog post template for Typst PDF rendering
// Replaces shared/latexblog.sty (XeLaTeX)

#let sidenote(body) = {
  place(top + right, scope: "parent", float: true, dx: 2em)[
    #text(size: 0.8em, fill: rgb("#666666"))[#body]
  ]
}

#let theorem(body, name: none) = {
  context {
    let num = counter("theorem").get().first() + 1
    counter("theorem").update(n => n + 1)
    let label = if name != none { [ (#name)] } else { [] }
    v(0.5em)
    block(inset: 12pt, stroke: 0.5pt + rgb("#4a90d9"), radius: 4pt, width: 100%)[
      #strong[Theorem #num#label.] #body
    ]
    v(0.5em)
  }
}

#let definition(body, name: none) = {
  context {
    let num = counter("definition").get().first() + 1
    counter("definition").update(n => n + 1)
    let label = if name != none { [ (#name)] } else { [] }
    v(0.5em)
    block(inset: 12pt, stroke: 0.5pt + rgb("#5b9a5b"), radius: 4pt, width: 100%)[
      #strong[Definition #num#label.] #body
    ]
    v(0.5em)
  }
}

#let lemma(body, name: none) = {
  context {
    let num = counter("lemma").get().first() + 1
    counter("lemma").update(n => n + 1)
    let label = if name != none { [ (#name)] } else { [] }
    v(0.5em)
    block(inset: 12pt, stroke: 0.5pt + rgb("#d4a017"), radius: 4pt, width: 100%)[
      #strong[Lemma #num#label.] #body
    ]
    v(0.5em)
  }
}

#let corollary(body, name: none) = {
  context {
    let num = counter("corollary").get().first() + 1
    counter("corollary").update(n => n + 1)
    let label = if name != none { [ (#name)] } else { [] }
    v(0.5em)
    block(inset: 12pt, stroke: 0.5pt + rgb("#9b59b6"), radius: 4pt, width: 100%)[
      #strong[Corollary #num#label.] #body
    ]
    v(0.5em)
  }
}

#let blog-post(
  title: "Untitled",
  date: "",
  tags: (),
  lang: "en",
  summary: "",
  author: "Riguz",
  body,
) = {
  set page(
    paper: "a4",
    margin: 2.5cm,
    header: context text(size: 0.8em, style: "italic")[#title #h(1fr) #author],
    footer: context {
      text(size: 0.8em)[#h(1fr) #counter(page).display() / #counter(page).final()]
      h(1fr)
      text(size: 0.6em)[© #datetime.today().year() #author. All rights reserved.]
    },
  )

  set text(font: ("New Computer Modern", "PingFang SC", "Noto Sans CJK SC"), size: 12pt, lang: lang)
  set heading(numbering: "1.1")
  show link: set text(fill: blue.darken(40%))

  align(center)[
    #text(size: 1.8em, weight: "bold")[#title]
    #v(0.5em)
    #text(size: 1.1em)[#date #h(1em) | #h(1em) #author]
    #if tags.len() > 0 {
      v(0.3em)
      text(size: 0.9em, style: "italic")[Tags: #tags.join(", ")]
    }
  ]
  v(1em)

  body
}