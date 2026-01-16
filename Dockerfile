# Етап 1: Компилиране (използваме последната стабилна версия на Go)
FROM golang:1.23-alpine AS builder

# Инсталираме git за изтегляне на зависимостите
RUN apk add --no-cache git

# Изтегляме и компилираме проксито директно
RUN go install github.com/yigitkonur/go-native-squid-proxy/cmd/proxy@latest

# Етап 2: Финално олекотено изображение
FROM alpine:latest

# Копираме само компилираното бинарно файлче
COPY --from=builder /go/bin/proxy /usr/local/bin/proxy

# Koyeb изисква порт 8080
ENV PORT=8080
EXPOSE 8080

# Стартираме проксито, като му казваме да слуша на порта от Koyeb
# Забележка: -addr :8080 казва на проксито да слуша на всички интерфейси
CMD ["proxy", "-addr", ":8080"]