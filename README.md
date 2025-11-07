# Stacks Blockchain with Docker

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Pull Requests Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat)](http://makeapullrequest.com)

Run your own Stacks Blockchain node easily with just few commands.

⚠️ **[docker compose version `2.2.2` or greater is required](./docs/docker.md)**

---

## Quickstart

```bash
git clone https://github.com/stacks-network/stacks-blockchain-docker && cd stacks-blockchain-docker
cp sample.env .env
```

### Sync from genesis (no signer)

```bash
./manage.sh -n mainnet -a start
```

### Sync from genesis (with signer)

```bash
./manage.sh -n mainnet -a start -f signer
```

### Seed chainstate from Hiro Archiver

Using data from the [Hiro Archiver](https://docs.hiro.so/hiro-archive) service, this script will download the latest files, extract them and restore the postgres data. \
_**Note**: it can take a long time to process the data, and you'll need at a minimum roughly 350GB of free space_  \
_**Note**: for faster downloads, install [aria2](https://aria2.github.io/) on your system_

```bash
sudo ./scripts/seed-chainstate.sh
./manage.sh -n mainnet -a start
```

- [Requirements](./docs/requirements.md)
- [Docker Setup](./docs/docker.md)
- [Configuration](./docs/config.md)
- [Upgrading](./docs/upgrade.md)
- [Usage](./docs/usage.md)
- [Common Issues](./docs/issues.md)

---

## Accessing the services

_For networks other than `mocknet`, downloading the initial headers can take several minutes. \
Until the headers are downloaded, the `/v2/info` endpoints won't return any data. \
Use the command `./manage.sh -n <network> -a logs` to check the sync progress._

**stacks-blockchain**:

```bash
curl -sL localhost:20443/v2/info | jq
```

**stacks-blockchain-api**:

```bash
curl -sL localhost:3999/v2/info | jq
```

**proxy** _(optional argument)_:

```bash
curl -sL localhost/v2/info | jq
curl -sL localhost/ | jq
```
