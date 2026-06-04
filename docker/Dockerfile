FROM debian:bookworm AS builder

ARG ENABLE_DOCS=false
ARG OSMO_INSTALL_PREFIX=/usr/local

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/osmoweb-tools

COPY scripts ./scripts
COPY docker/build-in-container.sh /usr/local/bin/build-in-container.sh

RUN chmod +x /usr/local/bin/build-in-container.sh \
    && build-in-container.sh

FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libc-ares2 \
        libdbd-sqlite3 \
        libdbi1 \
        libfftw3-single3 \
        libgnutls30 \
        libmnl0 \
        libortp16 \
        libosip2-15 \
        libpcsclite1 \
        libsofia-sip-ua0 \
        libsctp1 \
        libsqlite3-0 \
        libssl3 \
        libsystemd0 \
        libtalloc2 \
        liburing2 \
        libusb-1.0-0 \
        procps \
        telnet \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local /usr/local
COPY docker/osmo-entrypoint.sh /usr/local/bin/osmo-entrypoint.sh
COPY scripts/config.tar.gz /opt/osmo/config.tar.gz

RUN chmod +x /usr/local/bin/osmo-entrypoint.sh \
    && mkdir -p /etc/osmo /var/log/osmo /usr/local/etc/osmocom \
    && tar -xzf /opt/osmo/config.tar.gz -C /etc/osmo \
    && ldconfig

VOLUME ["/etc/osmo", "/var/log/osmo", "/usr/local/etc/osmocom"]

EXPOSE 4237 4239 4241 4242 4243 4254 4258

ENTRYPOINT ["/usr/local/bin/osmo-entrypoint.sh"]
