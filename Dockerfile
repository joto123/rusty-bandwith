FROM golang:1.21-alpine AS builder

# Инсталираме всички нужни библиотеки за обработка на изображения
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
COPY go.mod ./
COPY go.sum* ./
COPY . .

RUN go mod download
RUN CGO_ENABLED=1 GOOS=linux go build -o proxy main.go

FROM alpine:3.18
# Инсталираме runtime библиотеките
RUN apk add --no-cache vips libwebp libheif libjpeg-turbo libpng ca-certificates

WORKDIR /root/
COPY --from=builder /app/proxy .

EXPOSE 8080
CMD ["./proxy"]