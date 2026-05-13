use anyhow::{Context, Result};
use std::path::Path;
use std::process::Command;

use crate::metadata::{self, PostMeta};
use crate::template;

pub fn build_site(root: &Path) -> Result<()> {
    let posts_dir = root.join("posts");
    let output_dir = root.join("output");
    let shared_dir = root.join("shared");

    if !posts_dir.exists() {
        anyhow::bail!("No posts/ directory found. Create a post first with `latex-blog new`.");
    }

    // Collect all posts
    let mut posts = discover_posts(&posts_dir)?;
    if posts.is_empty() {
        println!("No posts found in posts/");
        return Ok(());
    }

    // Sort by date descending
    posts.sort_by(|a, b| b.date.cmp(&a.date));

    // Prepare output directory
    if output_dir.exists() {
        std::fs::remove_dir_all(&output_dir)?;
    }
    std::fs::create_dir_all(&output_dir)?;

    // Load HTML templates
    let tera = template::load_templates(root)?;

    // Build each post
    for post in &posts {
        let post_source_dir = posts_dir.join(&post.source_dir);
        let post_output_dir = output_dir.join("posts").join(&post.slug);
        std::fs::create_dir_all(&post_output_dir)?;

        // 1. Convert to HTML via Pandoc
        // Prefer post.md (markdown) for HTML; fall back to extracting body from post.typ
        let md_source = post_source_dir.join("post.md");
        let typ_source = post_source_dir.join("post.typ");

        let html_fragment = if md_source.exists() {
            println!("[pandoc] Converting {} (from markdown) ...", post.title);
            run_pandoc_md(&md_source, &shared_dir)?
        } else if typ_source.exists() {
            println!("[pandoc] Converting {} (from typst body) ...", post.title);
            run_pandoc_typ_body(&typ_source, &shared_dir)?
        } else {
            anyhow::bail!("No source file found for post: {}", post.source_dir);
        };

        // 2. Render full HTML page with template
        let full_html = template::render_post(
            &tera,
            &post.title,
            &post.date,
            &post.tags,
            &post.lang,
            &html_fragment,
        )?;
        std::fs::write(post_output_dir.join("index.html"), &full_html)?;

        // 3. Compile PDF via Typst
        if typ_source.exists() {
            println!("[typst] Compiling {} ...", post.title);
            match run_typst(&typ_source, root) {
                Ok(()) => {
                    let pdf_path = typ_source.with_extension("pdf");
                    if pdf_path.exists() {
                        std::fs::copy(&pdf_path, post_output_dir.join("post.pdf"))?;
                        let _ = std::fs::remove_file(&pdf_path);
                        println!("  -> PDF generated.");
                    } else {
                        eprintln!("  -> PDF not found after typst compile.");
                    }
                }
                Err(e) => {
                    eprintln!("  -> Typst compilation failed: {}. Skipping PDF.", e);
                }
            }
        }

        // 4. Copy post-local images
        let images_dir = post_source_dir.join("images");
        if images_dir.exists() {
            let images_output = post_output_dir.join("images");
            copy_dir_recursive(&images_dir, &images_output)?;
        }

        println!("  -> Done: posts/{}/", post.slug);
    }

    // Generate index page
    println!("[index] Generating index page ...");
    let index_html = template::render_index(&tera, &posts)?;
    std::fs::write(output_dir.join("index.html"), &index_html)?;

    // Generate tag pages
    println!("[tags] Generating tag pages ...");
    generate_tag_pages(&tera, &posts, &output_dir)?;

    // Copy static assets
    let static_dir = root.join("static");
    if static_dir.exists() {
        copy_dir_recursive(&static_dir, &output_dir)?;
    }

    println!("\nBuild complete! Output: {}", output_dir.display());
    println!("Run `latex-blog serve` to preview locally.");
    Ok(())
}

fn discover_posts(posts_dir: &Path) -> Result<Vec<PostMeta>> {
    let mut posts = Vec::new();

    for entry in std::fs::read_dir(posts_dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            let typ_file = path.join("post.typ");

            let meta = if typ_file.exists() {
                metadata::parse_metadata(&typ_file)
            } else {
                continue;
            };

            match meta {
                Ok(m) => posts.push(m),
                Err(e) => eprintln!("Warning: Failed to parse {}: {}", path.display(), e),
            }
        }
    }

    Ok(posts)
}

fn generate_tag_pages(tera: &tera::Tera, posts: &[PostMeta], output_dir: &Path) -> Result<()> {
    use std::collections::HashMap;
    let mut tag_map: HashMap<String, Vec<PostMeta>> = HashMap::new();

    for post in posts {
        for tag in &post.tags {
            tag_map.entry(tag.clone()).or_default().push(post.clone());
        }
    }

    for (tag, tag_posts) in tag_map {
        let tag_dir = output_dir.join("tags").join(&tag);
        std::fs::create_dir_all(&tag_dir)?;
        let html = template::render_tag_index(tera, &tag, &tag_posts)?;
        std::fs::write(tag_dir.join("index.html"), html)?;
    }

    Ok(())
}

