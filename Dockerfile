# Етап на компрометиране (Build)
FROM golang:1.21-alpine AS builder
RUN apk add --no-cache git
RUN go install github.com/mccutchen/compy/cmd/compy@latest

# Финален имидж
FROM alpine:latest
RUN apk add --no-cache ca-certificates
COPY --from=builder /go/bin/compy /usr/bin/compy

# Портът за Koyeb
ENV PORT=8080
EXPOSE 8080

# Стартираме compy с оптимизации за снимки (jpeg и webp качество 50%)
CMD ["compy", "-host", "0.0.0.0", "-port", "8080", "-jpeg", "50", "-gif", "50", "-gzip"]