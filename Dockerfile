FROM debian:bookworm-slim

# Инсталираме ziproxy
RUN apt-get update && apt-get install -y ziproxy && rm -rf /var/lib/apt/lists/*

# Конфигурираме Ziproxy:
# 1. Порт 8080 (Koyeb стандарт)
# 2. Слушане на всички адреси (0.0.0.0)
# 3. Намаляваме качеството на снимките за пестене на трафик
RUN sed -i 's/^Port = .*/Port = 8080/' /etc/ziproxy/ziproxy.conf && \
    sed -i 's/^Address = .*/Address = "0.0.0.0"/' /etc/ziproxy/ziproxy.conf && \
    sed -i 's/^ImageQuality = .*/ImageQuality = {70,70,70,70}/' /etc/ziproxy/ziproxy.conf

# Експортираме порта
EXPOSE 8080

# Слагаме флаг -n (no-detach), който държи процеса активен на преден план
# Това ще попречи на контейнера да се затвори с Exit Code 0
CMD ["ziproxy", "-d", "-n"]