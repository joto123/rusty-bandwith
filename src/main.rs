use clap::{Parser, ValueHint};
use hyper::{Body, Request, Response, Server, StatusCode, header};
use hyper::service::{make_service_fn, service_fn};
use std::net::SocketAddr;
use percent_encoding::percent_decode_str;
use image::{DynamicImage, ImageBuffer, Rgba, GenericImageView};
use std::sync::Arc;
use jpegxl_rs::{encoder_builder, encode::EncoderSpeed, encode::EncoderResult};
use std::path::Path;
use reqwest::Client;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long, env = "PORT", default_value_t = 8080)]
    port: u16,

    #[arg(long, env = "USE_JXL", default_value_t = false)]
    jxl: bool,

    #[arg(long, default_value_t = 8)]
    speed: u8,
}

struct ImageParams {
    url: String,
    quality: u8,
    grayscale: bool,
}

struct AppConfig {
    use_jxl: bool,
    encoder_speed: EncoderSpeed,
    client: Client, // Споделен клиент за HTTP заявки
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let args = Args::parse();
    
    let speed = match args.speed {
        1 => EncoderSpeed::Lightning,
        2 => EncoderSpeed::Thunder,
        3 => EncoderSpeed::Falcon,
        4 => EncoderSpeed::Cheetah,
        5 => EncoderSpeed::Hare,
        6 => EncoderSpeed::Wombat,
        7 => EncoderSpeed::Squirrel,
        _ => EncoderSpeed::Tortoise,
    };

    // Създаваме клиент с поддръжка на компресия и времеви лимити
    let client = Client::builder()
        .user_agent("Bandwidth-Hero-Rust-Proxy/1.0")
        .build()?;

    let config = Arc::new(AppConfig {
        use_jxl: args.jxl,
        encoder_speed: speed,
        client,
    });

    // ВАЖНО: Слушаме на 0.0.0.0 за Koyeb/Docker
    let addr = SocketAddr::from(([0, 0, 0, 0], args.port));

    println!("Server running on http://{}", addr);

    let make_svc = make_service_fn(move |_conn| {
        let config = config.clone();
        async move {
            Ok::<_, hyper::Error>(service_fn(move |req| handle_request(req, config.clone())))
        }
    });

    let server = Server::bind(&addr).serve(make_svc);
    server.await?;
    Ok(())
}
// Помощна функция за обработка на query параметрите
fn parse_query(query: &str) -> ImageParams {
    let mut image_params = ImageParams {
        url: String::new(),
        quality: 80,
        grayscale: true,
    };

    for pair in query.split('&') {
        let mut parts = pair.splitn(2, '=');
        match (parts.next(), parts.next()) {
            (Some("url"), Some(v)) => image_params.url = percent_decode_str(v).decode_utf8_lossy().to_string(),
            (Some("l"), Some(v)) => image_params.quality = v.parse().unwrap_or(80).min(100),
            (Some("bw"), Some(v)) => image_params.grayscale = v != "0",
            _ => {}
        }
    }
    image_params
}

// Главният манипулатор на заявки
async fn handle_request(req: Request<Body>, config: Arc<AppConfig>) -> Result<Response<Body>, hyper::Error> {
    // 1. Проверка за здраве (Health Check) за Bandwidth Hero екстеншъна
    if req.uri().path() == "/" && req.uri().query().is_none() {
        return Ok(Response::builder()
            .status(StatusCode::OK)
            .body(Body::from("bandwidth-hero-proxy"))
            .unwrap());
    }

    // 2. Извличане на параметрите
    let query = req.uri().query().unwrap_or("");
    let params = parse_query(query);

    if params.url.is_empty() {
        return Ok(Response::builder().status(StatusCode::BAD_REQUEST).body(Body::from("Missing URL")).unwrap());
    }

    // 3. Подготовка на прокси заявката с прехвърляне на хедъри
    let mut proxy_req = config.client.get(&params.url);

    // Прехвърляме важните хедъри от браузъра към оригиналния сървър
    for (key, value) in req.headers().iter() {
        let key_s = key.as_str().to_lowercase();
        // Пропускаме хедъри, които биха объркали проксито (hop-by-hop)
        if key_s != "host" && key_s != "connection" && !key_s.starts_with("proxy-") {
            proxy_req = proxy_req.header(key, value);
        }
    }

    // 4. Изпълнение на заявката
    let response = match proxy_req.send().await {
        Ok(res) => res,
        Err(e) => {
            return Ok(Response::builder()
                .status(StatusCode::BAD_GATEWAY)
                .body(Body::from(format!("Fetch error: {}", e)))
                .unwrap());
        }
    };

    // Проверка на статуса
    if !response.status().is_success() {
        return Ok(Response::builder()
            .status(response.status())
            .body(Body::from("Remote server error"))
            .unwrap());
    }

    // Вземаме байтовете на изображението
    let bytes = match response.bytes().await {
        Ok(b) => b,
        Err(_) => return Ok(Response::builder().status(500).body(Body::from("Data error")).unwrap()),
    };

    // Продължаваме към Част 3: Обработка на изображението...
	// 5. Декодиране и обработка на изображението
    let mut img = match image::load_from_memory(&bytes) {
        Ok(img) => img,
        Err(_) => {
            // Ако не е изображение (напр. грешка или HTML), връщаме оригиналните байтове
            return Ok(Response::builder()
                .status(StatusCode::OK)
                .body(Body::from(bytes.to_vec()))
                .unwrap());
        }
    };

    // Конвертиране в Grayscale, ако е поискано
    if params.grayscale {
        img = convert_to_grayscale_optimized(&img);
    }

    // 6. Компресия и изпращане
    let (body, content_type) = if config.use_jxl {
        let jxl_quality = if params.quality >= 95 { 0.0 } else { 8.0 * (1.0 - (params.quality as f32 / 100.0).powf(0.7)) };
        let mut encoder = encoder_builder().speed(config.encoder_speed).build().unwrap();
        encoder.quality = jxl_quality;
        encoder.lossless = params.quality >= 95;
        
        let rgb = img.to_rgb8();
        let encoded = encoder.encode(&rgb.into_raw(), img.width(), img.height()).unwrap();
        (encoded.data, "image/jxl")
    } else {
        let webp_encoder = webp::Encoder::from_image(&img).unwrap();
        let webp_image = webp_encoder.encode(params.quality as f32);
        (webp_image.to_vec(), "image/webp")
    };

    // 7. Връщане на резултата с кеширащи хедъри
    Ok(Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, content_type)
        // Казваме на браузъра да кешира изображението за 1 седмица
        .header(header::CACHE_CONTROL, "public, max-age=604800")
        // Премахваме хедъри, които биха попречили на кеширането
        .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
        .body(Body::from(body))
        .unwrap())
}

// Помощната функция за Grayscale (от твоя оригинален код)
fn convert_to_grayscale_optimized(img: &DynamicImage) -> DynamicImage {
    let (width, height) = img.dimensions();
    let rgba_img = img.to_rgba8();
    let mut output = ImageBuffer::new(width, height);
    for (x, y, pixel) in rgba_img.enumerate_pixels() {
        let luma = ((pixel[0] as u32 * 299 + pixel[1] as u32 * 587 + pixel[2] as u32 * 114) / 1000) as u8;
        output.put_pixel(x, y, Rgba([luma, luma, luma, pixel[3]]));
    }
    DynamicImage::ImageRgba8(output)
}
