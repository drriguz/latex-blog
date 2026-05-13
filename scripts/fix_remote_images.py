#!/usr/bin/env python3
"""Fix remote image URLs and other issues in converted .typ files.

Typst cannot load remote images, so we need to comment them out or
replace them with local references.
"""

import re
from pathlib import Path

BLOG_ROOT = Path(__file__).resolve().parent.parent
POSTS_DIR = BLOG_ROOT / "posts"


def fix_typst_file(path):
    content = path.read_text(encoding="utf-8")
    original = content
    lines = content.split("\n")
    result = []
    skip_until_close = 0
    i = 0

    while i < len(lines):
        line = lines[i]

        # If we're skipping a figure block with remote image
        if skip_until_close > 0:
            open_parens = line.count("(") - line.count(")")
            skip_until_close += open_parens
            if skip_until_close <= 0:
                result.append("// " + line)
                skip_until_close = 0
            else:
                result.append("// " + line)
            i += 1
            continue

        # Check for remote URLs in image() calls
        if re.search(r'image\("(https?://[^"]*)"', line):
            url = re.search(r'image\("(https?://[^"]*)"', line)
            if url:
                url_str = url.group(1)

            # Check if inside a #figure() block
            if "#figure(" in line or "figure(" in line:
                # Comment out from here, track parens
                indent = len(line) - len(line.lstrip())
                prefix = " " * indent + "// "
                result.append(prefix + f"Remote image removed: {url_str}")
                # Skip the entire figure block
                open_count = line.count("(")
                close_count = line.count(")")
                balance = open_count - close_count
                skip_until_close = 0
                # Check if the figure closes on this line or later
                if balance <= 0 and line.strip().endswith(")"):
                    # If figure is on a single line
                    result.append("// " + line)
                    i += 1
                    continue

                # Multi-line figure - skip until we find the closing )
                j = i + 1
                collected = [line]
                balance = line.count("(") - line.count(")")
                while j < len(lines) and balance > 0:
                    collected.append(lines[j])
                    balance += lines[j].count("(") - lines[j].count(")")
                    j += 1
                for cl in collected:
                    result.append("// " + cl)
                i = j
                continue
            else:
                # Simple image - comment out
                result.append("// " + line)
                i += 1
                continue

        # Fix absolute /images/ paths → relative images/
        line = re.sub(r'image\("/images/', 'image("images/', line)

        result.append(line)
        i += 1

    content = "\n".join(result)
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
        if fix_typst_file(typ_file):
            changed += 1
            print(f"  Fixed: {post_dir.name}")
    print(f"\nTotal files fixed: {changed}")


if __name__ == "__main__":
    main()