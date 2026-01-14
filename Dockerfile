FROM rust:1.75-slim as builder
WORKDIR /usr/src/app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/src/app/target/release/rusty-bandwidth /usr/local/bin/proxy
CMD ["sh", "-c", "proxy --port ${PORT:-8080}"]
