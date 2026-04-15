#!/usr/bin/env python3
"""
Migrate Hexo markdown posts to latex-blog format.
Converts .md -> .tex using pandoc, preserving metadata.
"""

import os
import re
import subprocess
import sys
import shutil
from pathlib import Path

OLD_BLOG = Path("/Users/riguz/Workspace/blog/source/_posts")
OLD_IMAGES = Path("/Users/riguz/Workspace/blog/source/images")
NEW_BLOG = Path("/Users/riguz/Workspace/typedefai/latex-blog/posts")
SHARED = Path("/Users/riguz/Workspace/typedefai/latex-blog/shared")

def parse_frontmatter(md_path: Path):
    """Parse YAML frontmatter from a Hexo markdown file (no pyyaml needed)."""
    text = md_path.read_text(encoding="utf-8")
    m = re.match(r'^\s*---\s*\n(.*?)\n---\s*\n', text, re.DOTALL)
    if not m:
        return None, text
    
    raw = m.group(1)
    body = text[m.end():]
    
    meta = {}
    # Parse title
    tm = re.search(r'^title:\s*(.+)$', raw, re.MULTILINE)
    if tm:
        meta['title'] = tm.group(1).strip().strip('"').strip("'")
    
    # Parse date
    dm = re.search(r'^date:\s*(\S+)', raw, re.MULTILINE)
    if dm:
        meta['date'] = dm.group(1).strip()
    
    # Parse categories (list items under categories:)
    cats = []
    cm = re.search(r'^categories:\s*\n((?:\s+-\s+.+\n?)+)', raw, re.MULTILINE)
    if cm:
        cats = [c.strip() for c in re.findall(r'-\s+(.+)', cm.group(1))]
    meta['categories'] = cats
    
    # Parse tags (list items under tags:)
    tags = []
    tm2 = re.search(r'^tags:\s*\n((?:\s+-\s+.+\n?)+)', raw, re.MULTILINE)
    if tm2:
        tags = [t.strip() for t in re.findall(r'-\s+(.+)', tm2.group(1))]
    meta['tags'] = tags
    
    return meta, body


def clean_body(body: str) -> str:
    """Remove Hexo-specific markers like <!-- more -->."""
    body = re.sub(r'<!--\s*more\s*-->', '', body)
    # Remove {% raw %} / {% endraw %} liquid tags
    body = re.sub(r'\{%\s*raw\s*%\}', '', body)
    body = re.sub(r'\{%\s*endraw\s*%\}', '', body)
    # Remove {% asset_img ... %} and replace with plain image
    body = re.sub(r'\{%\s*asset_img\s+(\S+)\s+(.*?)\s*%\}', r'![\2](\1)', body)
    return body.strip()


def fix_image_refs(body: str, images_dir: Path) -> str:
    """Fix image references: /images/foo.png -> images/foo.png and copy images."""
    def replace_img(m):
        alt = m.group(1)
        src = m.group(2)
        # Extract filename from path
        fname = os.path.basename(src)
        old_img = OLD_IMAGES / fname
        if old_img.exists():
            new_img = images_dir / fname
            shutil.copy2(old_img, new_img)
        return f'![{alt}](images/{fname})'
    
    body = re.sub(r'!\[([^\]]*)\]\((/images/|images/)([^)]+)\)', 
                  lambda m: f'![{m.group(1)}](images/{m.group(3)})',
                  body)
    
    # Copy referenced images
    for m in re.finditer(r'!\[[^\]]*\]\(images/([^)]+)\)', body):
        fname = m.group(1)
        old_img = OLD_IMAGES / fname
        if old_img.exists():
            new_img = images_dir / fname
            shutil.copy2(old_img, new_img)
    
    return body


