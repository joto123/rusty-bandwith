FROM golang:1.21-alpine AS builder

# Инсталиране на необходими зависимости
RUN apk add --no-cache git

WORKDIR /app
# Клонираме оригиналния код на Janifr
RUN git clone https://github.com/janifr/bandwidth-hero-proxy.git .

# Компилиране на приложението
RUN go build -o proxy main.go

# Финално изображение
FROM alpine:latest
RUN apk add --no-cache ca-certificates libc6-compat
WORKDIR /root/
COPY --from=builder /app/proxy .

# Портът, на който Koyeb ще слуша
EXPOSE 8080

CMD ["./proxy"]