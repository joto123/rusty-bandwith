FROM alpine:latest

# Инсталираме privoxy
RUN apk add --no-cache privoxy

# Директно записваме работеща конфигурация за Alpine
RUN echo -e "confdir /etc/privoxy\n\
logdir /var/log/privoxy\n\
filterfile default.filter\n\
filterfile user.filter\n\
actionsfile match-all.action\n\
actionsfile default.action\n\
actionsfile user.action\n\
listen-address 0.0.0.0:8080\n\
toggle 1\n\
enable-remote-toggle 0\n\
enable-remote-http-toggle 0\n\
enable-edit-actions 0\n\
buffer-limit 8192" > /etc/privoxy/config

# Оправяме правата за всеки случай
RUN chown -R privoxy:privoxy /etc/privoxy

EXPOSE 8080

# Стартираме
CMD ["privoxy", "--no-daemon", "--user", "privoxy", "/etc/privoxy/config"]