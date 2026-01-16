FROM golang:1.21-alpine AS builder

# Добавяме libheif-dev за AVIF поддръжка
RUN apk add --no-cache vips-dev build-base git expat-dev libwebp-dev libheif-dev

WORKDIR /app
COPY go.mod ./
COPY go.sum* ./
COPY . .

RUN go mod download github.com/h2non/bimg
RUN go mod tidy

RUN CGO_ENABLED=1 GOOS=linux go build -o proxy main.go

FROM alpine:3.18
# Добавяме libheif и тук за финалното изображение
RUN apk add --no-cache vips ca-certificates libwebp libheif

WORKDIR /root/
COPY --from=builder /app/proxy .

EXPOSE 8080
CMD ["./proxy"]