# Stage 1: Build
FROM rust:1.75-slim-bookworm as builder

# Инсталираме нужните системни библиотеки за компилация
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app
COPY . .

# Компилираме проекта
RUN cargo build --release

# Stage 2: Run
FROM debian:bookworm-slim

# Инсталираме сертификати, за да може проксито да отваря HTTPS сайтове
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Копираме изпълнимия файл (увери се, че името съвпада с Cargo.toml)
COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/proxy

# Koyeb подава порта динамично
CMD ["sh", "-c", "proxy --port ${PORT:-8080}"]
