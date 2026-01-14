# Използваме пълен образ за компилация, за да избегнем липсващи инструменти
FROM rust:1.75-bookworm as builder

# Инсталираме основните инструменти за компилация на зависимостите
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app
COPY . .

# Компилираме. Ако тук даде грешка, значи има проблем в main.rs
RUN cargo build --release

# Втори етап: Лек образ за работа
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# ВНИМАНИЕ: Провери името на binary-то да е точно като в Cargo.toml
COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/proxy

EXPOSE 8080
CMD ["sh", "-c", "proxy --port ${PORT:-8080}"]
