FROM golang:latest AS builder

LABEL org.opencontainers.image.source=https://github.com/yangchuansheng/ip_derper

WORKDIR /app

ADD tailscale /app/tailscale

# build modified derper
RUN cd /app/tailscale/cmd/derper && \
    CGO_ENABLED=0 /usr/local/go/bin/go build -buildvcs=false -ldflags "-s -w" -o /app/derper && \
    cd /app && \
    rm -rf /app/tailscale

FROM backplane/upx:latest AS upx
COPY --from=builder /app/derper /app/derper
RUN upx --best /app/derper

FROM ubuntu:20.04
WORKDIR /app

# ========= CONFIG =========
# - derper args
ENV DERP_ADDR=:443 \
    DERP_HTTP_PORT=80 \
    DERP_HOST=127.0.0.1 \
    DERP_CERTS=/app/certs/ \
    DERP_STUN=true \
    DERP_VERIFY_CLIENTS=false
# ==========================

# apt
RUN apt-get update && \
    apt-get install -y openssl curl

COPY build_cert.sh /app/
COPY --from=upx /app/derper /app/derper

# build self-signed certs && start derper
CMD bash /app/build_cert.sh $DERP_HOST $DERP_CERTS /app/san.conf && \
    /app/derper --hostname=$DERP_HOST \
    --certmode=manual \
    --certdir=$DERP_CERTS \
    --stun=$DERP_STUN  \
    --a=$DERP_ADDR \
    --http-port=$DERP_HTTP_PORT \
    --verify-clients=$DERP_VERIFY_CLIENTS
