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


