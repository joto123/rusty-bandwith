FROM golang:1.21-bookworm AS builder

RUN apt-get update && apt-get install -y \
    libvips-dev \
    build-essential \
    git \
    pkg-config

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=1 GOOS=linux go build -o proxy main.go


# Runtime image
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libvips \
    libwebp \
    libheif1 \
    libjpeg62-turbo \
    libpng16-16 \
    ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /root/

COPY --from=builder /app/proxy .

EXPOSE 8080

CMD ["./proxy"]
