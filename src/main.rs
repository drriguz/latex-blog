mod build;
mod metadata;
mod server;
mod template;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(
    name = "latex-blog",
    about = "A static blog generator powered by XeLaTeX and Pandoc"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new blog post
    New {
        /// Title of the new post
        title: String,
        /// Tags (comma-separated)
        #[arg(short, long, default_value = "")]
        tags: String,
        /// Language
        #[arg(short, long, default_value = "en")]
        lang: String,
    },
    /// Build the static site
    Build,
    /// Start a local development server
    Serve {
        /// Port to listen on
        #[arg(short, long, default_value_t = 9527)]
        port: u16,
    },
    /// Clean the output directory
    Clean,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let project_root = std::env::current_dir()?;

    match cli.command {
        Commands::New { title, tags, lang } => cmd_new(&project_root, &title, &tags, &lang),
        Commands::Build => cmd_build(&project_root),
        Commands::Serve { port } => cmd_serve(&project_root, port),
        Commands::Clean => cmd_clean(&project_root),
    }
}

fn cmd_new(root: &PathBuf, title: &str, tags: &str, _lang: &str) -> Result<()> {
    let date = chrono::Local::now().format("%Y-%m-%d").to_string();
    let title_slug = slug::slugify(title);
    let dir_name = format!("{}-{}", date, title_slug);
    let post_dir = root.join("posts").join(&dir_name);

    if post_dir.exists() {
        anyhow::bail!("Post directory already exists: {}", post_dir.display());
    }

    std::fs::create_dir_all(post_dir.join("images"))?;

    let template = std::fs::read_to_string(root.join("templates/new-post.tex"))?;
    let content = template
        .replace("__TITLE__", title)
        .replace("__DATE__", &date)
        .replace("__TAGS__", tags);

    std::fs::write(post_dir.join("post.tex"), content)?;

    println!("Created new post: posts/{}/post.tex", dir_name);
    Ok(())
}

fn cmd_build(root: &PathBuf) -> Result<()> {
    build::build_site(root)
}

fn cmd_serve(root: &PathBuf, port: u16) -> Result<()> {
    let output_dir = root.join("output");
    if !output_dir.exists() {
        println!("Output directory not found. Building site first...");
        build::build_site(root)?;
    }
    server::serve(&output_dir, port)
}

fn cmd_clean(root: &PathBuf) -> Result<()> {
    let output_dir = root.join("output");
    if output_dir.exists() {
        std::fs::remove_dir_all(&output_dir)?;
        println!("Cleaned output directory.");
    } else {
        println!("Output directory does not exist.");
    }
    Ok(())
}
