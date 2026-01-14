use clap::Parser;
use hyper::{Body, Request, Response, Server, StatusCode, header};
use hyper::service::{make_service_fn, service_fn};
use std::net::SocketAddr;
use percent_encoding::percent_decode_str;
use image::{DynamicImage, ImageBuffer, Rgba, GenericImageView};
use std::sync::Arc;
use reqwest::Client;

#[derive(Parser, Debug)]
struct Args {
    #[arg(short, long, env = "PORT", default_value_t = 8080)]
    port: u16,
}

struct ImageParams {
    url: String,
    quality: u8,
    grayscale: bool,
}

struct AppConfig {
    client: Client,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let args = Args::parse();
    let client = Client::builder()
        .user_agent("Bandwidth-Hero-Rust-Proxy/1.0")
        .build()?;

    let config = Arc::new(AppConfig { client });
    let addr = SocketAddr::from(([0, 0, 0, 0], args.port));

    println!("WebP Compression Server running on http://{}", addr);

    let make_svc = make_service_fn(move |_conn| {
        let config = config.clone();
        async move {
            Ok::<_, hyper::Error>(service_fn(move |req| handle_request(req, config.clone())))
        }
    });

    Server::bind(&addr).serve(make_svc).await?;
    Ok(())
}

async fn handle_request(req: Request<Body>, config: Arc<AppConfig>) -> Result<Response<Body>, hyper::Error> {
    if req.uri().path() == "/" && req.uri().query().is_none() {
        return Ok(Response::builder().body(Body::from("bandwidth-hero-proxy")).unwrap());
    }

    let query = req.uri().query().unwrap_or("");
    let params = parse_query(query);
    if params.url.is_empty() {
        return Ok(Response::builder().status(400).body(Body::from("Missing URL")).unwrap());
    }

    // Проксиране на заявката
    let mut proxy_req = config.client.get(&params.url);
    for (key, value) in req.headers().iter() {
        let key_s = key.as_str().to_lowercase();
        if key_s != "host" && key_s != "connection" {
            proxy_req = proxy_req.header(key, value);
        }
    }

    let response = match proxy_req.send().await {
        Ok(res) => res,
        Err(_) => return Ok(Response::builder().status(502).body(Body::from("Fetch error")).unwrap()),
    };

    let bytes = match response.bytes().await {
        Ok(b) => b,
        Err(_) => return Ok(Response::builder().status(500).body(Body::from("Data error")).unwrap()),
    };

    let mut img = match image::load_from_memory(&bytes) {
        Ok(img) => img,
        Err(_) => return Ok(Response::builder().body(Body::from(bytes.to_vec())).unwrap()),
    };

    if params.grayscale {
        img = convert_to_grayscale(&img);
    }

    // САМО WebP компресия
    let webp_encoder = webp::Encoder::from_image(&img).unwrap();
    let webp_image = webp_encoder.encode(params.quality as f32);

    Ok(Response::builder()
        .header(header::CONTENT_TYPE, "image/webp")
        .header(header::CACHE_CONTROL, "public, max-age=604800")
        .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
        .body(Body::from(webp_image.to_vec()))
        .unwrap())
}

fn parse_query(query: &str) -> ImageParams {
    let mut params = ImageParams { url: String::new(), quality: 80, grayscale: false };
    for pair in query.split('&') {
        let mut parts = pair.splitn(2, '=');
        match (parts.next(), parts.next()) {
            (Some("url"), Some(v)) => params.url = percent_decode_str(v).decode_utf8_lossy().to_string(),
            (Some("l"), Some(v)) => params.quality = v.parse().unwrap_or(80),
            (Some("bw"), Some(v)) => params.grayscale = v == "1",
            _ => {}
        }
    }
    params
}

fn convert_to_grayscale(img: &DynamicImage) -> DynamicImage {
    let (width, height) = img.dimensions();
    let mut output = ImageBuffer::new(width, height);
    for (x, y, pixel) in img.to_rgba8().enumerate_pixels() {
        let luma = ((pixel[0] as u32 * 299 + pixel[1] as u32 * 587 + pixel[2] as u32 * 114) / 1000) as u8;
        output.put_pixel(x, y, Rgba([luma, luma, luma, pixel[3]]));
    }
    DynamicImage::ImageRgba8(output)
}
