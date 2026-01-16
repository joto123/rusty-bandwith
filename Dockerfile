# Етап 1: Компилиране на оригиналния Compy
FROM golang:1.23-bookworm AS builder

# Инсталираме зависимости за работа с изображения (важно за функциите на Compy)
RUN apt-get update && apt-get install -y libjpeg-dev libpng-dev

# Изтегляме оригиналния код
RUN git clone https://github.com/andrewgaul/compy.git /app
WORKDIR /app

# Компилираме
RUN go build -o compy .

# Етап 2: Олекотено финално изображение
FROM debian:bookworm-slim

# Инсталираме библиотеките, необходими за компресията в движение
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libjpeg62-turbo \
    libpng16-16 \
    && rm -rf /var/lib/apt/lists/*

# Копираме компилираното прокси
COPY --from=builder /app/compy /usr/local/bin/compy

# Настройки за Koyeb
# Compy функции: -gzip (компресия), -jpeg-quality (оптимизация)
ENV PORT=8080
EXPOSE 8080

# Стартираме с флаговете, които правят Compy това, което е
CMD ["sh", "-c", "compy -http-addr :$PORT -gzip -jpeg-quality 70"]