use anyhow::Result;
use std::path::Path;

pub fn serve(output_dir: &Path, port: u16) -> Result<()> {
    let addr = format!("0.0.0.0:{}", port);
    println!("Serving at http://localhost:{}", port);

    let server = tiny_http::Server::http(&addr)
        .map_err(|e| anyhow::anyhow!("Failed to start server: {}", e))?;

    let output_dir = output_dir.to_path_buf();

    for request in server.incoming_requests() {
        let url_path = request.url().to_string();
        let url_path = url_path.trim_start_matches('/');

        // Determine file path
        let file_path = if url_path.is_empty() {
            output_dir.join("index.html")
        } else {
            let candidate = output_dir.join(url_path);
            if candidate.is_dir() {
                candidate.join("index.html")
            } else {
                candidate
            }
        };

        // Security: ensure the resolved path is within output_dir
        let canonical = match file_path.canonicalize() {
            Ok(p) => p,
            Err(_) => {
                let response = tiny_http::Response::from_string("404 Not Found")
                    .with_status_code(404);
                let _ = request.respond(response);
                continue;
            }
        };

        let canonical_output = match output_dir.canonicalize() {
            Ok(p) => p,
            Err(_) => {
                let response = tiny_http::Response::from_string("500 Internal Server Error")
                    .with_status_code(500);
                let _ = request.respond(response);
                continue;
            }
        };

        if !canonical.starts_with(&canonical_output) {
            let response = tiny_http::Response::from_string("403 Forbidden")
                .with_status_code(403);
            let _ = request.respond(response);
            continue;
        }

        if canonical.is_file() {
            let content_type = guess_content_type(&canonical);
            match std::fs::read(&canonical) {
                Ok(data) => {
                    let response = tiny_http::Response::from_data(data)
                        .with_header(
                            tiny_http::Header::from_bytes(
                                &b"Content-Type"[..],
                                content_type.as_bytes(),
                            )
                            .unwrap(),
                        )
                        .with_status_code(200);
                    let _ = request.respond(response);
                }
                Err(_) => {
                    let response = tiny_http::Response::from_string("404 Not Found")
                        .with_status_code(404);
                    let _ = request.respond(response);
                }
            }
        } else {
            let response = tiny_http::Response::from_string("404 Not Found")
                .with_status_code(404);
            let _ = request.respond(response);
        }
    }

    Ok(())
}

fn guess_content_type(path: &Path) -> String {
    match path.extension().and_then(|e| e.to_str()) {
        Some("html") => "text/html; charset=utf-8".to_string(),
        Some("css") => "text/css; charset=utf-8".to_string(),
        Some("js") => "application/javascript; charset=utf-8".to_string(),
        Some("json") => "application/json; charset=utf-8".to_string(),
        Some("png") => "image/png".to_string(),
        Some("jpg") | Some("jpeg") => "image/jpeg".to_string(),
        Some("gif") => "image/gif".to_string(),
        Some("svg") => "image/svg+xml".to_string(),
        Some("pdf") => "application/pdf".to_string(),
        Some("woff2") => "font/woff2".to_string(),
        Some("woff") => "font/woff".to_string(),
        _ => "application/octet-stream".to_string(),
    }
}
