# Stacks Mocknet with Docker
## Requirements:

- [Docker](https://docs.docker.com/get-docker/)
- [docker-compose](https://github.com/docker/compose/releases/) >= `1.27.4`
- [git](https://git-scm.com/downloads)
- `jq` binary

## Quickstart

1. Clone the repo locally:

```bash
  git clone -b mocknet --depth 1 https://github.com/blockstack/stacks-local-dev ./stacks-local-dev && cd ./stacks-local-dev
```

2. Create/Copy `.env` file
*Use a symlink as an alternative to copying: `ln -s sample.env .env`*
```bash
  cp sample.env .env
```

3. Start the Services:
```bash
docker-compose up -d
```
*NOTE*: We are now importing V1 BNS data. What this means is that initially, there will be a longer startup time while the data is downloaded and extracted, then loaded via the API container into postgres. Once this initial load is complete, subsequent restarts will be much faster. Additionally, all data is persistent here - postgres and the stacks-blockchain, so bringing a node up to the tip height should be much faster. 

4. Stop the Services:

```bash
docker-compose down
```

## Bootstrap Container

The first container to start will always be the `mocknet_bootstrap` container. The sole purpose of this container is to run a [script](https://github.com/blockstack/stacks-local-dev/blob/mocknet/setup.sh) to replace the variables in the `.template` files with the values from `.env`

## API Container

The API Container will run a [script](https://github.com/blockstack/stacks-local-dev/blob/mocknet/setup-bns.sh) before starting it's server. The sole purpose of this is to download (or verify the files exist) V1 BNS data. Once the download/extraction/verification has finished, the `stacks-blockchain-api` server will start up

## Env Vars

All variables used in the [`sample.env`](https://github.com/blockstack/stacks-local-dev/blob/mocknet/sample.env) file can be modified, but generally most of them should be left as-is.

## Local Data Dirs

3 Directories will be created on first start that will store persistent data. Deleting this data will result in a full resync of the blockchain, and in the case of `bns-data`, it will have to download and extract the V1 BNS data again. 

### Locally opened ports

In this section of the [`sample.env`](https://github.com/blockstack/stacks-local-dev/blob/mocknet/sample.env) file, the values can be modified to change the ports opened locally by docker.

Currently, default port values are used - but if you have a running service on any of the defined ports, they can be adjusted to any locally available port.

ex:

```bash
API_STACKS_BLOCKCHAIN_API_PORT_LOCAL=3999
```

Can be adjusted to:

```bash
API_STACKS_BLOCKCHAIN_API_PORT_LOCAL=3000
```

Docker will still use the default ports _internally_ - this modification will only affect how the **host** OS accesses the services.

For example, to access postgres (using the **new** port `5433`) after running `docker-compose up -d`:

```bash
export PGPASSWORD='postgres' && psql --host localhost -p 5433 -U postgres -d stacks_node_api
```

### Postgres

Default password is easy to guess, and we do open a port to postgres locally.

This password is defined in the file [`sample.env`](https://github.com/blockstack/stacks-local-dev/blob/mocknet/sample.env#L59) 

```bash
POSTGRES_PASSWORD=postgres
```

## docker-compose

### Install/Update docker-compose

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

### Ensure all images are up to date
```bash
docker-compose pull
```

### Services Running in Mocknet
**docker-compose Mocknet service names**:
- follower
- api
- postgres

**Docker container names**:
- mocknet_stacks-node-follower
- mocknet_stacks-node-api
- mocknet_postgres

#### Starting Mocknet Services

1. Start all services:

```bash
docker-compose up -d
```

2. Start specific service:

```bash
docker-compose start <compose service>
```

#### Stopping Mocknet Services

1. Stop all services:

```bash
docker-compose down
```

2. Stop specific service:

```bash
docker-compose stop <compose service>
```

3. Restart:

```bash
docker-compose restart <compose service>
```

#### Retrieving Mocknet logs

1. Tail logs with docker-compose:

```bash
docker-compose logs -f <compose service>
```

2. Tail logs through `docker`:

```bash
docker logs -f <docker container name>
```

## Accessing the services

**stacks-node-folloer**:

- Ports `20443-20444` are exposed to `localhost`

```bash
curl localhost:20443/v2/info | jq
```

**stacks-node-api**:

- Ports `3700, 30999` are exposed to `localhost`

```bash
curl localhost:3999/v2/info | jq
```

## Using the private testnet

### Spin up the private testnet

Write `.env` file:

```
###############################
## Stacks-Node-API
##
NODE_ENV=production
GIT_TAG=master
PG_HOST=postgres
PG_PORT=5432
PG_USER=stacks
PG_PASSWORD=postgres
PG_DATABASE=stacks_blockchain
PG_SCHEMA=stacks_node_api
STACKS_CHAIN_ID=2147483648
V2_POX_MIN_AMOUNT_USTX=90000000260
STACKS_CORE_EVENT_PORT=3700
STACKS_CORE_EVENT_HOST=0.0.0.0
STACKS_BLOCKCHAIN_API_PORT=3999
STACKS_BLOCKCHAIN_API_HOST=0.0.0.0
STACKS_BLOCKCHAIN_API_DB=pg
STACKS_CORE_RPC_HOST=stacks-node-follower
STACKS_CORE_RPC_PORT=20443
#BNS_IMPORT_DIR=/bns-data

###############################
## Postgres
##
# Make sure the password is the same as PG_PASSWORD above.
# note to document: this is set in the sql for postgres. if the above is changed, that needs to change as well. 
POSTGRES_PASSWORD=postgres
```

Pull the latest docker images

```bash
./manage.sh private-testnet pull
```

Start the testnet

```bash
./manage.sh private-testnet up
```

It will take a few minutes for the stacks-node to sync with the regtest bitcoin node, build a genesis block, etc.
Once `v2/info` returns a non-zero stacks height, the private testnet is ready to use:

```bash
$ curl -s localhost:20443/v2/info | jq .stacks_tip_height
1
```

You can monitor the bootup process by watching the logs:

```bash
$ docker logs --tail 20 -f stacks-node-follower
```

### Deploying a contract

1. Make a keychain

```bash
$ stx make_keychain -t | jq . > cli_keychain.json
```

2. Get some testnet STX:

```
$ curl -s -X POST "localhost:3999/extended/v1/faucets/stx?address=$(cat ./cli_keychain.json | jq -r .keyInfo.address)" | jq .
{
  "success": true,
  "txId": "0xdd8cfd9070f2cdfa13f513e45f7ce6f2fa350f6f4a45c8393b0b0ae88df6fa6a",
  "txRaw": "80800000000400164247d6f2b425ac5771423ae6c80c754f7172b0000000000000000100000000000000b40001715f0751a1f8a20f0af3f8604b30730915d8489f229ea78320b199a7c037ece375808cbd1aa73706c62357a1c8827f859e5c896f5166d1aee8a8c5618163ca5903020000000000051a8234f5ebfd5841303de78bf4eecc41aa1013b2af000000001dcd650046617563657400000000000000000000000000000000000000000000000000000000"
}
```

3. Check your balance:

```bash
$ curl -s "localhost:3999/v2/accounts/$(cat ./cli_keychain.json | jq -r .keyInfo.address)?proof=0" | jq -r .balance
0x0000000000000000000000003b9aca00
```

4. Publish a smart contract:

Generate the transaction hex:

```bash
$ stx deploy_contract -x -t ~/devel/stacks-blockchain/sample-contracts/tokens.clar hello-world 2000 0 $(cat ./cli_keychain.json | jq -r .keyInfo.privateKey) > /tmp/deploy-tx.hex
```

Push to the miner's mempool:

```bash
$ cat /tmp/deploy-tx.hex | xxd -p -r | curl -H "Content-Type: application/octet-stream" -X POST --data-binary @- localhost:20443/v2/transactions
"c1a41067d67e55962018b449fc7defabd409f317124e190d6bbb2905ae11b735"
```

Check the API's view of the transaction:

```
$ curl -s http://localhost:3999/extended/v1/tx/0xc1a41067d67e55962018b449fc7defabd409f317124e190d6bbb2905ae11b735 | jq .
{
  "tx_id": "0xc1a41067d67e55962018b449fc7defabd409f317124e190d6bbb2905ae11b735",
  "tx_type": "smart_contract",
  "nonce": 0,
  "fee_rate": "2000",
  "sender_address": "ST2139XFBZNC42C1XWY5Z9VPC86N104XJNWVB2ZDY",
  "sponsored": false,
  "post_condition_mode": "allow",
  "tx_status": "success",
  "block_hash": "0xe29d0c8eba592de25ac32369e2a56db244e313164b55d6b1cacf5d271b8905d9",
  "block_height": 407,
  "burn_block_time": 1620242680,
  "burn_block_time_iso": "2021-05-05T19:24:40.000Z",
  "canonical": true,
  "tx_index": 1,
  "tx_result": {
    "hex": "0x0703",
    "repr": "(ok true)"
  },
  "post_conditions": [],
  "smart_contract": {
    "contract_id": "ST2139XFBZNC42C1XWY5Z9VPC86N104XJNWVB2ZDY.hello-world",
    "source_code": "(define-map tokens { account: principal } { balance: uint })\n(define-private (get-balance (account principal))\n  (default-to u0 (get balance (map-get? tokens (tuple (account account))))))\n\n(define-private (token-credit! (account principal) (amount uint))\n  (if (<= amount u0)\n      (err \"must move positive balance\")\n      (let ((current-amount (get-balance account)))\n        (begin\n          (map-set tokens (tuple (account account))\n                      (tuple (balance (+ amount current-amount))))\n          (ok amount)))))\n\n(define-public (token-transfer (to principal) (amount uint))\n  (let ((balance (get-balance tx-sender)))\n    (if (or (> amount balance) (<= amount u0))\n        (err \"must transfer positive balance and possess funds\")\n        (begin\n          (map-set tokens (tuple (account tx-sender))\n                      (tuple (balance (- balance amount))))\n          (token-credit! to amount)))))\n\n(define-public (mint! (amount uint))\n   (let ((balance (get-balance tx-sender)))\n     (token-credit! tx-sender amount)))\n\n(token-credit! 'SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR u10000)\n(token-credit! 'SM2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQVX8X0G u300)\n"
  },
  "events": [],
  "event_count": 0
}
```

## Workarounds to potential issues

_**Port already in use**_:

- If you have a port conflict, typically this means you already have a process using that same port.
- To resolve, find the port you have in use (i.e. `3999` and edit the [`sample.env`](https://github.com/blockstack/stacks-local-dev/blob/mocknet/sample.env) file to use the new port)

```bash
$ netstat -anl | grep 3999
tcp46      0      0  *.3999                 *.*                    LISTEN
```

_**Containers not starting (hanging on start)**_:

- Occasionally, docker can get **stuck** and not allow new containers to start. If this happens, simply restart your docker daemon and try again.

_**BNS Data not imported/incorrect**_:
- This could happen if a file exists, but is empty or truncated. The script to extract these files *should* address this, but if it doesn't you can manually extract the files. 
```bash
$ wget https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -O ./persistent-data/bns-data/export-data.tar.gz
$ tar -xvzf ./persistent-data/bns-data/export-data.tar.gz -C ./persistent-data/bns-data/
```

_**Database Issues**_:
- For any of the various Postgres issues, it may be easier to simply remove the persistent data dir for postgres. Note that doing so will result in a longer startup time as the data is repopulated. 
```bash
$ rm -rf ./persistent-data/postgres
```

_**Stacks Blockchain Issues**_:
- For any of the various stacks blockchain issues, it may be easier to simply remove the persistent data dir. Note that doing so will result in a longer startup time as the data is re-synced. 
```bash
$ rm -rf ./persistent-data/stacks-blockchain
```


