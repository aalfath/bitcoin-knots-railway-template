# Deploy and Host Bitcoin Knots on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/TEMPLATE_CODE)

**Published on the Railway marketplace:** https://railway.com/deploy/TEMPLATE_CODE

Bitcoin Knots is a full node implementation derived from Bitcoin Core and maintained by Luke Dashjr. It downloads and independently validates every block, relays transactions under its own stricter mempool policy, and exposes the standard `bitcoind` JSON-RPC and REST interfaces so wallets, indexers and payment tools can rely on a node you control.

> **Chain notice: read before deploying.** Bitcoin Knots 29.4.1 and later include a hard fork. They activate a BLAKE2b proof-of-work algorithm, a temporary 800 kWU block weight limit and a new `SIGHASH_UNIFIED` signature format at a flag day. This node therefore follows the **Knots chain**, which is a different chain from the one Bitcoin Core, BTCPay Server's default node and most wallets and exchanges follow. Balances, confirmations and payments seen by this node can differ from what Bitcoin Core users see. Read the [Knots 29.4.1](https://github.com/bitcoinknots/bitcoin/releases/tag/v29.4.1.knots20260508) and [29.4.2](https://github.com/bitcoinknots/bitcoin/releases/tag/v29.4.2.knots20260508) release notes and decide which chain you intend to follow before connecting any wallet or payment software to it.

## About Hosting Bitcoin Knots

Hosting Bitcoin Knots requires one private container and one persistent volume. This package builds a small Debian image around the official Knots 29.4.2 release binaries. The Dockerfile pins the SHA256 of each tarball, taken from the release's `SHA256SUMS` file after verifying its seven builder signatures, including Luke Dashjr's codesigning key.

The node runs a pruned mainnet by default, keeping about 10 GB of recent blocks plus the chain state, so it needs roughly 25 GB of disk. That is above the Hobby plan's 5 GB volume limit, so **deploy it on the Railway Pro plan** (50 GB volumes by default). The initial sync downloads and validates the whole chain history; on Railway this typically takes from many hours to a few days, and it is CPU and memory intensive while it runs.

RPC is reachable only over Railway's private network. The service has no public domain, and Railway does not route inbound peer connections to it, so the node makes outbound peer connections only.

## Common Use Cases

- Running your own validating node on the Knots chain for a wallet or backend
- Giving other services in the same Railway project (indexers, explorers, bots) a private `bitcoind` RPC endpoint
- Testing software against Knots on `regtest`, `signet` or `testnet4` by changing one variable

## Dependencies for Bitcoin Knots Hosting

- Bitcoin Knots `29.4.2.knots20260508` official Linux release binaries
- `debian:trixie-20260918-slim` base image
- This repository's Dockerfile and entrypoint, built by Railway from GitHub
- One Railway persistent volume mounted at `/data`
- Railway Pro plan for a volume large enough for a pruned mainnet node

### Deployment Dependencies

- [Bitcoin Knots website](https://bitcoinknots.org/)
- [Bitcoin Knots 29.4.2 release](https://github.com/bitcoinknots/bitcoin/releases/tag/v29.4.2.knots20260508)
- [Bitcoin Knots builder keys](https://github.com/bitcoinknots/guix.sigs/tree/knots/builder-keys)
- [Railway volumes](https://docs.railway.com/reference/volumes)
- [Railway private networking](https://docs.railway.com/reference/private-networking)

## Implementation Details

| Service | Image | Networking and health | Persistent storage |
| --- | --- | --- | --- |
| `bitcoind` | GitHub Dockerfile using the official Knots 29.4.2 binaries, SHA256-pinned | Private only: RPC and REST on `8332`, P2P on `8333`; readiness path `/rest/chaininfo.json` | `/data` for blocks, chain state and peer data |

Other services in the same project reach the node at `http://bitcoind.railway.internal:8332` with `BITCOIN_RPC_USER` and `BITCOIN_RPC_PASSWORD`, which you can reference as `${{bitcoind.BITCOIN_RPC_USER}}` and `${{bitcoind.BITCOIN_RPC_PASSWORD}}`. On every start the entrypoint turns the generated password into a salted `rpcauth` hash, so the password is never written to the volume or shown in the process list. `bitcoind` runs as an unprivileged `bitcoin` user.

| Variable | Default | Purpose |
| --- | --- | --- |
| `BITCOIN_CHAIN` | `main` | `main`, `test`, `testnet4`, `signet` or `regtest` |
| `BITCOIN_RPC_USER` | `railway` | RPC username |
| `BITCOIN_RPC_PASSWORD` | generated | RPC password |
| `BITCOIN_PRUNE_MB` | `10000` | Block storage to keep in MiB; `0` disables pruning (needs a volume of about 1 TB) |
| `BITCOIN_DBCACHE_MB` | `2048` | UTXO cache in MiB; larger values speed up the initial sync but use more memory |
| `BITCOIN_MAXMEMPOOL_MB` | `300` | Mempool memory limit in MiB |
| `BITCOIN_MAX_UPLOAD_MB_PER_DAY` | `2000` | Daily upload cap to limit Railway egress charges |
| `BITCOIN_DISABLE_WALLET` | `1` | Keeps the built-in wallet off; set `0` only if you accept keeping keys on Railway |
| `BITCOIN_EXTRA_ARGS` | empty | Extra `bitcoind` flags, separated by spaces |

To run `bitcoin-cli`, open a shell with `railway ssh --service bitcoind` and run `bitcoin-cli -datadir=/data -chain=main -rpcport=8332 getblockchaininfo`. Adjust `-chain` if you changed `BITCOIN_CHAIN`.

The REST interface is enabled so Railway can check readiness without credentials; it serves read-only chain data on the private network. Railway volumes preserve state across deployments but are not backups. Keep the built-in wallet disabled, or back it up yourself if you turn it on.

This is a community-maintained deployment package and does not imply affiliation with or endorsement by Bitcoin Knots.

## Why Deploy Bitcoin Knots on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Bitcoin Knots on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
