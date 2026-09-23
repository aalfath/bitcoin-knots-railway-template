# Bitcoin Knots for Railway, built from the official signed release binaries.
# The SHA256 values below come from the release's SHA256SUMS file, whose
# signatures (Luke Dashjr and six other Knots builders) were verified with
# the keys in https://github.com/bitcoinknots/guix.sigs/tree/knots/builder-keys.

FROM debian:trixie-20260918-slim AS download

ARG KNOTS_VERSION=29.4.2.knots20260508
ARG KNOTS_SHA256_AMD64=b59d0445a317e21a03dc29425db3aba79b27d5125230b1a2b1dce62e120827c5
ARG KNOTS_SHA256_ARM64=e50c5717e834a68a324d0e8e2fdc097cb3c9ff38cd69ce2caf9360d1e24aa69a
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    case "${TARGETARCH:-amd64}" in \
      amd64) triplet=x86_64-linux-gnu; sha="$KNOTS_SHA256_AMD64" ;; \
      arm64) triplet=aarch64-linux-gnu; sha="$KNOTS_SHA256_ARM64" ;; \
      *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    tarball="bitcoin-${KNOTS_VERSION}-${triplet}.tar.gz"; \
    curl -fsSL -o "/tmp/$tarball" "https://github.com/bitcoinknots/bitcoin/releases/download/v${KNOTS_VERSION}/$tarball"; \
    echo "$sha  /tmp/$tarball" | sha256sum -c -; \
    mkdir /opt/knots; \
    tar -xzf "/tmp/$tarball" -C /opt/knots --strip-components=1; \
    rm "/tmp/$tarball"

FROM debian:trixie-20260918-slim

ARG KNOTS_VERSION=29.4.2.knots20260508

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates openssl \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --system bitcoin \
 && useradd --system --gid bitcoin --home-dir /data --no-create-home --shell /usr/sbin/nologin bitcoin

COPY --from=download /opt/knots/bin/bitcoind /opt/knots/bin/bitcoin-cli /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

LABEL org.opencontainers.image.title="Bitcoin Knots for Railway" \
      org.opencontainers.image.version="${KNOTS_VERSION}" \
      org.opencontainers.image.source="https://github.com/aalfath/bitcoin-knots-railway-template"

ENV BITCOIN_DATA_DIR=/data
EXPOSE 8332 8333
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
