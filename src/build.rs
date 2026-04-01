use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
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

        // 1. Convert LaTeX to HTML via Pandoc
        println!("[pandoc] Converting {} ...", post.title);
        let html_fragment = run_pandoc(&post_source_dir.join("post.tex"), &shared_dir)?;

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

        // 3. Compile PDF via XeLaTeX
        println!("[xelatex] Compiling {} ...", post.title);
        match run_xelatex(&post_source_dir, &shared_dir) {
            Ok(pdf_path) => {
                std::fs::copy(&pdf_path, post_output_dir.join("post.pdf"))?;
                println!("  -> PDF generated.");
            }
            Err(e) => {
                eprintln!("  -> PDF compilation failed: {}. Skipping PDF.", e);
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
            let tex_file = path.join("post.tex");
            if tex_file.exists() {
                match metadata::parse_metadata(&tex_file) {
                    Ok(meta) => posts.push(meta),
                    Err(e) => eprintln!("Warning: Failed to parse {}: {}", tex_file.display(), e),
                }
            }
        }
    }

    Ok(posts)
}

fn run_pandoc(tex_path: &Path, shared_dir: &Path) -> Result<String> {
    let output = Command::new("pandoc")
        .arg(tex_path)
        .arg("--from=latex")
        .arg("--to=html5")
        .arg("--mathjax") // outputs math in a format KaTeX auto-render can pick up
        .arg("--highlight-style=pygments")
        .arg(format!(
            "--resource-path={}:{}",
            tex_path.parent().unwrap().display(),
            shared_dir.display()
        ))
        .output()
        .context("Failed to run pandoc. Is pandoc installed?")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Pandoc failed:\n{}", stderr);
    }

    let html = String::from_utf8(output.stdout)
        .context("Pandoc produced invalid UTF-8")?;

    Ok(html)
}

fn run_xelatex(post_dir: &Path, shared_dir: &Path) -> Result<PathBuf> {
    let tex_file = post_dir.join("post.tex");

    // Run xelatex twice for cross-references
    for pass in 1..=2 {
        let output = Command::new("xelatex")
            .arg("-interaction=nonstopmode")
            .arg("-halt-on-error")
            .arg(format!("-output-directory={}", post_dir.display()))
            .env(
                "TEXINPUTS",
                format!("{}:{}:", post_dir.display(), shared_dir.display()),
            )
            .arg(&tex_file)
            .output()
            .context("Failed to run xelatex. Is texlive installed?")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let stdout = String::from_utf8_lossy(&output.stdout);
            if pass == 2 {
                anyhow::bail!(
                    "XeLaTeX failed (pass {}):\nstdout: {}\nstderr: {}",
                    pass,
                    stdout.chars().take(2000).collect::<String>(),
                    stderr.chars().take(2000).collect::<String>()
                );
            }
        }
    }

    let pdf_path = post_dir.join("post.pdf");
    if pdf_path.exists() {
        Ok(pdf_path)
    } else {
        anyhow::bail!("PDF not generated at {}", pdf_path.display())
    }
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
