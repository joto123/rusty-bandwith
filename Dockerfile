# ---------- BUILDER ----------
FROM golang:1.21-alpine3.18 AS builder

# Системни нужди за bimg на Alpine
RUN apk add --no-cache vips-dev build-base pkgconfig git

WORKDIR /app
COPY . .
RUN go mod tidy && go mod download

# Компилираме с флаг за премахване на тежките символи (-s -w)
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o proxy main.go

# ---------- RUNTIME ----------
FROM alpine:3.18

# Инсталираме само runtime библиотеките (WebP, HEIF, JPEG-Turbo)
RUN apk add --no-cache \
    vips \
    ca-certificates \
    libwebp \
    libheif \
    libjpeg-turbo \
    libpng

WORKDIR /root/
COPY --from=builder /app/proxy .

# Ограничаваме Go да не се разширява в паметта излишно
ENV GOMAXPROCS=1
ENV MALLOC_ARENA_MAX=2

EXPOSE 8080
ENTRYPOINT ["./proxy"]