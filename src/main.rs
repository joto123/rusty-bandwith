use axum::{
    extract::Query,
    http::{header, StatusCode, HeaderMap},
    response::IntoResponse,
    routing::get,
    Router,
};
use clap::Parser;
use image::DynamicImage;
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
    
    println!("Ultra Stealth Proxy running on {}", addr);
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn proxy_handler(Query(query): Query<ProxyQuery>) -> impl IntoResponse {
    let client = Client::builder()
        .gzip(true)
        .build()
        .unwrap_or_default();

    // Симулираме заявка от Chrome за изображение
    let res = match client.get(&query.url)
        .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .header("Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8")
        .header("Accept-Language", "bg-BG,bg;q=0.9,en;q=0.8")
        .header("Referer", "https://twitter.com/")
        // ДОБАВЯМЕ SEC-FETCH ХЕДЪРИ
        .header("Sec-Fetch-Dest", "image")
        .header("Sec-Fetch-Mode", "no-cors")
        .header("Sec-Fetch-Site", "cross-site")
        .header("Sec-Ch-Ua", "\"Not_A Brand\";v=\"8\", \"Chromium\";v=\"120\", \"Google Chrome\";v=\"120\"")
        .header("Sec-Ch-Ua-Mobile", "?0")
        .header("Sec-Ch-Ua-Platform", "\"Windows\"")
        .send().await {
            Ok(res) => res,
            Err(_) => return (StatusCode::BAD_REQUEST, "Fetch error").into_response(),
        };

    let bytes = match res.bytes().await {
        Ok(b) => b,
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Bytes error").into_response(),
    };

    let img = match image::load_from_memory(&bytes) {
        Ok(i) => i,
        Err(_) => {
            // Връщаме оригинала, ако не можем да декодираме (напр. ако Twitter върне грешка като картинка)
            let mut headers = HeaderMap::new();
            headers.insert(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*".parse().unwrap());
            headers.insert(header::CONTENT_TYPE, "image/jpeg".parse().unwrap());
            return (headers, bytes).into_response();
        }
    };

    let mut webp_data = Cursor::new(Vec::new());
    match img.write_to(&mut webp_data, image::ImageFormat::WebP) {
        Ok(_) => {
            let mut headers = HeaderMap::new();
            headers.insert(header::CONTENT_TYPE, "image/webp".parse().unwrap());
            headers.insert(header::CACHE_CONTROL, "public, max-age=31536000".parse().unwrap());
            headers.insert(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*".parse().unwrap());
            (headers, webp_data.into_inner()).into_response()
        },
        Err(_) => {
            let mut headers = HeaderMap::new();
            headers.insert(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*".parse().unwrap());
            (headers, bytes).into_response()
        }
    }
}
