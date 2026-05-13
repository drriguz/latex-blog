# AGENTS.md

## Project

Static blog generator: Rust CLI compiles Markdown/Typst posts into HTML (via Pandoc) and PDF (via Typst), wraps them with Tera templates. Legacy XeLaTeX support retained for `.tex`-only posts.

## Commands

```bash
make build          # Build the entire site (cargo run -- build)
make serve          # Dev server on port 9527 (cargo run -- serve --port 9527)
make clean          # Remove output/
make new            # Interactive post creation (or: cargo run -- new "Title" --tags "tag1,tag2")
make dev            # Build then serve
```

No test framework is configured. Inline unit tests exist in `src/metadata.rs` — run with `cargo test`.

## Build Pipeline

1. Scan `posts/*/post.typ` (preferred) or `posts/*/post.tex` for metadata
2. Per post: if `post.md` exists, Pandoc converts markdown → HTML; otherwise Pandoc converts `post.tex` → HTML
3. Typst compiles `post.typ` → PDF; falls back to XeLaTeX for legacy `.tex`-only posts; PDF failure is non-fatal
4. Tera templates (`templates/*.html`) wrap HTML fragments into pages
5. Index and tag pages generated from collected metadata
6. Output written to `output/` (wiped and rebuilt each build)

## External Dependencies

- **Typst 0.14+** — must be on PATH (PDF generation)
- **Pandoc 3.0+** — must be on PATH (HTML generation)
- **XeLaTeX** (optional, for legacy `.tex`-only posts)
- **PingFang SC** font — in `shared/blog.typ` font fallback list for CJK
- Pandoc Lua filters: `shared/sidenote.lua`, `shared/codeblock.lua`
- BibTeX: `shared/references.bib` + `shared/numeric.csl` for citations

## Architecture

- `src/main.rs` — CLI entry (clap subcommands: new, build, serve, clean)
- `src/build.rs` — orchestrates Pandoc + Typst pipeline (XeLaTeX fallback)
- `src/metadata.rs` — regex-based metadata extraction from `.typ` or `.tex` files
- `src/template.rs` — Tera template rendering
- `src/server.rs` — tiny_http static file server
- `shared/blog.typ` — Typst document template (fonts, page layout, headers/footers, theorems)
- `shared/latexblog.sty` — legacy LaTeX package (still used for `.tex`-only posts)
- `templates/` — Tera HTML templates; `new-post.typ` is the post scaffold

## Key Conventions

- Post directories follow `posts/YYYY-MM-DD-slug/` naming; slug is derived by stripping the date prefix
- Each post should contain `post.typ` (preferred) and `post.md` (for HTML); `.tex` is legacy
- Metadata in `.typ` files uses `#show: blog-post.with(title: "...", date: "...", tags: (...))`
- Metadata in `.tex` files uses `\blogtitle{}`, `\blogdate{}`, etc.
- Post images go in `posts/YYYY-MM-DD-slug/images/`
- Template variable `root_path` provides relative path depth (e.g. `../../` for posts, empty for index)
- `output/` is the generated site root and is gitignored
- `scripts/convert_to_typst.py` — bulk conversion script (used for migration from `.tex`)
- `scripts/fix_typst.py` — post-processing fixes for converted `.typ` files
- `scripts/fix_remote_images.py` — comments out remote image URLs that Typst can't load