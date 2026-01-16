# --- Етап 1: Builder ---
FROM rust:1.75-bookworm AS builder

# Инсталиране на зависимости за компилиране (reqwest-impersonate изисква тези за BoringSSL)
RUN apt-get update && apt-get install -y \
    cmake \
    clang \
    pkg-config \
    libssl-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Конфигурация за стабилен билд в облачна среда
ENV CC=clang
ENV CXX=clang++
ENV AR=llvm-ar
ENV CARGO_HTTP_MULTIPLEXING=false
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

WORKDIR /usr/src/app

# Копираме Cargo.toml
COPY Cargo.toml ./

# Създаваме празен проект за кеширане на библиотеките
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src/

# Копираме истинския код
COPY . .

# Финален билд на приложението
RUN touch src/main.rs && cargo build --release

# --- Етап 2: Runtime (Минимален размер) ---
FROM debian:bookworm-slim

# Инсталираме само runtime нужните пакети
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Копираме изпълнимия файл от builder етапа
COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/

# Koyeb използва порта от променливата PORT
ENV PORT=8080
EXPOSE 8080

CMD ["rusty-bandwidth"]