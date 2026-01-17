# ---------- BUILDER ----------
FROM golang:1.21-bookworm AS builder

# Install build dependencies
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

# Copy only go.mod first for caching
COPY go.mod ./
RUN go mod tidy

# Copy the rest of the source
COPY . .

# Build binary (stripped, smaller)
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o proxy main.go


# ---------- RUNTIME ----------
FROM debian:bookworm-slim

# Install only runtime libs (much smaller)
RUN apt-get update && apt-get install -y \
    libvips \
    libwebp7 \
    libheif1 \
    libjpeg62-turbo \
    libpng16-16 \
    ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /root/

# Copy binary only (no source code)
COPY --from=builder /app/proxy .

EXPOSE 8080

CMD ["./proxy"]
