# Етап 1: Компилиране
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Инсталираме прокси сървъра на elazarl (най-използваната Go библиотека за целта)
RUN go mod init proxy && \
    go get github.com/elazarl/goproxy && \
    echo 'package main\n\
import (\n\
	"log"\n\
	"net/http"\n\
	"os"\n\
	"github.com/elazarl/goproxy"\n\
)\n\
func main() {\n\
	proxy := goproxy.NewProxyHttpServer()\n\
	proxy.Verbose = true\n\
	port := os.Getenv("PORT")\n\
	if port == "" { port = "8080" }\n\
	log.Fatal(http.ListenAndServe(":" + port, proxy))\n\
}' > main.go && \
    go build -o /proxy main.go

# Етап 2: Финално олекотено изображение
FROM alpine:latest
COPY --from=builder /proxy /usr/local/bin/proxy

# Koyeb настройки
ENV PORT=8080
EXPOSE 8080

# Стартираме без допълнителни флагове, защото кодът вече чете $PORT
CMD ["proxy"]