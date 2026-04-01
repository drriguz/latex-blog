use anyhow::Result;
use std::path::Path;
use tera::{Context, Tera};

pub fn load_templates(root: &Path) -> Result<Tera> {
    let template_dir = root.join("templates/**/*.html");
    let tera = Tera::new(
        template_dir
            .to_str()
            .ok_or_else(|| anyhow::anyhow!("Invalid template path"))?,
    )?;
    Ok(tera)
}

pub fn render_post(
    tera: &Tera,
    title: &str,
    date: &str,
    tags: &[String],
    lang: &str,
    content: &str,
) -> Result<String> {
    let mut ctx = Context::new();
    ctx.insert("title", title);
    ctx.insert("date", date);
    ctx.insert("tags", tags);
    ctx.insert("lang", lang);
    ctx.insert("content", content);
    ctx.insert("root_path", "../../");
    let html = tera.render("post.html", &ctx)?;
    Ok(html)
}

pub fn render_index(tera: &Tera, posts: &[crate::metadata::PostMeta]) -> Result<String> {
    let mut ctx = Context::new();
    ctx.insert("posts", posts);
    ctx.insert("root_path", "");
    ctx.insert("lang", "en");
    let html = tera.render("index.html", &ctx)?;
    Ok(html)
}
