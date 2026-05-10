# syntax=docker/dockerfile:1

FROM debian:bookworm AS builder

ARG BAMTOOLS_VERSION=v2.5.3
ARG BAMTOOLS_URL=https://github.com/pezmaster31/bamtools/archive/refs/tags/v2.5.3.tar.gz

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates curl cmake make g++ zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN curl -fsSL "$BAMTOOLS_URL" -o bamtools.tar.gz \
    && tar -xzf bamtools.tar.gz

WORKDIR /src/bamtools-2.5.3/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/bamtools .. \
    && make -j"$(nproc)" \
    && make install \
    && test -x /opt/bamtools/bin/bamtools \
    && cp /opt/bamtools/bin/bamtools /tmp/bamtools

RUN mkdir -p /tmp/runtime-libs \
    && (ldd /tmp/bamtools | awk '/=> \/|^\// {for(i=1;i<=NF;i++) if ($i ~ /^\//) print $i}' | sort -u | xargs -r -I{} cp -v --parents "{}" /tmp/runtime-libs) || true

FROM debian:bookworm-slim

COPY --from=builder /opt/bamtools /opt/bamtools
COPY --from=builder /tmp/runtime-libs/ /

RUN printf '%s\n' '#!/bin/sh' \
    'if [ "${1:-}" = "bamtools" ]; then shift; fi' \
    'exec /opt/bamtools/bin/bamtools "$@"' > /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh \
    && ln -sf /opt/bamtools/bin/bamtools /usr/local/bin/bamtools

ENV PATH="/opt/bamtools/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/bamtools/lib"
WORKDIR /data
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
