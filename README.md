# LaTeX Blog

A static blog generator powered by **XeLaTeX** and **Pandoc**. Write technical blog posts in LaTeX with full CJK support, and compile them into a static HTML site with KaTeX math rendering and downloadable PDFs.

## Features

- Write blog posts in XeLaTeX (`.tex` files)
- CJK support (Noto Sans CJK SC)
- Math equations rendered via KaTeX
- Syntax-highlighted code blocks
- Tables, figures, lists, theorems
- HTML + PDF dual output
- Minimal, academic-style design
- CLI for creating new posts, building, and previewing

## Prerequisites

- **Rust** (1.70+): <https://rustup.rs/>
- **Pandoc** (3.0+): <https://pandoc.org/installing.html>
- **TeX Live** with XeLaTeX: `brew install --cask mactex` (macOS) or `apt install texlive-xetex texlive-fonts-extra` (Ubuntu)
- **Noto Sans CJK SC** font: `brew install font-noto-sans-cjk-sc` or download from Google Fonts

## Quick Start

```bash
# Build the CLI
cargo build --release

# Create a new post
cargo run -- new "My First Post" --tags "rust, latex"

# Build the static site
cargo run -- build

# Preview locally
cargo run -- serve --port 8080
```

Or use the Makefile:

```bash
make build    # Build the static site
make serve    # Start the dev server
make clean    # Remove output directory
make new      # Interactive new post creation
```

## Project Structure

```
├── posts/                    # Blog posts (one directory per post)
│   └── YYYY-MM-DD-slug/
│       ├── post.tex          # LaTeX source
│       └── images/           # Post-local images
├── shared/
│   └── blog.sty              # Shared LaTeX style (metadata commands, packages)
├── templates/
│   ├── base.html             # HTML base template
│   ├── post.html             # Post page template
│   ├── index.html            # Index page template
│   └── new-post.tex          # Template for new posts
├── static/
│   └── css/style.css         # Site stylesheet
├── src/                      # Rust CLI source
├── output/                   # Generated static site (gitignored)
├── Cargo.toml
└── Makefile
```

## Writing a Post

Each post lives in `posts/YYYY-MM-DD-slug/post.tex`. Metadata is defined using custom LaTeX commands:

```latex
\blogtitle{My Post Title}
\blogdate{2025-12-01}
\blogtags{math, algorithms}
\bloglang{en}
\blogsummary{A brief description of the post.}
```

These commands are defined in `shared/blog.sty` and serve dual purpose:
1. Parsed by the CLI for HTML metadata (title, date, tags, summary)
2. Rendered by XeLaTeX for PDF title page

## Build Pipeline

1. Scan `posts/*/post.tex` and extract metadata
2. **HTML**: Pandoc converts LaTeX → HTML5 fragments; KaTeX renders math client-side
3. **PDF**: XeLaTeX compiles each post to PDF
4. Tera templates wrap HTML fragments into full pages
5. Static assets and PDFs copied to `output/`

## License

MIT