def md_to_tex_via_pandoc(md_content: str, work_dir: Path) -> str:
    """Convert markdown content to LaTeX using pandoc."""
    tmp_md = work_dir / "_temp_input.md"
    tmp_md.write_text(md_content, encoding="utf-8")
    
    try:
        result = subprocess.run(
            [
                "pandoc", str(tmp_md),
                "--from=markdown",
                "--to=latex",
                "--wrap=none",
            ],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            print(f"  pandoc warning: {result.stderr[:200]}")
        return result.stdout
    finally:
        tmp_md.unlink(missing_ok=True)


def slugify(text: str) -> str:
    """Create a URL-friendly slug from text."""
    # For non-ASCII (Chinese), use pinyin-like approach or just use the filename
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    text = re.sub(r'-+', '-', text)
    return text.strip('-')


def escape_latex(s: str) -> str:
    """Escape special LaTeX characters in metadata strings."""
    s = s.replace('\\', r'\textbackslash{}')
    s = s.replace('&', r'\&')
    s = s.replace('%', r'\%')
    s = s.replace('$', r'\$')
    s = s.replace('#', r'\#')
    s = s.replace('_', r'\_')
    s = s.replace('{', r'\{')
    s = s.replace('}', r'\}')
    s = s.replace('~', r'\textasciitilde{}')
    s = s.replace('^', r'\textasciicircum{}')
    return s


def process_post(md_path: Path, idx: int, total: int):
    """Convert a single markdown post to LaTeX blog format."""
    meta, body = parse_frontmatter(md_path)
    if meta is None:
        print(f"  [{idx}/{total}] SKIP (no frontmatter): {md_path.name}")
        return False
    
    title = meta.get("title", "Untitled")
    date = str(meta.get("date", "1970-01-01"))
    # Handle datetime objects
    if hasattr(date, 'strftime'):
        date = date.strftime('%Y-%m-%d')
    # Ensure date is just YYYY-MM-DD
    date = date[:10]
    
    categories = meta.get("categories", [])
    if isinstance(categories, str):
        categories = [categories]
    tags = meta.get("tags", [])
    if isinstance(tags, str):
        tags = [tags]
    # Combine categories and tags for blog tags
    all_tags = list(set(categories + tags)) if tags or categories else []
    
    # Determine language from content
    has_cjk = bool(re.search(r'[\u4e00-\u9fff]', title + body[:200]))
    lang = "zh" if has_cjk else "en"
    
    # Create slug from filename (more reliable than title for Chinese posts)
    file_slug = md_path.stem
    file_slug = slugify(file_slug) or md_path.stem.lower().replace(' ', '-')
    
    # Create output directory
    dir_name = f"{date}-{file_slug}"
    post_dir = NEW_BLOG / dir_name
    
    if post_dir.exists():
        print(f"  [{idx}/{total}] SKIP (exists): {dir_name}")
        return False
    
    post_dir.mkdir(parents=True, exist_ok=True)
    images_dir = post_dir / "images"
    images_dir.mkdir(exist_ok=True)
    
    # Clean and fix body
    body = clean_body(body)
    body = fix_image_refs(body, images_dir)
    
    # Convert markdown body to LaTeX via pandoc
    tex_body = md_to_tex_via_pandoc(body, post_dir)
    
    if not tex_body.strip():
        print(f"  [{idx}/{total}] WARN (empty conversion): {md_path.name}")
        # Try to keep going with raw body
        tex_body = f"% Raw content - pandoc conversion failed\n% Original file: {md_path}\n"
    
    # Escape metadata for LaTeX
    safe_tags = ", ".join(all_tags)
    
    # Build the .tex file
    # Note: title may contain special chars; we need careful escaping
    # but also want to preserve intentional LaTeX like math
    tex_content = f"""\\documentclass[12pt]{{article}}
\\usepackage{{latexblog}}

% ============================================================
% Blog Metadata
% ============================================================
\\blogtitle{{{title}}}
\\blogdate{{{date}}}
\\blogtags{{{safe_tags}}}
\\bloglang{{{lang}}}
\\blogsummary{{}}

\\begin{{document}}
\\makeblogtitle

{tex_body}

\\end{{document}}
"""
    
    (post_dir / "post.tex").write_text(tex_content, encoding="utf-8")
    
    # Also save the cleaned markdown for HTML generation
    # (pandoc can convert markdown->HTML with proper code highlighting)
    (post_dir / "post.md").write_text(body, encoding="utf-8")

    # Remove images dir if empty
    if not any(images_dir.iterdir()):
        images_dir.rmdir()
    
    print(f"  [{idx}/{total}] OK: {dir_name}  ({title})")
    return True


def main():
    if not OLD_BLOG.exists():
        print(f"Error: Old blog not found at {OLD_BLOG}")
        sys.exit(1)
    
    # Find all markdown files
    md_files = sorted(OLD_BLOG.rglob("*.md"))
    total = len(md_files)
    print(f"Found {total} markdown posts to migrate.\n")
    
    success = 0
    failed = 0
    skipped = 0
    
    for idx, md_path in enumerate(md_files, 1):
        try:
            result = process_post(md_path, idx, total)
            if result:
                success += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"  [{idx}/{total}] ERROR: {md_path.name}: {e}")
            failed += 1
    
    print(f"\n{'='*50}")
    print(f"Migration complete: {success} converted, {skipped} skipped, {failed} failed")
    print(f"Total: {total} posts")


if __name__ == "__main__":
    main()
