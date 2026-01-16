FROM alpine:latest

# Инсталираме privoxy
RUN apk add --no-cache privoxy

# Конфигурираме Privoxy за Koyeb
# 1. Слушане на порт 8080 и адрес 0.0.0.0
# 2. Активираме компресията (buffer-limit)
# 3. Премахваме логването, за да пестим ресурси
RUN sed -i 's/listen-address  127.0.0.1:8118/listen-address  0.0.0.0:8080/' /etc/privoxy/config && \
    sed -i 's/buffer-limit 4096/buffer-limit 8192/' /etc/privoxy/config && \
    echo "enable-edit-actions 0" >> /etc/privoxy/config && \
    echo "toggle 1" >> /etc/privoxy/config

# Експортираме порта
EXPOSE 8080

# Стартираме Privoxy на преден план (--no-daemon)
# Това гарантира, че Koyeb няма да изключи инстанцията
CMD ["privoxy", "--no-daemon", "/etc/privoxy/config"]