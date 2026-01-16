FROM golang:1.21-alpine AS builder

# 1. Инсталираме системните зависимости за компилиране на bimg/vips
RUN apk add --no-cache \
    vips-dev \
    build-base \
    git \
    expat-dev \
    libwebp-dev \
    libheif-dev \
    libjpeg-turbo-dev \
    libpng-dev

WORKDIR /app

# 2. Копираме файловете на проекта
COPY go.mod ./
COPY go.sum* ./
COPY . .

# 3. Актуализираме и изтегляме Go зависимостите
# Това ще добави липсващия github.com/h2non/bimg в go.sum
RUN go mod tidy
RUN go mod download

# 4. Компилираме приложението
RUN CGO_ENABLED=1 GOOS=linux go build -o proxy main.go

# 5. Финално леко изображение (Runtime)
FROM alpine:3.18

# Инсталираме само библиотеките, нужни за работата на приложението
RUN apk add --no-cache \
    vips \
    libwebp \
    libheif \
    libjpeg-turbo \
    libpng \
    ca-certificates

WORKDIR /root/
COPY --from=builder /app/proxy .

# Експортираме порта (Koyeb по подразбиране търси 8080)
EXPOSE 8080

CMD ["./proxy"]