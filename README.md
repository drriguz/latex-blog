# LaTeX Blog

A static blog generator powered by **Typst** and **Pandoc**. Write technical blog posts in Typst (or Markdown) with full CJK support, and compile them into a static HTML site with KaTeX math rendering and downloadable PDFs.

## Features

- Write blog posts in Typst (`.typ` files) or Markdown (`.md` files)
- CJK support (PingFang SC / Noto Sans CJK SC font fallback)
- Math equations rendered via KaTeX (HTML) and Typst (PDF)
- Syntax-highlighted code blocks
- Tables, figures, lists, theorems, sidenotes
- HTML + PDF dual output
- Minimal, academic-style design
- CLI for creating new posts, building, and previewing
- Legacy XeLaTeX support for older `.tex`-only posts

## Prerequisites

- **Rust** (1.70+): <https://rustup.rs/>
- **Typst** (0.14+): <https://github.com/typst/typst/releases> or `brew install typst`
- **Pandoc** (3.0+): <https://pandoc.org/installing.html>
- **PingFang SC** font (macOS built-in) or **Noto Sans CJK SC** (`brew install font-noto-sans-cjk-sc`)
- XeLaTeX (optional, for legacy `.tex`-only posts)

## Quick Start

```bash
# Build the CLI
cargo build --release

# Create a new post
cargo run -- new "My First Post" --tags "rust, typst"

# Build the static site
cargo run -- build

# Preview locally
cargo run -- serve --port 9527
```

Or use the Makefile:

```bash
make build    # Build the static site
make serve    # Start the dev server (port 9527)
make clean    # Remove output directory
make new      # Interactive new post creation
make dev      # Build then serve
```

## Project Structure

```
├── posts/                    # Blog posts (one directory per post)
│   └── YYYY-MM-DD-slug/
│       ├── post.typ          # Typst source (preferred)
│       ├── post.md           # Markdown source (for HTML output)
│       └── images/           # Post-local images
├── shared/
│   ├── blog.typ              # Typst document template
│   ├── latexblog.sty         # Legacy LaTeX package (for .tex-only posts)
│   ├── references.bib        # BibTeX references
│   └── *.lua                 # Pandoc Lua filters
├── templates/
│   ├── base.html             # HTML base template
│   ├── post.html             # Post page template
│   ├── index.html            # Index page template
│   └── new-post.typ          # Template for new posts
├── static/
│   └── css/style.css         # Site stylesheet
├── src/                      # Rust CLI source
├── output/                   # Generated static site (gitignored)
├── Cargo.toml
└── Makefile
```

## Writing a Post

Each post lives in `posts/YYYY-MM-DD-slug/`. Create one with `cargo run -- new "Title"`:

```typst
#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition
#show: blog-post.with(
  title: "My Post Title",
  date: "2025-12-01",
  tags: ("math", "algorithms"),
  lang: "en",
  summary: "A brief description of the post.",
)

= Introduction

Write your content here using Typst syntax.
```

For HTML output, also create a `post.md` file in the same directory — Pandoc converts Markdown to HTML with better code highlighting than Typst-to-HTML.

## Build Pipeline

1. Scan `posts/*/post.typ` (preferred) or `posts/*/post.tex` for metadata
2. **HTML**: if `post.md` exists, Pandoc converts Markdown → HTML5; otherwise Pandoc converts `post.tex` → HTML5
3. **PDF**: Typst compiles `post.typ` → PDF; falls back to XeLaTeX for legacy `.tex`-only posts
4. Tera templates wrap HTML fragments into full pages
5. Index and tag pages generated from collected metadata
6. Output written to `output/`

## License

MIT