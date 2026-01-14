use axum::{
    extract::Query,
    http::{header, StatusCode, HeaderMap},
    response::IntoResponse,
    routing::get,
    Router,
};
use clap::Parser;
use image::{DynamicImage, ImageOutputFormat};
use reqwest::Client;
use serde::Deserialize;
use std::io::Cursor;
use std::net::SocketAddr;

#[derive(Parser)]
struct Args {
    #[arg(short, long, env = "PORT", default_value_t = 8080)]
    port: u16,
}

#[derive(Deserialize)]
struct ProxyQuery {
    url: String,
    #[serde(default = "default_quality")]
    l: u8,
}

fn default_quality() -> u8 { 50 }

#[tokio::main]
async fn main() {
    let args = Args::parse();
    let app = Router::new().route("/", get(proxy_handler));
    let addr = SocketAddr::from(([0, 0, 0, 0], args.port));
    
    println!("WebP Proxy v2.0 (Stable) running on {}", addr);
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn proxy_handler(Query(query): Query<ProxyQuery>) -> impl IntoResponse {
    let client = Client::builder()
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .build()
        .unwrap_or_default();

    // 1. Опит за взимане на снимката
    let res = match client.get(&query.url)
        .header("Referer", "https://twitter.com/")
        .send().await {
            Ok(res) => res,
            Err(e) => {
                println!("Error fetching {}: {}", query.url, e);
                return (StatusCode::BAD_REQUEST, "Failed to fetch image").into_response();
            }
        };

    if !res.status().is_success() {
        return (StatusCode::BAD_GATEWAY, "Origin server error").into_response();
    }

    // 2. Проверка на типа данни (дали е картинка)
    let bytes = match res.bytes().await {
        Ok(b) => b,
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to read bytes").into_response(),
    };

    // 3. Декодиране
    let img = match image::load_from_memory(&bytes) {
        Ok(i) => i,
        Err(e) => {
            println!("Decoding error for {}: {}", query.url, e);
            // Ако не е картинка, просто връщаме байтовете както са (fallback)
            let mut headers = HeaderMap::new();
            headers.insert(header::CONTENT_TYPE, "image/jpeg".parse().unwrap());
            return (headers, bytes).into_response();
        }
    };

    // 4. Енкодиране към WebP (тук беше "Unimplemented" грешката)
    let mut webp_data = Cursor::new(Vec::new());
    
    // Използваме универсален метод за запис, който работи с повече версии
    match img.write_to(&mut webp_data, image::ImageFormat::WebP) {
        Ok(_) => {
            let mut headers = HeaderMap::new();
            headers.insert(header::CONTENT_TYPE, "image/webp".parse().unwrap());
            headers.insert(header::CACHE_CONTROL, "public, max-age=31536000".parse().unwrap());
            headers.insert(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*".parse().unwrap());
            (headers, webp_data.into_inner()).into_response()
        },
        Err(e) => {
            println!("WebP encoding error: {}", e);
            let mut headers = HeaderMap::new();
            headers.insert(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*".parse().unwrap());
            (headers, bytes).into_response()
        }
    }
}