fn run_pandoc_typ_body(typ_path: &Path, shared_dir: &Path) -> Result<String> {
    // Strip Typst template header (#import, #show, #let lines) so Pandoc can parse the body
    let content = std::fs::read_to_string(typ_path)
        .with_context(|| format!("Failed to read {}", typ_path.display()))?;
    let body = strip_typst_header(&content);

    let tmp = typ_path.parent().unwrap().join("_temp_body.typ");
    std::fs::write(&tmp, body.as_bytes())?;

    let result = (|| -> Result<String> {
        let output = Command::new("pandoc")
            .arg(&tmp)
            .arg("--from=typst")
            .arg("--to=html5")
            .arg("--standalone")
            .arg("--toc")
            .arg("--toc-depth=3")
            .arg("--number-sections")
            .arg("--mathjax")
            .arg("--syntax-highlighting=none")
            .arg(format!(
                "--resource-path={}:{}",
                typ_path.parent().unwrap().display(),
                shared_dir.display()
            ))
            .arg(format!(
                "--lua-filter={}",
                shared_dir.join("codeblock.lua").display()
            ))
            .output()
            .context("Failed to run pandoc. Is pandoc installed?")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Pandoc (typst body) failed:\n{}", stderr);
        }

        extract_body(&output.stdout)
    })();

    let _ = std::fs::remove_file(&tmp);
    result
}

fn strip_typst_header(content: &str) -> String {
    let mut lines = content.lines().peekable();
    let mut body_start = 0;

    while let Some(line) = lines.next() {
        let trimmed = line.trim();
        // Skip import, show, and let lines that form the template header
        if trimmed.starts_with("#import")
            || trimmed.starts_with("#show:")
            || trimmed.starts_with("#show:")
            || (trimmed.starts_with("#let") && !trimmed.contains("="))
            || trimmed.is_empty()
        {
            body_start += line.len() + 1;
            continue;
        }
        // Also skip the closing ) of the #show block if it's alone on a line
        if trimmed == ")" {
            body_start += line.len() + 1;
            continue;
        }
        break;
    }

    if body_start > 0 {
        content[body_start..].trim_start().to_string()
    } else {
        content.to_string()
    }
}

fn run_pandoc_md(md_path: &Path, shared_dir: &Path) -> Result<String> {
    let output = Command::new("pandoc")
        .arg(md_path)
        .arg("--from=markdown")
        .arg("--to=html5")
        .arg("--standalone")
        .arg("--toc")
        .arg("--toc-depth=3")
        .arg("--number-sections")
        .arg("--mathjax")
        .arg("--syntax-highlighting=none")
        .arg(format!(
            "--lua-filter={}",
            shared_dir.join("codeblock.lua").display()
        ))
        .arg(format!(
            "--resource-path={}:{}",
            md_path.parent().unwrap().display(),
            shared_dir.display()
        ))
        .output()
        .context("Failed to run pandoc. Is pandoc installed?")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Pandoc (markdown) failed:\n{}", stderr);
    }

    extract_body(&output.stdout)
}

fn extract_body(stdout: &[u8]) -> Result<String> {
    let html = String::from_utf8(stdout.to_vec()).context("Pandoc produced invalid UTF-8")?;

    let body_start = html.find("<body>").map(|i| i + 6);
    let body_end = html.rfind("</body>");

    let content = if let (Some(start), Some(end)) = (body_start, body_end) {
        html[start..end].to_string()
    } else {
        html
    };

    Ok(content)
}

fn run_typst(typ_path: &Path, project_root: &Path) -> Result<()> {
    let status = Command::new("typst")
        .arg("compile")
        .arg("--root")
        .arg(project_root)
        .arg(typ_path)
        .arg(typ_path.with_extension("pdf"))
        .status()
        .context("Failed to run typst. Is typst installed?")?;

    if !status.success() {
        anyhow::bail!("Typst compilation failed for {}", typ_path.display());
    }

    Ok(())
}

fn copy_dir_recursive(src: &Path, dst: &Path) -> Result<()> {
    if !dst.exists() {
        std::fs::create_dir_all(dst)?;
    }

    for entry in std::fs::read_dir(src)? {
        let entry = entry?;
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());

        if src_path.is_dir() {
            copy_dir_recursive(&src_path, &dst_path)?;
        } else {
            std::fs::copy(&src_path, &dst_path)?;
        }
    }

    Ok(())
}