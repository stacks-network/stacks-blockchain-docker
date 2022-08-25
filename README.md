# Stacks Blockchain with Docker

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Pull Requests Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat)](http://makeapullrequest.com)

Run your own Stacks Blockchain node easily with just few commands.

---

Note: repo has been renamed from `stacks-local-dev` to `stacks-blockchain-docker` and moved from github org `blockstack` to `stacks-network`\
Be sure to update the remote url: `git remote set-url origin https://github.com/stacks-network/stacks-blockchain-docker`

---

## **Requirements:**

- [Docker](https://docs.docker.com/get-docker/) >= `20.10.12`
- [docker-compose](https://github.com/docker/compose/releases/) >= `2.2.2`
- [git](https://git-scm.com/downloads)
- [jq binary](https://stedolan.github.io/jq/download/)
- [sed](https://www.gnu.org/software/sed/)
- Machine with (at a minimum):
  - 4GB memory
  - 1 Vcpu
  - 100GB storage

#### **MacOS with an M1 processor is _NOT_ recommended for this repo**

⚠️ The way Docker for Mac on an Arm chip is designed makes the I/O incredibly slow, and blockchains are **_very_** heavy on I/O. \
This only seems to affect MacOS, other Arm based systems like Raspberry Pi's seem to work fine.

### **Install/Update docker-compose**

_Note: `docker-compose` executable is required, even though recent versions of Docker contain `compose` natively_

- [Install Docker-compose](https://docs.docker.com/compose/install/)
- [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/install/)
- [Docker Desktop for Windows](https://docs.docker.com/docker-for-windows/install/)
- [Docker Engine for Linux](https://docs.docker.com/engine/install/#server)

First, check if you have `docker-compose` installed locally.

To do that, run this command in your terminal :

```bash
$ docker-compose -v
Docker Compose version v2.2.2
```

If the command is not found, or the version is less than `2.2.2`, run the following to install the latest to `/usr/local/bin/docker-compose`:

```bash
#You will need to have jq installed, or this snippet won't run.
VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r)
DESTINATION=/usr/local/bin/docker-compose
sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
sudo chmod 755 $DESTINATION
```

### Security note on docker

The Docker daemon always runs as the root user so by default you will need root privileges to interact with it.

The script `manage.sh` uses docker, so to avoid the requirement of needing to run the script with root privileges it is prefered to be able to _manage Docker as a non-root user_, following [these simple tests](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user).

This will avoid the need of running the script with root privileges for all operations except the removal of data.

### Configuration files you can edit

The following files can be modified to personalize your node configuration, but generally most of them should be left as-is. All these files will be created from the sample copy if they don't exist at runtime (for example `.env` is created from [`sample.env`](sample.env) ). _Note that the burnchchain environemnt variables defined in `./env` will be written to existing config files_

- `.env`
- `./conf/mainnet/Config.toml`
- `./conf/testnet/Config.toml`

By default:

- BNS data is **not** enabled/imported
  - To enable, uncomment `# BNS_IMPORT_DIR=/bns-data` in `./env`
    - Download BNS data: `./manage.sh bns`
- Fungible token metadata is **not** enabled
  - To enable, uncomment `# STACKS_API_ENABLE_FT_METADATA=1` in `./env`
- Non-Fungible token metadata is **not** enabled
  - To enable, uncomment `# STACKS_API_ENABLE_NFT_METADATA=1` in `./env`
- Verbose logging is **not** enabled
  - To enable, uncomment `# VERBOSE=true` in `./env`
- Burnchain config is set to use a public bitcoin node (`bitcoin.mainnet.stacks.org`)
  - To use a different burnchain host, edit the `Burnchain Config` section in `/.env`

### Local Data Dirs

Directories will be created on first start that will store persistent data under `./persistent-data/<folder>`

`<folder>` can be 1 of:

- mainnet
- testnet
- mocknet

## **Quickstart**

1. **Clone the repo locally**

```bash
git clone https://github.com/stacks-network/stacks-blockchain-docker && cd stacks-blockchain-docker
```

2. **Optionally, create/copy `.env` file**. If file `.env` doesn't exist when launched it will be created from `sample.env` automatically.

```bash
cp sample.env .env
```

_You may also use a symlink as an alternative to copying: `ln -s sample.env .env`_

3. **Ensure all images are up to date**

```bash
./manage.sh -n <network> -a pull
```

4. **Start the Services**

```bash
./manage.sh -n <network> -a start
```

- With optional proxy:

```bash
./manage.sh -n <network> -a start -f proxy
```

5. **Stop the Services**

```bash
./manage.sh -n <network> -a stop
```

6. **Retrieve Service Logs**

```bash
./manage.sh -n <network> -a logs
```

- Export docker log files to `./exported-logs`:

This will create one log file for every running service, for example: postgres.log, stacks-blockain.log, stacks-blockchain-api.log  
Notice that each time you run this command the log files will be overwritten.

```bash
./manage.sh -n <network> -a logs export
```

7. **Restart all services**

```bash
./manage.sh -n <network> -a restart
```

- With optional proxy:

```bash
./manage.sh -n <network> -a restart -f proxy
```

8. **Delete** all data in `./persistent-data/<network>`

   This data is owned by root, so you will need to run it with sudo privileges so it can delete the data.

```bash
$ sudo ./manage.sh -n <network> -a reset
```

9. **Download BNS data to** `./persistent-data/bns-data`

```bash
./manage.sh bns
```

10. **Export stacks-blockchain-api events** (_Not applicable for mocknet_)

```bash
./manage.sh -n <network> -a export
# check logs for completion
./manage.sh -n <network> -a restart
```

11. **Replay stacks-blockchain-api events** (_Not applicable for mocknet_)

```bash
./manage.sh -n <network> -a import
# check logs for completion
./manage.sh -n <network> -a restart
```

## **Accessing the services**

_Note_: For networks other than `mocknet`, downloading the initial headers can take several minutes. Until the headers are downloaded, the `/v2/info` endpoints won't return any data. \
Use the command `./manage.sh -n <network> -a logs` to check the sync progress.

**stacks-blockchain**:

- Ports `20443-20444` are exposed to `localhost`

```bash
curl -sL localhost:20443/v2/info | jq
```

**stacks-blockchain-api**:

- Port `3999` are exposed to `localhost`

```bash
curl -sL localhost:3999/v2/info | jq
```

**proxy**:

- Port `80` is exposed to `localhost`

```bash
curl -sL localhost/v2/info | jq
curl -sL localhost/ | jq
```

---

## Upgrades

⚠️ For upgrades to running instances of this repo, you'll need to [run the event-replay](https://github.com/hirosystems/stacks-blockchain-api#event-replay):

```bash
./manage.sh -n <network> -a stop
./manage.sh -n <network> -a export
./manage.sh -n <network> -a import
./manage.sh -n <network> -a restart
```

---

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

_**Database Issues**_:

- For any of the various Postgres/sync issues, it may be easier to simply remove the persistent data dir. Note that doing so will result in a longer startup time as the data is repopulated.

```bash
./manage.sh -n <network> -a stop
./manage.sh -n <network> -a reset
./manage.sh -n <network> -a start
```

_**API Missing Parent Block Error**_:

- If the Stacks blockchain is no longer syncing blocks, and the API reports an error similar to this:\
  `Error processing core node block message DB does not contain a parent block at height 1970 with index_hash 0x3367f1abe0ee35b10e77fbcaa00d3ca452355478068a0662ec492bb30ee0f13e"`,\
  The API (and by extension the DB) is out of sync with the blockchain. \
  The only known method to recover is to resync from genesis (**event-replay _may_ work, but in all likelihood will restore data to the same broken state**).

- To attempt the event-replay

```bash
./manage.sh -n <network> -a stop
./manage.sh -n <network> -a import
# check logs for completion
./manage.sh -n <network> -a restart
```

- To wipe data and re-sync from genesis

```bash
./manage.sh -n <network> -a stop
./manage.sh -n <network> -a reset
./manage.sh -n <network> -a restart
```
