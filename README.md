# Stacks Blockchain with Docker

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Pull Requests Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat)](http://makeapullrequest.com)

⚠️ For upgrades to running instances of this repo, you'll need to [run the event-replay](https://github.com/hirosystems/stacks-blockchain-api#event-replay):

```bash
./manage.sh <network> export
./manage.sh <network> stop
./manage.sh <network> import
./manage.sh <network> restart
```

Note: repo has been renamed from `stacks-local-dev` to `stacks-blockchain-docker` and moved from github org `blockstack` to `stacks-network`\
Be sure to update the remote url: `git remote set-url origin https://github.com/stacks-network/stacks-blockchain-docker`

### **MacOS with an M1 processor is _NOT_ recommended for this repo**

⚠️ The way Docker for Mac on an Arm chip is designed makes the I/O incredibly slow, and blockchains are **_very_** heavy on I/O. \
This only seems to affect MacOS, other Arm based systems like Raspberry Pi's seem to work fine.

## **Requirements:**

- [Docker](https://docs.docker.com/get-docker/)
- [docker-compose](https://github.com/docker/compose/releases/) >= `1.27.4`
- [git](https://git-scm.com/downloads)
- [jq binary](https://stedolan.github.io/jq/download/)
- VM with at a minimum:
  - 4GB memory
  - 1 Vcpu
  - 50GB storage

### **Install/Update docker-compose**

_Note: `docker-compose` executable is required, even though recent versions of Docker contain `compose` natively_

- [Install Docker-compose](https://docs.docker.com/compose/install/)
- [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/install/)
- [Docker Desktop for Windows](https://docs.docker.com/docker-for-windows/install/)
- [Docker Engine for Linux](https://docs.docker.com/engine/install/#server)

First, check if you have `docker-compose` installed locally.

To do that, run this command in your terminal :

```bash
docker-compose --version
```

Output should look something very similar to this :

```
docker-compose version 1.27.4, build 40524192
```

If the command is not found, or the version is < `1.27.4`, run the following to install the latest to `/usr/local/bin/docker-compose`:

```bash
#You will need to have jq installed, or this snippet won't run.
VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r)
DESTINATION=/usr/local/bin/docker-compose
sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
sudo chmod 755 $DESTINATION
```

### **Env Vars**

All variables used in the [`sample.env`](sample.env) file can be modified, but generally most of them should be left as-is.

### Local Data Dirs

Directories will be created on first start that will store persistent data under `./persistent-data/<network>`

`<network>` can be 1 of:

- mocknet
- testnet
- mainnet
- private-testnet

## **Quickstart**

1. Clone the repo locally:

```bash
git clone https://github.com/stacks-network/stacks-blockchain-docker && cd ./stacks-blockchain-docker
```

2. Create/Copy `.env` file

```bash
cp sample.env .env
```

_You may also use a symlink as an alternative to copying: `ln -s sample.env .env`_

Note: V1 BNS data is **not** imported by default. If you'd like to use BNS data, [uncomment this line](sample.env#L21) in your `.env` file: `BNS_IMPORT_DIR=/bns-data`

3. Ensure all images are up to date

```bash
./manage.sh <network> pull
```

4. Start the Services:

```bash
./manage.sh <network> up
```

- Optional (with a proxy):

```bash
./manage.sh <network> up proxy
```

5. Stop the Services:

```bash
./manage.sh <network> down
```

6. Retrieve Service Logs

```bash
./manage.sh <network> logs
```

7. Restart all services:

```bash
./manage.sh <network> restart
```

- Optional (with a proxy):

```bash
./manage.sh <network> restart proxy
```

7. Delete all data in `./persistent-data/<network>`:

```bash
./manage.sh <network> reset
```

8. export stacks-blockchain-api events (Not applicable for mocknet)

```bash
./manage.sh <network> export
# check logs for completion
./manage.sh <network> restart
```

9. replay stacks-blockchain-api events (Not applicable for mocknet)

```bash
./manage.sh <network> import
# check logs for completion
./manage.sh <network> restart
```

## **Accessing the services**

_Note_: For networks other than `mocknet`, downloading the initial headers can take several minutes. Until the headers are downloaded, the `/v2/info` endpoints won't return any data.
Use the command `./manage.sh <network> logs` to check the sync progress.

**stacks-blockchain**:

- Ports `20443-20444` are exposed to `localhost`

```bash
curl localhost:20443/v2/info | jq
```

**stacks-blockchain-api**:

- Ports `3999` are exposed to `localhost`

```bash
curl localhost:3999/v2/info | jq
```

**proxy**:

- Port `80` is exposed to `localhost`

```bash
curl localhost/v2/info | jq
curl localhost/ | jq
```

---

## **Using the private testnet**

### **Deploying a contract**

_[Follow the guide here](https://docs.hiro.so/references/stacks-cli#installing-the-stacks-cli) to install the `stx` cli_

1. Make a keychain

```bash
stx make_keychain -t | jq . > cli_keychain.json
```

2. Get some testnet STX:

```
curl -s -X POST "localhost:3999/extended/v1/faucets/stx?address=$(cat ./cli_keychain.json | jq -r .keyInfo.address)" | jq .
```

```
{
  "success": true,
  "txId": "0xdd8cfd9070f2cdfa13f513e45f7ce6f2fa350f6f4a45c8393b0b0ae88df6fa6a",
  "txRaw": "80800000000400164247d6f2b425ac5771423ae6c80c754f7172b0000000000000000100000000000000b40001715f0751a1f8a20f0af3f8604b30730915d8489f229ea78320b199a7c037ece375808cbd1aa73706c62357a1c8827f859e5c896f5166d1aee8a8c5618163ca5903020000000000051a8234f5ebfd5841303de78bf4eecc41aa1013b2af000000001dcd650046617563657400000000000000000000000000000000000000000000000000000000"
}
```

3. Check your balance:

```bash
curl -s "localhost:3999/v2/accounts/$(cat ./cli_keychain.json | jq -r .keyInfo.address)?proof=0" | jq -r .balance
```

```
0x0000000000000000000000003b9aca00
```

4. Publish a smart contract:

Generate the transaction hex:

```bash
stx deploy_contract -x -t ~/devel/stacks-blockchain/sample-contracts/tokens.clar hello-world 2000 0 $(cat ./cli_keychain.json | jq -r .keyInfo.privateKey) > /tmp/deploy-tx.hex
```

Push to the miner's mempool:

```bash
cat /tmp/deploy-tx.hex | xxd -p -r | curl -H "Content-Type: application/octet-stream" -X POST --data-binary @- localhost:20443/v2/transactions
"c1a41067d67e55962018b449fc7defabd409f317124e190d6bbb2905ae11b735"
```

Check the API's view of the transaction:

```
curl -s http://localhost:3999/extended/v1/tx/0xc1a41067d67e55962018b449fc7defabd409f317124e190d6bbb2905ae11b735 | jq .
```

```
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

## **Workarounds to potential issues**

_**Port(s) already in use**_:

- If you have a port conflict, typically this means you already have a process using that same port.\
  To resolve, find the port you have in use (i.e. `3999` and edit your `.env` file to use the new port.

```bash
netstat -anl | grep 3999
```

```
tcp46      0      0  *.3999                 *.*                    LISTEN
```

_**Containers not starting (hanging on start)**_:

- Occasionally, docker can get **stuck** and not allow new containers to start. If this happens, simply restart your docker daemon and try again.

_**BNS Data not imported/incorrect**_:

- This could happen if a file exists, but is empty or truncated. The script to extract these files _should_ address this, but if it doesn't you can manually extract the files.

```bash
wget https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -O ./persistent-data/bns-data/export-data.tar.gz
tar -xvzf ./persistent-data/bns-data/export-data.tar.gz -C ./persistent-data/bns-data/
```

_**Database Issues**_:

- For any of the various Postgres/sync issues, it may be easier to simply remove the persistent data dir. Note that doing so will result in a longer startup time as the data is repopulated.

```bash
./manage.sh <network> reset
./manage.sh <network> restart
```

_**API Missing Parent Block Error**_:

- If the Stacks blockchain is no longer syncing blocks, and the API reports an error similar to this:\
  `Error processing core node block message DB does not contain a parent block at height 1970 with index_hash 0x3367f1abe0ee35b10e77fbcaa00d3ca452355478068a0662ec492bb30ee0f13e"`,\
  The API (and by extension the DB) is out of sync with the blockchain. \
  The only known method to recover is to resync from genesis (**event-replay _may_ work, but in all likliehood will restore data to the same broken state**).

- To attempt the event-replay

```bash
./manage.sh <network> import
# check logs for completion
./manage.sh <network> restart
```

- To wipe data and re-sync from genesis

```bash
./manage.sh <network> reset
./manage.sh <network> restart
```
