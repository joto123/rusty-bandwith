# Етап 1: Компилация (Builder)
FROM rust:1.75-bookworm AS builder

# Инсталиране на необходимите инструменти за компилация
# reqwest-impersonate често изисква cmake и clang за изграждане на бордовите TLS библиотеки
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    clang \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# Копираме Cargo файловете първо за кеширане на слоевете
COPY Cargo.toml ./
# Създаваме празен main.rs, за да изтеглим и компилираме само зависимостите
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -f target/release/deps/rusty_bandwidth*

# Сега копираме истинския код и компилираме
COPY . .
RUN cargo build --release

# Етап 2: Лек образ за работа (Runtime)
FROM debian:bookworm-slim

# Инсталираме ca-certificates (задължително за HTTPS заявки) и OpenSSL
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Копираме бинарния файл от builder-а
COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/

# Настройки на средата
ENV PORT=8080
EXPOSE 8080

# Стартиране
CMD ["rusty-bandwidth"]