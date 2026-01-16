FROM debian:bookworm-slim

# Инсталираме ziproxy
RUN apt-get update && apt-get install -y ziproxy && rm -rf /var/lib/apt/lists/*

# Настройваме порта на 8080 за Koyeb
RUN sed -i 's/Port = 8080/Port = 8080/' /etc/ziproxy/ziproxy.conf && \
    sed -i 's/Address = "127.0.0.1"/Address = "0.0.0.0"/' /etc/ziproxy/ziproxy.conf

EXPOSE 8080

CMD ["ziproxy", "-d"]