# Deploy and Host Bitcoin Knots on Railway

Bitcoin Knots is a Bitcoin full node derived from Bitcoin Core and maintained by Luke Dashjr. It downloads and independently validates every block, applies a stricter transaction relay policy, and exposes the standard `bitcoind` JSON-RPC interface, so your wallets, indexers and scripts can rely on a node you control instead of a third party.

## About Hosting Bitcoin Knots

This template runs one private `bitcoind` service built from the official Knots 29.4.2 release binaries, whose SHA256 hashes are pinned after verifying the release signatures. It runs a pruned mainnet node that keeps about 10 GB of recent blocks, so it needs roughly 25 GB of disk. That exceeds the Hobby plan's 5 GB volume limit, so deploy it on Railway Pro. The first sync validates the whole chain history and takes hours to days. **Chain notice:** Knots 29.4.1 and later include a hard fork to BLAKE2b proof of work, so this node follows the Knots chain, not the chain Bitcoin Core and most wallets and exchanges follow.

## Common Use Cases

- Running your own validating node on the Knots chain for a wallet or backend
- Giving other services in the same Railway project a private `bitcoind` RPC endpoint
- Testing software against Knots on `regtest`, `signet` or `testnet4` by changing one variable

## Dependencies for Bitcoin Knots Hosting

- Bitcoin Knots `29.4.2.knots20260508` official Linux release binaries
- The [aalfath/bitcoin-knots-railway-template](https://github.com/aalfath/bitcoin-knots-railway-template) Dockerfile and entrypoint, built by Railway
- A Railway volume mounted at `/data` (Railway Pro plan)

### Deployment Dependencies

- [Bitcoin Knots website](https://bitcoinknots.org/)
- [Bitcoin Knots 29.4.2 release](https://github.com/bitcoinknots/bitcoin/releases/tag/v29.4.2.knots20260508)
- [Bitcoin Knots builder keys](https://github.com/bitcoinknots/guix.sigs/tree/knots/builder-keys)
- [Railway volumes](https://docs.railway.com/reference/volumes)
- [Railway private networking](https://docs.railway.com/reference/private-networking)

### Implementation Details

Other services in the same project connect over Railway's private network:

```
http://${{bitcoind.RAILWAY_PRIVATE_DOMAIN}}:8332
user:     ${{bitcoind.BITCOIN_RPC_USER}}
password: ${{bitcoind.BITCOIN_RPC_PASSWORD}}
```

The service has no public domain and Railway does not route inbound peer connections to it, so the node only makes outbound peer connections. On every start the entrypoint turns the generated password into a salted `rpcauth` hash, so the password is never written to the volume or shown in the process list, and `bitcoind` runs as an unprivileged `bitcoin` user.

| Variable | Default | Purpose |
| --- | --- | --- |
| `BITCOIN_CHAIN` | `main` | `main`, `test`, `testnet4`, `signet` or `regtest` |
| `BITCOIN_RPC_USER` | `railway` | RPC username |
| `BITCOIN_RPC_PASSWORD` | generated | RPC password |
| `BITCOIN_PRUNE_MB` | `10000` | MiB of blocks to keep; `0` keeps the full chain (about 800 GB, so grow the volume to 1 TB first) |
| `BITCOIN_DBCACHE_MB` | `2048` | UTXO cache in MiB; larger values speed up the first sync but use more memory |
| `BITCOIN_MAXMEMPOOL_MB` | `300` | Mempool memory limit in MiB |
| `BITCOIN_MAX_UPLOAD_MB_PER_DAY` | `2000` | Daily upload cap that limits Railway egress charges |
| `BITCOIN_DISABLE_WALLET` | `1` | Keeps the built-in wallet off; set `0` only if you accept keeping keys on Railway |
| `BITCOIN_EXTRA_ARGS` | empty | Extra `bitcoind` flags, separated by spaces |

To run `bitcoin-cli`, open a shell with `railway ssh --service bitcoind` and run `bitcoin-cli -datadir=/data -chain=main -rpcport=8332 getblockchaininfo`. Railway HTTP health checks cannot reach `bitcoind`'s endpoints, so the service restarts on failure instead, and `RAILWAY_DEPLOYMENT_DRAINING_SECONDS=120` gives it two minutes to flush its database on redeploys. Railway volumes survive redeploys but are not backups.

Before connecting wallets or payment software, read the [Knots 29.4.1](https://github.com/bitcoinknots/bitcoin/releases/tag/v29.4.1.knots20260508) and [29.4.2](https://github.com/bitcoinknots/bitcoin/releases/tag/v29.4.2.knots20260508) release notes. This is a community-maintained deployment package and does not imply affiliation with or endorsement by Bitcoin Knots.

## Why Deploy Bitcoin Knots on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Bitcoin Knots on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
