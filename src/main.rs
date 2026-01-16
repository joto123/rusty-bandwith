use axum::{
    extract::{Query, HeaderMap},
    response::IntoResponse,
    routing::get,
    Router,
};
use image::{DynamicImage, ImageOutputFormat};
use serde::Deserialize;
use std::io::Cursor;

#[derive(Deserialize)]
struct ImageParams {
    url: String,
}

async fn handle_proxy(headers: HeaderMap, Query(params): Query<ImageParams>) -> impl IntoResponse {
    // 1. Създаваме клиент (използваме стандартен reqwest)
    let client = reqwest::Client::new();
    
    // 2. Изтегляме оригиналното изображение
    let resp = match client.get(&params.url).send().await {
        Ok(res) => res.bytes().await.unwrap_or_default(),
        Err(_) => return "Грешка при теглене".into_response(),
    };

    // 3. Зареждаме изображението в паметта
    let img = match image::load_from_memory(&resp) {
        Ok(i) => i,
        Err(_) => return "Невалиден формат на изображението".into_response(),
    };

    // 4. Логика за автоматично оразмеряване
    let user_agent = headers.get("user-agent")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");

    let target_width = if user_agent.contains("Mobile") || user_agent.contains("Android") || user_agent.contains("iPhone") {
        600 // За мобилни устройства
    } else {
        1200 // За десктоп
    };

    // Оразмеряваме само ако оригиналът е по-голям от целта
    let resized_img = if img.width() > target_width {
        img.resize(target_width, 10000, image::imageops::FilterType::Lanczos3)
    } else {
        img
    };

    // 5. Конвертиране в WebP
    let mut buffer = Cursor::new(Vec::new());
    match resized_img.write_to(&mut buffer, ImageOutputFormat::WebP) {
        Ok(_) => (),
        Err(_) => return "Грешка при конвертиране".into_response(),
    };

    // 6. Връщане на готовото WebP изображение
    (
        [("content-type", "image/webp")],
        buffer.into_inner()
    ).into_response()
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/proxy", get(handle_proxy));

    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{}", port);

    println!("Сървърът стартира на {}", addr);
    axum::Server::bind(&addr.parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}