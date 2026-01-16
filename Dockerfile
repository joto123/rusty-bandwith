FROM debian:bookworm-slim

# Инсталираме ziproxy
RUN apt-get update && apt-get install -y ziproxy && rm -rf /var/lib/apt/lists/*

# Конфигурираме Ziproxy за Koyeb:
# 1. Слагаме порт 8080
# 2. Позволяваме връзки от всякъде (0.0.0.0)
# 3. Активираме оптимизацията на изображения
RUN sed -i 's/^Port = .*/Port = 8080/' /etc/ziproxy/ziproxy.conf && \
    sed -i 's/^Address = .*/Address = "0.0.0.0"/' /etc/ziproxy/ziproxy.conf && \
    sed -i 's/^ImageQuality = .*/ImageQuality = {70,70,70,70}/' /etc/ziproxy/ziproxy.conf

# Експортираме порта
EXPOSE 8080

# Стартираме ziproxy в режим "foreground", за да не гасне контейнера
CMD ["ziproxy", "-d"]