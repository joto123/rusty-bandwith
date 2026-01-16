# Етап 1: Компилиране на Compy
FROM golang:1.23-bookworm AS builder

# Инсталираме системни зависимости за изображения
RUN apt-get update && apt-get install -y libjpeg-dev libpng-dev git

# Клонираме оригиналния код
RUN git clone https://github.com/andrewgaul/compy.git /app
WORKDIR /app

# --- КРИТИЧНАТА КОРЕКЦИЯ ТУК ---
# Инициализираме модул и теглим зависимостите ръчно
RUN go mod init github.com/andrewgaul/compy && \
    go get github.com/dsnet/compress/bzip2 && \
    go get github.com/nfnt/resize && \
    go mod tidy && \
    go build -o compy .

# Етап 2: Финално олекотено изображение
FROM debian:bookworm-slim

# Инсталираме само нужните библиотеки за работа (Runtime)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libjpeg62-turbo \
    libpng16-16 \
    && rm -rf /var/lib/apt/lists/*

# Копираме готовия бинарен файл
COPY --from=builder /app/compy /usr/local/bin/compy

# Настройки за Koyeb
ENV PORT=8080
EXPOSE 8080

# Стартираме Compy с функциите му за компресия и оптимизация
CMD ["sh", "-c", "compy -http-addr :$PORT -gzip -jpeg-quality 70"]