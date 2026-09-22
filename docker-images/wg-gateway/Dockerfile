# syntax=docker/dockerfile:1
FROM alpine:3.20

RUN apk add --no-cache wireguard-tools socat

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
