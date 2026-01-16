FROM alpine:latest

# Инсталираме privoxy
RUN apk add --no-cache privoxy

# Създаваме чиста конфигурация директно
RUN echo "confdir /etc/privoxy" > /etc/privoxy/config.new && \
    echo "logdir /var/log/privoxy" >> /etc/privoxy/config.new && \
    echo "filterfile default.filter" >> /etc/privoxy/config.new && \
    echo "filterfile user.filter" >> /etc/privoxy/config.new && \
    echo "actionsfile match-all.action" >> /etc/privoxy/config.new && \
    echo "actionsfile default.action" >> /etc/privoxy/config.new && \
    echo "actionsfile user.action" >> /etc/privoxy/config.new && \
    echo "listen-address 0.0.0.0:8080" >> /etc/privoxy/config.new && \
    echo "toggle 1" >> /etc/privoxy/config.new && \
    echo "enable-remote-toggle 0" >> /etc/privoxy/config.new && \
    echo "enable-remote-http-toggle 0" >> /etc/privoxy/config.new && \
    echo "enable-edit-actions 0" >> /etc/privoxy/config.new && \
    echo "buffer-limit 8192" >> /etc/privoxy/config.new && \
    echo "keep-alive-timeout 5" >> /etc/privoxy/config.new && \
    mv /etc/privoxy/config.new /etc/privoxy/config

# Експортираме порта за Koyeb
EXPOSE 8080

# Стартираме Privoxy на преден план
CMD ["privoxy", "--no-daemon", "/etc/privoxy/config"]