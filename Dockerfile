FROM golang:1.21-alpine AS builder

# Инсталиране на необходимите библиотеки за компилация
RUN apk add --no-cache vips-dev build-base git

WORKDIR /app

# Копираме модулните файлове
COPY go.mod ./
# Ако имаш go.sum, го копираме, ако ли не - ще се създаде
COPY go.sum* ./

# ТАЗИ КОМАНДА ОПРАВЯ ГРЕШКАТА: 
# Тя автоматично изтегля зависимостите и генерира правилен go.sum
RUN go mod tidy

# Копираме останалия код
COPY . .

# Компилираме с активиран CGO за bimg (vips)
RUN CGO_ENABLED=1 GOOS=linux go build -o proxy main.go

# Финално леко изображение
FROM alpine:3.18
# Инсталираме само runtime библиотеките
RUN apk add --no-cache vips ca-certificates

WORKDIR /root/
COPY --from=builder /app/proxy .

EXPOSE 8080

CMD ["./proxy"]