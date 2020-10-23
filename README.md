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
All variables used in the `.env` file can be modified, but generally most of them should be left as-is.


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
The variables take the form of `xxxx_CPU` and `xxxx_MEM`.

ex:
```bash
STACKS_MINER_CPU=0.3
STACKS_MINER_MEM=128M
STACKS_FOLLOWER_CPU=0.3
STACKS_FOLLOWER_MEM=128M
```

### Bitcoin
By default, we're using the bitcoin node operated by PBC (hiro or blockstack at this point?).

You're welcome to to use any bitcoin testnet/regtest node you'd prefer by changing the following variables:

```bash
BTC_RPC_PORT=18443
BTC_P2P_PORT=18443
BTC_HOST=bitcoind.blockstack.org
BTC_PW=blockstacksystem
BTC_USER=blockstack
```
**Note**: There is an important env var related here `BTC_FAUCET_PK` that will have to be updated if you use a different btc node. For the server defined above, this already setup - using a different node would require you to set this up yourself.
```bash
BTC_FAUCET_PK=8b5c692c6583d5dca70102bb4365b23b40aba9b5a3f32404a1d31bc09d855d9b
```

### Postgres
Default password is easy to guess, and we do open a port to postgres locally.

This is defined in the file https://github.com/blockstack/stacks-local-dev/blob/master/postgres/stacks-node-api.sql#L1

If you update this value to something other than `postgres`, you'll have to adjust the value in the `.env` file as well, as the mocknet API uses this:
```bash
POSTGRES_PASSWORD=postgres
```

## docker-compose
### Disable mocknet explorer
- highlight how to disable the explorer if so desired
  - ideally, a command to remove it would be sweet

### Starting Mocknet Services
- how to run the compose file
- how to restart individual services

### Stopping Mocknet Services
- how to stop the compose file
- how  to stop services

### Services in the mocknet
- components of the compose file
  - miner
  - follower
  - api
  - postgres
  - explorer

### logging
- how to retrieve the logs
- through compose
- through  docker natively

## accessing the services
- how to access the various services locally


## workarounds to potential issues
- port already in use locally
  - netstat etc, then link to changing the local port we open
- issue from friedger -> restart docker
