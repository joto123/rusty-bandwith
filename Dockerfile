# Етап 1: Компилация
FROM rust:latest AS builder
WORKDIR /usr/src/app

# Инсталиране на системни зависимости за OpenSSL и Image обработка
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY . .
RUN cargo build --release

# Етап 2: Лек образ за работа
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/

ENV PORT=8080
EXPOSE 8080

CMD ["rusty-bandwidth"]
