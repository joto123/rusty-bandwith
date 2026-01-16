FROM golang:1.21-alpine AS builder

# Инсталиране на необходимите библиотеки за компилация
RUN apk add --no-cache vips-dev build-base git

WORKDIR /app

# 1. Копираме първо модулните файлове
COPY go.mod ./
COPY go.sum* ./

# 2. Копираме целия код СЕГА (за да може Go да види main.go)
COPY . .

# 3. ТАЗИ КОМАНДА ЩЕ ДОБАВИ ЛИПСВАЩИТЕ СУМИ:
RUN go mod download github.com/h2non/bimg
RUN go mod tidy

# 4. Компилираме
RUN CGO_ENABLED=1 GOOS=linux go build -o proxy main.go

# Финално леко изображение
FROM alpine:3.18
RUN apk add --no-cache vips ca-certificates

WORKDIR /root/
COPY --from=builder /app/proxy .

EXPOSE 8080

CMD ["./proxy"]