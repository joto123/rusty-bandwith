# --- Етап 1: Builder ---
FROM rust:1.75-bookworm AS builder

# Инсталиране на критичните системни зависимости за BoringSSL/reqwest-impersonate
RUN apt-get update && apt-get install -y \
    cmake \
    clang \
    pkg-config \
    libssl-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# Копираме Cargo.toml за кеширане
COPY Cargo.toml ./

# Създаваме "fake" проект, за да компилираме само зависимостите (спестява много време)
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src/

# Сега копираме истинския код
COPY . .

# Актуализираме времето на main.rs, за да форсираме нов билд върху кешираните зависимости
RUN touch src/main.rs && cargo build --release

# --- Етап 2: Runtime ---
FROM debian:bookworm-slim

# Инсталираме само нужните неща за работа (runtime)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Копираме готовия бинарен файл
COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/

# Порт по подразбиране
ENV PORT=8080
EXPOSE 8080

# Стартираме
CMD ["rusty-bandwidth"]