# Използваме най-новата версия на Rust, за да избегнем проблемите със zerovec
FROM rust:latest as builder

# Инсталираме нужните системни зависимости
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app
COPY . .

# Изпълняваме препоръката от грешката за всеки случай и компилираме
RUN cargo update && cargo build --release

# Втори етап: Лек образ за работа
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# ВНИМАНИЕ: Провери дали името съвпада с Cargo.toml (напр. rusty-bandwidth)
COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/proxy

EXPOSE 8080
CMD ["sh", "-c", "proxy --port ${PORT:-8080}"]
