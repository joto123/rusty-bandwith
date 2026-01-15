use axum::{
    extract::Query,
    http::{header, StatusCode, HeaderMap},
    response::IntoResponse,
    routing::get,
    Router,
};
use tower_http::cors::{Any, CorsLayer};
use clap::Parser;
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
    
    // Глобална настройка на CORS за целия сървър
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/", get(proxy_handler))
        .layer(cors);

    let addr = SocketAddr::from(([0, 0, 0, 0], args.port));
    println!("🚀 Ultra Stealth Proxy v2.5 running on http://{}", addr);
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn proxy_handler(Query(query): Query<ProxyQuery>) -> impl IntoResponse {
    let client = Client::new();

    let res = match client.get(&query.url)
        .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .header("Referer", "https://twitter.com/")
        .send().await {
            Ok(r) => r,
            Err(_) => return (StatusCode::BAD_REQUEST, "Fetch error").into_response(),
        };

    let bytes_data = match res.bytes().await {
        Ok(b) => b.to_vec(),
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Bytes error").into_response(),
    };

    let img = match image::load_from_memory(&bytes_data) {
        Ok(i) => i,
        Err(_) => {
            return ([(header::CONTENT_TYPE, "image/jpeg")], bytes_data).into_response();
        }
    };

    let mut webp_buffer = Vec::new();
    let mut cursor = Cursor::new(&mut webp_buffer);
    
    match img.write_to(&mut cursor, image::ImageFormat::WebP) {
        Ok(_) => {
            let mut headers = HeaderMap::new();
            headers.insert(header::CONTENT_TYPE, "image/webp".parse().unwrap());
            headers.insert(header::CACHE_CONTROL, "public, max-age=31536000".parse().unwrap());
            (headers, webp_buffer).into_response()
        },
        Err(_) => {
            ([(header::CONTENT_TYPE, "image/jpeg")], bytes_data).into_response()
        }
    }
}