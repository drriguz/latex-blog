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

pub fn parse_metadata(tex_path: &Path) -> Result<PostMeta> {
    let content = std::fs::read_to_string(tex_path)
        .with_context(|| format!("Failed to read {}", tex_path.display()))?;

    let title = extract_command(&content, "blogtitle").unwrap_or_else(|| "Untitled".to_string());
    let date = extract_command(&content, "blogdate").unwrap_or_else(|| "1970-01-01".to_string());
    let tags_str = extract_command(&content, "blogtags").unwrap_or_default();
    let lang = extract_command(&content, "bloglang").unwrap_or_else(|| "en".to_string());
    let summary = extract_command(&content, "blogsummary").unwrap_or_default();

    let tags: Vec<String> = if tags_str.is_empty() {
        vec![]
    } else {
        tags_str
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect()
    };

    // Derive slug from the parent directory name, stripping the date prefix
    let source_dir = tex_path
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

fn extract_command(content: &str, command: &str) -> Option<String> {
    let pattern = format!(r"\\{}\{{([^}}]*)\}}", regex::escape(command));
    let re = Regex::new(&pattern).ok()?;
    re.captures(content).map(|caps| caps[1].to_string())
}

/// Strip date prefix (YYYY-MM-DD-) from directory name to get slug
fn derive_slug(dir_name: &str) -> String {
    let date_prefix = Regex::new(r"^\d{4}-\d{2}-\d{2}-").unwrap();
    date_prefix.replace(dir_name, "").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_command() {
        let content = r#"\blogtitle{Hello World}
\blogdate{2025-12-01}
\blogtags{rust, latex}"#;
        assert_eq!(
            extract_command(content, "blogtitle"),
            Some("Hello World".into())
        );
        assert_eq!(
            extract_command(content, "blogdate"),
            Some("2025-12-01".into())
        );
        assert_eq!(
            extract_command(content, "blogtags"),
            Some("rust, latex".into())
        );
        assert_eq!(extract_command(content, "bloglang"), None);
    }

    #[test]
    fn test_derive_slug() {
        assert_eq!(derive_slug("2025-12-01-hello-world"), "hello-world");
        assert_eq!(derive_slug("no-date-prefix"), "no-date-prefix");
    }
}
