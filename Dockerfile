FROM golang:1.21-alpine AS builder

# Инсталиране на библиотеки за обработка на изображения
RUN apk add --no-cache vips-dev build-base

WORKDIR /app
COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -o proxy main.go

FROM alpine:3.18
RUN apk add --no-cache vips ca-certificates

WORKDIR /root/
COPY --from=builder /app/proxy .

EXPOSE 8080
CMD ["./proxy"]