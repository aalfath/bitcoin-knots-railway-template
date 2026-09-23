#!/bin/sh
# Starts bitcoind for Railway: prepares the volume, derives an rpcauth line
# from the RPC password (so the password itself never touches disk or argv),
# then drops privileges to the bitcoin user.
set -eu

data_dir="${BITCOIN_DATA_DIR:-/data}"
chain="${BITCOIN_CHAIN:-main}"
rpc_port="${BITCOIN_RPC_PORT:-8332}"
p2p_port="${BITCOIN_P2P_PORT:-8333}"

case "$chain" in
  main|test|testnet4|signet|regtest) ;;
  *) echo "BITCOIN_CHAIN must be one of main, test, testnet4, signet, regtest (got '$chain')" >&2; exit 1 ;;
esac

: "${BITCOIN_RPC_USER:?BITCOIN_RPC_USER is required}"
: "${BITCOIN_RPC_PASSWORD:?BITCOIN_RPC_PASSWORD is required}"
case "$BITCOIN_RPC_USER" in
  *[!A-Za-z0-9._@-]*) echo "BITCOIN_RPC_USER may only contain letters, digits, '.', '_', '@' and '-'" >&2; exit 1 ;;
esac

# Railway mounts volumes as root; hand the data directory to the bitcoin user.
mkdir -p "$data_dir"
if [ "$(stat -c %U "$data_dir")" != "bitcoin" ]; then
  chown -R bitcoin:bitcoin "$data_dir"
fi

salt="$(openssl rand -hex 16)"
hmac="$(printf '%s' "$BITCOIN_RPC_PASSWORD" | openssl dgst -sha256 -hmac "$salt" | sed 's/^.*= //')"

# Railway's private DNS answers with IPv6 first, so listen on IPv6 when the
# container has a non-loopback IPv6 address (a failed bind is fatal for
# bitcoind). On Railway, give the private network a moment to come up.
# The RPC server's [::] socket is dual-stack and also accepts IPv4, so it must
# not be combined with a separate 0.0.0.0 bind on the same port.
has_ipv6() { awk '$6 != "lo" { found = 1 } END { exit !found }' /proc/net/if_inet6 2>/dev/null; }
tries=0
while ! has_ipv6 && [ -n "${RAILWAY_PRIVATE_DOMAIN:-}" ] && [ "$tries" -lt 10 ]; do
  tries=$((tries + 1))
  sleep 1
done
if has_ipv6; then
  set -- -rpcbind="[::]:$rpc_port" -bind="[::]:$p2p_port" "$@"
else
  set -- -rpcbind="0.0.0.0:$rpc_port" "$@"
fi

set -- \
  -datadir="$data_dir" \
  -chain="$chain" \
  -printtoconsole=1 \
  -nodebuglogfile \
  -server=1 \
  -rpcauth="$BITCOIN_RPC_USER:$salt\$$hmac" \
  -rpcport="$rpc_port" \
  -rpcallowip=0.0.0.0/0 \
  -rpcallowip=::/0 \
  -listen=1 \
  -discover=0 \
  -listenonion=0 \
  -port="$p2p_port" \
  -bind="0.0.0.0:$p2p_port" \
  -prune="${BITCOIN_PRUNE_MB:-10000}" \
  -dbcache="${BITCOIN_DBCACHE_MB:-2048}" \
  -maxmempool="${BITCOIN_MAXMEMPOOL_MB:-300}" \
  -maxuploadtarget="${BITCOIN_MAX_UPLOAD_MB_PER_DAY:-2000}" \
  -disablewallet="${BITCOIN_DISABLE_WALLET:-1}" \
  "$@"

# BITCOIN_EXTRA_ARGS is intentionally word-split into extra bitcoind flags.
# shellcheck disable=SC2086
exec setpriv --reuid=bitcoin --regid=bitcoin --init-groups \
  /usr/local/bin/bitcoind "$@" ${BITCOIN_EXTRA_ARGS:-}
