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

pub fn render_tag_index(
    tera: &Tera,
    tag: &str,
    posts: &[crate::metadata::PostMeta],
) -> Result<String> {
    let mut ctx = Context::new();
    ctx.insert("tag", tag);
    ctx.insert("posts", posts);
    ctx.insert("root_path", "../../");
    ctx.insert("lang", "en");
    let html = tera.render("tag.html", &ctx)?;
    Ok(html)
}

pub fn render_tags_all(
    tera: &Tera,
    tags_with_counts: &[(String, usize)],
) -> Result<String> {
    let tags: Vec<std::collections::HashMap<&str, tera::Value>> = tags_with_counts
        .iter()
        .map(|(name, count)| {
            let mut m = std::collections::HashMap::new();
            m.insert("name", tera::to_value(name).unwrap());
            m.insert("count", tera::to_value(count).unwrap());
            m
        })
        .collect();
    
    let mut ctx = Context::new();
    ctx.insert("tags", &tags);
    ctx.insert("root_path", "");
    ctx.insert("lang", "en");
    let html = tera.render("tags-all.html", &ctx)?;
    Ok(html)
}
