# Stacks Mocknet for local development
## Quickstart
1. start:
```bash
docker-compose up -d
```
2. stop:
```bash
docker-compose down
```

## Install docker-compose
First, check if you have `docker-compose` installed locally:
```bash
$ docker-compose --version
docker-compose version 1.27.4, build 40524192
```

If the command is not found, or the version is < `1.27.4`, run the following to install the latest to `/usr/local/bin/docker-compose`:
```bash
VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r)
DESTINATION=/usr/local/bin/docker-compose
sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
sudo chmod 755 $DESTINATION
```


## Env Vars
### Locally opened ports
In this section, the values can be modified to change the ports opened locally by docker.
Currently, default port values are used - but if you have a running service on any of the defined ports in `.env` file, they can be adjusted to any locally available port.

ex:
```bash
POSTGRES_PORT_LOCAL=5432
EXPLORER_PORT_LOCAL=3000
```
Can be adjusted to:
```bash
POSTGRES_PORT_LOCAL=5433
EXPLORER_PORT_LOCAL=3001
```

Docker will still use the default ports *internally* - this modification will only affect how the **host** OS accesses the services.
For example, to access postgres (using the **new** port `5433`) after running `docker-compose up -d`:
```bash
$ export PGPASSWORD='postgres' && psql --host localhost -p 5433 -U postgres -d stacks_node_api
```


### System Resources
All sections in the `.env` file have specific CPU/MEM values, and can be adjusted as you see fit.
The variables take the form of `xxxx_CPU` and `xxxx_MEM`:
```bash
STACKS_MINER_CPU=0.3
STACKS_MINER_MEM=128M
STACKS_FOLLOWER_CPU=0.3
STACKS_FOLLOWER_MEM=128M
```

### Mocknet Miner/Follower
The only recommended changes here would be the docker image to run, and potentially the `Config.toml` to use.
While it's fine to adjust the other variables, it may have unintended side-effects on dependent services:
```bash
STACKS_IMAGE=blockstack/stacks-blockchain:v23.0.0.8-krypton
STACKS_MINER_CONFIG=./stacks-node-miner/Config.toml
STACKS_FOLLOWER_CONFIG=./stacks-node-follower/Config.toml
```


### Stacks API
```bash
API_PG_USER=sidecar_rw
API_PG_DATABASE=stacks_node_api
API_PG_SCHEMA=sidecar
API_STACKS_BLOCKCHAIN_API_DB=pg
BTC_FAUCET_PK=8b5c692c6583d5dca70102bb4365b23b40aba9b5a3f32404a1d31bc09d855d9b
```

### Bitcoin
```bash
BTC_RPC_PORT=18443
BTC_P2P_PORT=18443
BTC_HOST=bitcoind.blockstack.org
BTC_PW=blockstacksystem
BTC_USER=blockstack
BTC_MODE=mocknet
```

### Postgres
```bash
POSTGRES_IMAGE=postgres:alpine
POSTGRES_PORT=5432
POSTGRES_PASSWORD=postgres
POSTGRES_SETUP=./postgres/stacks-node-api.sql
```

### Mocknet Explorer
```bash
EXPLORER_MOCKNET_API_SERVER=http://localhost
EXPLORER_TESTNET_API_SERVER=http://localhost
EXPLORER_API_SERVER=http://localhost
EXPLORER_NODE_ENV=development
```


## docker-compose
- highlight how to disable the explorer if so desired
  - ideally, a command to remove it would be sweet
- how to run the compose file
- how to stop the containers
- components of the compose file
  - miner
  - follower
  - api
  - postgres
  - explorer

## logging
- how to retrieve the logs

## accessing the services
- how to access the various services locally


## workarounds to potential issues
- port already in use locally
  - netstat etc, then link to changing the local port we open
- issue from friedger -> restart docker
