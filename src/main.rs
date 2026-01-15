use axum::{
    extract::{Query, State},
    http::{header, HeaderMap, StatusCode},
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
use std::sync::Arc;

#[derive(Parser )]
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
    
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Създаваме клиента веднъж и го споделяме чрез Arc, за да е по-ефективно.
    let client = Arc::new(Client::new());

    let app = Router::new()
        .route("/", get(proxy_handler))
        .with_state(client) // Подаваме клиента като състояние на рутера.
        .layer(cors);

    let addr = SocketAddr::from(([0, 0, 0, 0], args.port));
    println!("🚀 Ultra Stealth Proxy v2.6 running on http://{}", addr );
    
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn proxy_handler(
    Query(query): Query<ProxyQuery>,
    State(client): State<Arc<Client>>, // Получаваме клиента от състоянието.
    in_headers: HeaderMap, // Получаваме хедърите от входящата заявка.
) -> impl IntoResponse {
    
    // Препращаме повечето хедъри, за да имитираме оригиналната заявка.
    let mut out_headers = HeaderMap::new();
    for (name, value) in in_headers.iter() {
        // Филтрираме хедъри, които не трябва да се препращат директно (напр. Host).
        if name != header::HOST {
            out_headers.insert(name.clone(), value.clone());
        }
    }

    // Гарантираме, че имаме User-Agent и Referer, които са важни за сайтове като Twitter.
    if !out_headers.contains_key(header::USER_AGENT) {
        out_headers.insert(header::USER_AGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".parse().unwrap());
    }
    out_headers.insert(header::REFERER, "https://twitter.com/".parse( ).unwrap());


    let res = match client.get(&query.url)
        .headers(out_headers)
        .send().await {
            Ok(r) => r,
            Err(e) => {
                eprintln!("Fetch error for URL {}: {}", query.url, e);
                return (StatusCode::BAD_REQUEST, "Fetch error").into_response();
            },
        };

    // Проверяваме дали отговорът е успешен.
    if !res.status().is_success() {
        eprintln!("Upstream server returned status {} for URL {}", res.status(), query.url);
        return (res.status(), "Upstream server error").into_response();
    }

    // Проверяваме Content-Type, преди да опитаме да обработим изображението.
    let content_type = res.headers()
        .get(header::CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .unwrap_or("")
        .to_string();

    let bytes_data = match res.bytes().await {
        Ok(b) => b.to_vec(),
        Err(_) => return (StatusCode::INTERNAL_SERVER_ERROR, "Bytes error").into_response(),
    };

    // Ако съдържанието не е изображение, просто го връщаме без обработка.
    if !content_type.starts_with("image/") {
        let mut headers = HeaderMap::new();
        headers.insert(header::CONTENT_TYPE, content_type.parse().unwrap_or("application/octet-stream".parse().unwrap()));
        return (headers, bytes_data).into_response();
    }

    // Опитваме да заредим изображението.
    let img = match image::load_from_memory(&bytes_data) {
        Ok(i) => i,
        Err(_) => {
            // Ако не успеем, връщаме оригиналните байтове с оригиналния content-type.
            let mut headers = HeaderMap::new();
            headers.insert(header::CONTENT_TYPE, content_type.parse().unwrap());
            return (headers, bytes_data).into_response();
        }
    };

    // Конвертираме към WebP.
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
            // Ако конверсията се провали, връщаме оригиналното изображение.
            let mut headers = HeaderMap::new();
            headers.insert(header::CONTENT_TYPE, content_type.parse().unwrap());
            (headers, bytes_data).into_response()
        }
    }
}
