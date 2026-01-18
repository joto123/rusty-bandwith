# ---------- BUILDER ----------
FROM golang:1.21-bookworm AS builder

RUN apt-get update && apt-get install -y \
    libvips-dev \
    libwebp-dev \
    libheif-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    build-essential \
    pkg-config \
    git

WORKDIR /app

COPY go.mod ./
# go mod tidy ще се изпълни автоматично по време на билда
COPY . .

RUN go mod tidy && go mod download
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o proxy main.go

# ---------- RUNTIME ----------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libvips \
    libwebp7 \
    libheif1 \
    libjpeg62-turbo \
    libpng16-16 \
    ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /root/
COPY --from=builder /app/proxy .

EXPOSE 8080
CMD ["./proxy"]