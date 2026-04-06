FROM debian:bookworm-slim AS libs

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libc6:i386 \
        libstdc++5:i386 \
        libstdc++6:i386 \
        libgcc-s1:i386 && \
    rm -rf /var/lib/apt/lists/*

FROM alpine:3.22

LABEL org.opencontainers.image.title="CoD2 Server"
LABEL org.opencontainers.image.description="Malý Call of duty 2 (v1.3) server v docker kontejneru - včetně knihovny libcod2x (v1.4.x) a opravených map ze zpam3. Vlastní malý rifle only mód."
LABEL org.opencontainers.image.documentation="https://github.com/MrakCZ/cod2-docker-server/blob/main/README.md"
LABEL org.opencontainers.image.authors="MrakCZ"
LABEL org.opencontainers.image.url="https://github.com/MrakCZ/cod2-docker-server"
LABEL org.opencontainers.image.source="https://github.com/MrakCZ/cod2-docker-server"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="MrakCZ"

ENV SERVER_USER="cod2"
RUN addgroup -g 1000 ${SERVER_USER} && \
    adduser -D -u 1000 -G ${SERVER_USER} ${SERVER_USER}

# 32bit knihovny z Debian build fáze
COPY --from=libs /usr/lib/i386-linux-gnu/ /usr/lib/i386-linux-gnu/
COPY --from=libs /lib/i386-linux-gnu/ /lib/i386-linux-gnu/
COPY --from=libs /lib/ld-linux.so.2 /lib/ld-linux.so.2

# Server binárka
COPY --chown=cod2:cod2 bin/cod2_lnxded_1_3_nodelay_va_loc /home/cod2/cod2_lnxded
RUN chmod +x /home/cod2/cod2_lnxded

# CoD2x
COPY --chown=cod2:cod2 bin/libCoD2x.so /home/cod2/libCoD2x.so
RUN chmod +x /home/cod2/libCoD2x.so

EXPOSE 20500/udp 20510/udp 28960/tcp 28960/udp

VOLUME ["/home/cod2/main"]

WORKDIR /home/cod2

# Přesměruj game log do docker stdout
RUN mkdir -p /home/cod2/.callofduty2/main/ && \
    ln -sf /dev/stdout /home/cod2/.callofduty2/main/games_mp.log && \
    chown -R cod2:cod2 /home/cod2/.callofduty2

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD pgrep cod2_lnxded > /dev/null && \
    test -e /home/cod2/.callofduty2/main/games_mp.log || exit 1

USER cod2

ENV LD_PRELOAD="/home/cod2/libCoD2x.so"

ENTRYPOINT ["./cod2_lnxded"]
