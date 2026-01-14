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
    
    println!("WebP Proxy with Stealth Mode running on {}", addr);
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn proxy_handler(Query(query): Query<ProxyQuery>) -> impl IntoResponse {
    // Създаваме клиент, който имитира истински браузър
    let client = Client::builder()
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .build()
        .unwrap_or_default();

    // Опит за изтегляне на оригиналното изображение
    let res = match client
        .get(&query.url)
        .header("Referer", "https://www.google.com/") // Помага при защити срещу hotlinking
        .send()
        .await 
    {
        Ok(res) => res,
        Err(_) => return (StatusCode::BAD_REQUEST, "Failed to fetch image").into_response(),
    };

    if !res.status().is_success() {
        return (StatusCode::BAD_GATEWAY, "Origin server returned an error").into_response();
    }

    let bytes = match res.bytes().await {
        Ok(b) => b,
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to read image bytes").into_response(),
    };

    // Декодиране и компресиране
    let img = match image::load_from_memory(&bytes) {
        Ok(i) => i,
        Err(_) => return (StatusCode::BAD_REQUEST, "Invalid image format").into_response(),
    };

    let mut webp_data = Cursor::new(Vec::new());
    
    // Превръщане в WebP
    match DynamicImage::ImageRgba8(img.to_rgba8()).write_to(&mut webp_data, ImageOutputFormat::WebP) {
        Ok(_) => (),
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Failed to encode WebP").into_response(),
    };

    let mut headers = HeaderMap::new();
    headers.insert(header::CONTENT_TYPE, "image/webp".parse().unwrap());
    headers.insert(header::CACHE_CONTROL, "public, max-age=31536000".parse().unwrap());

    (headers, webp_data.into_inner()).into_response()
}
