#!/usr/bin/env python3
"""Post-process converted .typ files to fix common pandoc conversion issues."""

import re
import sys
from pathlib import Path

BLOG_ROOT = Path(__file__).resolve().parent.parent
POSTS_DIR = BLOG_ROOT / "posts"


def fix_remote_images(content):
    # Pandoc converts markdown ![alt](https://url) to #image("https://...")
    # Typst can't load remote images, so comment them out
    # Pattern: #image("https://...") or #image(url("https://..."))
    content = re.sub(
        r'#image\("https?://[^"]*"\)',
        r'// Remote image removed: \g<0>',
        content,
    )
    content = re.sub(
        r'#image\(url\("https?://[^"]*"\)\)',
        r'// Remote image removed: \g<0>',
        content,
    )
    # Also handle figure-wrapped remote images
    content = re.sub(
        r'(#figure\(\s*// Remote image[^)]*\)[^)]*\))',
        r'// \g<0>',
        content,
        flags=re.DOTALL,
    )
    return content


def fix_citations(content):
    # Replace @cooley1965fft with plain text (no bibliography in typst)
    content = re.sub(r"@cooley1965fft", "Cooley & Tukey, 1965", content)
    # Replace #cite(label("..."), form: "prose") patterns
    content = re.sub(
        r'#cite\(label\("[^"]*"\),\s*form:\s*"prose"\)',
        r"[citation]",
        content,
    )
    return content


def fix_math_issues(content):
    # Fix Stimes → × (pandoc sometimes fails to convert \times in subscripts)
    content = content.replace("Stimes", "times")
    # Fix other common pandoc math conversion artifacts
    content = content.replace("\\(", "(")
    content = content.replace("\\)", ")")
    return content


def fix_bibliography_env(content):
    content = re.sub(r"#bibliography\([^)]*\)", "// Bibliography removed (no .bib in typst)", content)
    return content


def process_file(path):
    content = path.read_text(encoding="utf-8")
    original = content

    content = fix_remote_images(content)
    content = fix_citations(content)
    content = fix_math_issues(content)
    content = fix_bibliography_env(content)

    if content != original:
        path.write_text(content, encoding="utf-8")
        return True
    return False


def main():
    changed = 0
    for post_dir in sorted(POSTS_DIR.iterdir()):
        if not post_dir.is_dir():
            continue
        typ_file = post_dir / "post.typ"
        if not typ_file.exists():
            continue
        if process_file(typ_file):
            changed += 1
            print(f"  Fixed: {post_dir.name}")
    print(f"\nTotal files fixed: {changed}")


if __name__ == "__main__":
    main()