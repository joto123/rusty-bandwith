FROM alpine:latest

# Инсталираме privoxy
RUN apk add --no-cache privoxy

# Променяме конфигурацията директно в оригиналния файл:
# 1. Сменяме адреса на 0.0.0.0:8080 за Koyeb
# 2. Уверяваме се, че пътищата до файловете са правилни за Alpine (/etc/privoxy/)
RUN sed -i 's/listen-address  127.0.0.1:8118/listen-address  0.0.0.0:8080/' /etc/privoxy/config && \
    sed -i 's/enable-edit-actions 0/enable-edit-actions 1/' /etc/privoxy/config && \
    sed -i 's/buffer-limit 4096/buffer-limit 8192/' /etc/privoxy/config

# Експортираме порта
EXPOSE 8080

# Стартираме Privoxy на преден план
# Използваме потребител 'privoxy', за да нямаме проблеми с правата
CMD ["privoxy", "--no-daemon", "--user", "privoxy", "/etc/privoxy/config"]