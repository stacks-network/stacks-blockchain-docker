# Stacks Mainnet with Docker
## Requirements:

- [Docker](https://docs.docker.com/get-docker/)
- [docker-compose](https://github.com/docker/compose/releases/) >= `1.27.4`
- [git](https://git-scm.com/downloads)
- `jq` binary

## Quickstart

1. Clone the repo locally:

```bash
  git clone https://github.com/blockstack/stacks-local-dev ./stacks-local-dev && cd ./stacks-local-dev
```

2. Create/Copy `.env` file
```bash
  cp sample.env .env
```

3. Start the Services:

```bash
docker-compose up -d
```

4. Stop the Services:

```bash
docker-compose down
```

## Env Vars

All variables used in the [`.env`](https://github.com/blockstack/stacks-local-dev/blob/master/.env) file can be modified, but generally most of them should be left as-is.

### Locally opened ports

In this section of the [`.env`](https://github.com/blockstack/stacks-local-dev/blob/master/.env) file, the values can be modified to change the ports opened locally by docker.

Currently, default port values are used - but if you have a running service on any of the defined ports, they can be adjusted to any locally available port.

ex:

```bash
POSTGRES_PORT_LOCAL=5432
```

Can be adjusted to:

```bash
POSTGRES_PORT_LOCAL=5433
```

Docker will still use the default ports _internally_ - this modification will only affect how the **host** OS accesses the services.

For example, to access postgres (using the **new** port `5433`) after running `docker-compose up -d`:

```bash
export PGPASSWORD='postgres' && psql --host localhost -p 5433 -U postgres -d stacks_node_api
```

### Postgres

Default password is easy to guess, and we do open a port to postgres locally.

This password is defined in the file [./postgres/stacks-node-api.sql](https://github.com/blockstack/stacks-local-dev/blob/master/postgres/stacks-node-api.sql#L1)

If you update this value to something other than `postgres`, you'll have to adjust the value in the [`.env`](https://github.com/blockstack/stacks-local-dev/blob/master/.env) file as well, as the API uses this:

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

Running the mainnet explicitly via `docker-compose up/down` should also update the images used.

You can also run the following at anytime to ensure the local images are up to date:

```bash
docker-compose pull
```

### Services Running in Mocknet
**docker-compose Mocknet service names**:
=======
### Services Running in Mainnet
**docker-compose Mainnet service names**:
>>>>>>> master
- miner
- follower
- api
- postgres

**Docker container names**:
<<<<<<< HEAD
- mocknet_stacks-node-miner
- mocknet_stacks-node-follower
- mocknet_stacks-node-api
- mocknet_postgres
=======
- mainnet_stacks-node-miner
- mainnet_stacks-node-follower
- mainnet_stacks-node-api
- mainnet_postgres
>>>>>>> master

#### Starting Mainnet Services

1. Start all services:

```bash
docker-compose up -d
```

2. Start specific service:

```bash
docker-compose start <compose service>
```

#### Stopping Mainnet Services

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

#### Retrieving Mainnet logs

1. Tail logs with docker-compose:

```bash
docker-compose logs -f <compose service>
```

2. Tail logs through `docker`:

```bash
docker logs -f <docker container name>
```

## Accessing the services

**stacks-node-miner**:

- Ports `20443-20444` are exposed to `localhost`

```bash
curl localhost:20443/v2/info | jq
```

**stacks-node-follower**:

- Ports `20443-20444` are **only** exposed to the `mainnet` docker network.

**stacks-node-api**:

- Ports `3700, 30999` are exposed to `localhost`

```bash
curl localhost:3999/v2/info | jq
```

**postgres**:

- Port `5432` is exposed to `localhost` (PGPASSWORD is defined in [`.env`](https://github.com/blockstack/stacks-local-dev/blob/master/.env))

```bash
export PGPASSWORD='postgres' && psql --host localhost -p 5432 -U postgres -d stacks_node_api
```

## Workarounds to potential issues

_Port already in use_:

- If you have a port conflict, typically this means you already have a process using that same port.
- To resolve, find the port you have in use (i.e. `5432` and edit the [`.env`](https://github.com/blockstack/stacks-local-dev/blob/master/.env) file to use the new port)

```bash
$ netstat -anl | grep 5432
tcp46      0      0  *.5432                 *.*                    LISTEN
```

_Containers not starting (hanging on start)_:

- Occasionally, docker can get **stuck** and not allow new containers to start. If this happens, simply restart your docker daemon and try again.
