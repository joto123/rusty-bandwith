# Етап 1: Компилация с оптимизирано кеширане
FROM rust:latest AS builder
WORKDIR /usr/src/app

# Инсталиране на системни зависимости за OpenSSL и Image обработка
# Тази стъпка се изпълнява рядко, затова е в началото.
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 1. Копираме само файловете за зависимостите.
# Този слой ще се кешира, докато Cargo.toml/Cargo.lock не се променят.
COPY Cargo.toml Cargo.lock ./

# 2. Създаваме празен проект и билдваме само зависимостите.
# Това е най-бавната част и ще се изпълнява само при промяна на зависимостите.
RUN mkdir src/ && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release

# 3. Сега копираме целия сорс код.
# Промените в кода ще анулират кеша само оттук нататък.
COPY src ./src

# 4. Компилираме отново.
# Този път cargo ще преизползва вече компилираните зависимости и ще компилира само нашия код, което е много по-бързо.
# Използваме `touch` за да сме сигурни, че промените се засичат.
RUN touch src/main.rs && cargo build --release

# Етап 2: Лек образ за работа (без промени тук)
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Копираме компилирания файл от builder етапа.
COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/

ENV PORT=8080
EXPOSE 8080

CMD ["rusty-bandwidth"]
