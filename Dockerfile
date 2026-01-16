# --- Етап 1: Builder ---
FROM rust:1.75-bookworm AS builder

# Инсталиране на зависимости за BoringSSL (нужни за reqwest-impersonate)
RUN apt-get update && apt-get install -y \
    cmake \
    clang \
    pkg-config \
    libssl-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Променливи за стабилна компилация на BoringSSL
ENV CC=clang
ENV CXX=clang++
ENV AR=llvm-ar

WORKDIR /usr/src/app

# 1. Копираме Cargo.toml за кеширане на зависимостите
COPY Cargo.toml ./

# 2. Създаваме празен проект и компилираме само библиотеките
# Това спестява огромно количество време при последващи билдове
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src/

# 3. Копираме реалния сорс код
COPY . .

# 4. Финален билд (cargo ще види промяната в main.rs и ще компилира само вашия код)
RUN touch src/main.rs && cargo build --release

# --- Етап 2: Runtime ---
FROM debian:bookworm-slim

# Инсталираме runtime библиотеки (OpenSSL е нужен за работа)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Копираме готовия изпълним файл от билдера
COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/

# Конфигурация на порта
ENV PORT=8080
EXPOSE 8080

CMD ["rusty-bandwidth"]