#!/usr/bin/env python3
"""Convert blog posts from LaTeX to Typst format.

For posts with post.md: generate .typ from .md via pandoc (cleaner).
For posts without post.md: generate .typ from .tex via pandoc (may need manual review).
"""

import os
import re
import subprocess
import sys
from pathlib import Path

BLOG_ROOT = Path(__file__).resolve().parent.parent
POSTS_DIR = BLOG_ROOT / "posts"
SHARED_DIR = BLOG_ROOT / "shared"


def extract_metadata(tex_path):
    content = tex_path.read_text(encoding="utf-8")

    def extract(cmd):
        pattern = rf"\\{cmd}\{{([^}}]*)\}}"
        m = re.search(pattern, content)
        return m.group(1) if m else None

    title = extract("blogtitle") or "Untitled"
    date = extract("blogdate") or "1970-01-01"
    tags_str = extract("blogtags") or ""
    lang = extract("bloglang") or "en"
    summary = extract("blogsummary") or ""
    author = extract("blogauthor") or "Riguz"

    tags = [t.strip() for t in tags_str.split(",") if t.strip()]

    return {
        "title": title,
        "date": date,
        "tags": tags,
        "lang": lang,
        "summary": summary,
        "author": author,
    }


def esc_typst_str(s):
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    return s


def typst_tags(tags):
    if not tags:
        return "()"
    return "(" + ", ".join(f'"{t}"' for t in tags) + ")"


def generate_header(meta):
    title_esc = esc_typst_str(meta["title"])
    summary_esc = esc_typst_str(meta["summary"])

    lines = [
        '#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary',
        '#show: blog-post.with(',
        f'  title: "{title_esc}",',
        f'  date: "{meta["date"]}",',
        f'  tags: {typst_tags(meta["tags"])},',
        f'  lang: "{meta["lang"]}",',
    ]
    if summary_esc:
        lines.append(f'  summary: "{summary_esc}",')
    if meta["author"] != "Riguz":
        lines.append(f'  author: "{esc_typst_str(meta["author"])}",')
    lines.append(")")
    lines.append("")
    return "\n".join(lines)


def preprocess_tex(tex_content):
    content = tex_content

    # Remove preamble
    content = re.sub(r"\\documentclass.*?\n", "", content)
    content = re.sub(r"\\usepackage\{.*?\}\n", "", content)

    # Remove blog metadata commands
    for cmd in [
        "blogtitle",
        "blogdate",
        "blogtags",
        "bloglang",
        "blogsummary",
        "blogauthor",
    ]:
        content = re.sub(rf"\\{cmd}\{{[^}}]*\}}\n?", "", content)

    # Remove makeblogtitle
    content = re.sub(r"\\makeblogtitle\n?", "", content)

    # Remove \begin{document} and \end{document}
    content = re.sub(r"\\begin\{document\}\n?", "", content)
    content = re.sub(r"\\end\{document\}\n?", "", content)

    # Remove comment lines about blog metadata
    content = re.sub(r"%.*?Blog.*?Metadata.*?\n", "", content)
    content = re.sub(r"%\s*=+\s*\n", "", content)

    # Convert \sidenote{...} to a placeholder that pandoc can handle
    content = re.sub(r"\\sidenote\{([^}]*)\}", r"<!-- sidenote: \1 -->", content)

    # Convert \textcolor{color}{text} to \textbf{text} (pandoc strips color)
    content = re.sub(r"\\textcolor\{[^}]*\}\{([^}]*)\}", r"\textbf{\1}", content)

    return content.strip()


def convert_md_to_typst(md_path):
    result = subprocess.run(
        ["pandoc", str(md_path), "--from=markdown", "--to=typst"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if result.returncode != 0:
        print(f"    Pandoc warning: {result.stderr[:200]}")
    return result.stdout


def convert_tex_to_typst(tex_path):
    content = tex_path.read_text(encoding="utf-8")
    cleaned = preprocess_tex(content)

    tmp = tex_path.parent / "_temp_cleaned.tex"
    tmp.write_text(cleaned, encoding="utf-8")

    try:
        result = subprocess.run(
            ["pandoc", str(tmp), "--from=latex+raw_tex", "--to=typst"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            print(f"    Pandoc warning: {result.stderr[:200]}")
        return result.stdout
    finally:
        tmp.unlink(missing_ok=True)


def postprocess_typst(content):
    # Convert sidenote placeholders to Typst sidenote calls
    content = re.sub(r"<!-- sidenote: (.+?) -->", r"#sidenote[\1]", content)

    # Remove any remaining Shaded/Highlighting artifacts from pandoc (shouldn't appear in typst output)
    content = re.sub(r"// Shaded.*?\n", "", content)

    return content


def convert_post(post_dir):
    post_tex = post_dir / "post.tex"
    post_md = post_dir / "post.md"
    post_typ = post_dir / "post.typ"

    if not post_tex.exists():
        print(f"  SKIP: No post.tex in {post_dir.name}")
        return False

    meta = extract_metadata(post_tex)

    if post_md.exists():
        print(f"  MD->Typst: {post_dir.name}")
        body = convert_md_to_typst(post_md)
    else:
        print(f"  TEX->Typst: {post_dir.name}")
        body = convert_tex_to_typst(post_tex)

    if not body.strip():
        print(f"  WARN: Empty conversion for {post_dir.name}")
        body = f"// Empty conversion - original source: post.tex\n"

    body = postprocess_typst(body)

    header = generate_header(meta)
    output = header + "\n" + body

    post_typ.write_text(output, encoding="utf-8")
    print(f"  OK: {post_dir.name}/post.typ")
    return True


def main():
    skip_dirs = {"2026-01-01-test"}
    posts = sorted([d for d in POSTS_DIR.iterdir() if d.is_dir() and d.name not in skip_dirs])
    total = len(posts)
    success = 0
    failed = 0
    skipped = 0

    for idx, post_dir in enumerate(posts, 1):
        print(f"[{idx}/{total}] {post_dir.name}")
        try:
            result = convert_post(post_dir)
            if result:
                success += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"  ERROR: {e}")
            failed += 1

    print(f"\n{'=' * 50}")
    print(f"Conversion: {success} converted, {skipped} skipped, {failed} failed")


if __name__ == "__main__":
    main()