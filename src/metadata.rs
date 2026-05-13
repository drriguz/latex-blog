use anyhow::{Context, Result};
use regex::Regex;
use std::path::Path;

#[derive(Debug, Clone, serde::Serialize)]
pub struct PostMeta {
    pub title: String,
    pub date: String,
    pub tags: Vec<String>,
    pub lang: String,
    pub summary: String,
    pub slug: String,
    pub source_dir: String,
}

pub fn parse_metadata(typ_path: &Path) -> Result<PostMeta> {
    let content = std::fs::read_to_string(typ_path)
        .with_context(|| format!("Failed to read {}", typ_path.display()))?;

    let title = extract_typst_param(&content, "title").unwrap_or_else(|| "Untitled".to_string());
    let date = extract_typst_param(&content, "date").unwrap_or_else(|| "1970-01-01".to_string());
    let tags_str = extract_typst_param(&content, "tags").unwrap_or_default();
    let lang = extract_typst_param(&content, "lang").unwrap_or_else(|| "en".to_string());
    let summary = extract_typst_param(&content, "summary").unwrap_or_default();

    let tags = parse_typst_tags(&tags_str);

    let source_dir = typ_path
        .parent()
        .and_then(|p| p.file_name())
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    let slug = derive_slug(&source_dir);

    Ok(PostMeta {
        title,
        date,
        tags,
        lang,
        summary,
        slug,
        source_dir,
    })
}

fn extract_typst_param(content: &str, param: &str) -> Option<String> {
    let pattern = format!(
        r#"(?:^|\s|,){}\s*:\s*"((?:[^"\\]|\\.)*)""#,
        regex::escape(param)
    );
    let re = Regex::new(&pattern).ok()?;
    let caps = re.captures(content)?;
    Some(caps[1].replace("\\\"", "\"").replace("\\\\", "\\"))
}

fn parse_typst_tags(tags_str: &str) -> Vec<String> {
    if tags_str.is_empty() {
        return vec![];
    }
    let re = Regex::new(r#""([^"]*)""#).unwrap();
    re.captures_iter(tags_str)
        .map(|caps| caps[1].to_string())
        .collect()
}

fn derive_slug(dir_name: &str) -> String {
    let date_prefix = Regex::new(r"^\d{4}-\d{2}-\d{2}-").unwrap();
    date_prefix.replace(dir_name, "").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_typst_param() {
        let content = r#"#show: blog-post.with(
  title: "Understanding FFT",
  date: "2025-12-01",
  tags: ("math", "algorithms", "signal-processing"),
  lang: "en",
  summary: "An intro to FFT",
)"#;
        assert_eq!(
            extract_typst_param(content, "title"),
            Some("Understanding FFT".into())
        );
        assert_eq!(
            extract_typst_param(content, "date"),
            Some("2025-12-01".into())
        );
        assert_eq!(extract_typst_param(content, "lang"), Some("en".into()));
        assert_eq!(
            extract_typst_param(content, "summary"),
            Some("An intro to FFT".into())
        );
    }

    #[test]
    fn test_parse_typst_tags() {
        assert_eq!(
            parse_typst_tags(r#"("math", "algorithms")"#),
            vec!["math", "algorithms"]
        );
        assert_eq!(parse_typst_tags(r#"("rust",)"#), vec!["rust"]);
        assert_eq!(parse_typst_tags(""), Vec::<String>::new());
    }

    #[test]
    fn test_derive_slug() {
        assert_eq!(derive_slug("2025-12-01-hello-world"), "hello-world");
        assert_eq!(derive_slug("no-date-prefix"), "no-date-prefix");
    }
}