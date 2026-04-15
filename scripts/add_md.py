#!/usr/bin/env python3
"""Add post.md files to existing migrated post directories."""
import re
from pathlib import Path

OLD_BLOG = Path("/Users/riguz/Workspace/blog/source/_posts")
NEW_BLOG = Path("/Users/riguz/Workspace/typedefai/latex-blog/posts")

def parse_frontmatter(md_path):
    text = md_path.read_text(encoding="utf-8")
    m = re.match(r'^\s*---\s*\n(.*?)\n---\s*\n', text, re.DOTALL)
    if not m:
        return None, text
    return True, text[m.end():]

def clean_body(body):
    body = re.sub(r'<!--\s*more\s*-->', '', body)
    body = re.sub(r'\{%\s*raw\s*%\}', '', body)
    body = re.sub(r'\{%\s*endraw\s*%\}', '', body)
    body = re.sub(r'\{%\s*asset_img\s+(\S+)\s+(.*?)\s*%\}', r'![\2](\1)', body)
    body = re.sub(
        r'!\[([^\]]*)\]\((/images/|images/)([^)]+)\)',
        lambda m: '![' + m.group(1) + '](images/' + m.group(3) + ')',
        body
    )
    return body.strip()

count = 0
for md_file in sorted(OLD_BLOG.rglob("*.md")):
    meta, body = parse_frontmatter(md_file)
    if meta is None:
        continue
    body = clean_body(body)
    
    slug = md_file.stem.lower().replace(" ", "-")
    slug = re.sub(r'[^\w\s-]', '', slug)
    slug = re.sub(r'[\s_]+', '-', slug)
    slug = re.sub(r'-+', '-', slug).strip('-')
    
    for d in NEW_BLOG.iterdir():
        if d.is_dir() and d.name.endswith(slug):
            md_out = d / "post.md"
            if not md_out.exists():
                md_out.write_text(body, encoding="utf-8")
                count += 1
            break

print(f"Added {count} .md files")
