# Configuration

The following files can be modified to personalize your node configuration, but generally most of them should be left as-is. All these files will be created from a sample copy if they don't exist at runtime (for example `.env` is created from [`sample.env`](../sample.env) ). \
_Note: Burnchchain environment variables defined in `./env` will overwrite values in `Config.toml` files for mainnet/testnet when services are started_

- `.env`
- `./conf/mainnet/Config.toml`
- `./conf/testnet/Config.toml`

## Environment Variables

Most variables in `.env` shouldn't be modified, but there are a few you may wish to change before starting the services.

### Global Settings

| Name                            | Description                                           | Default Value             |
| ------------------------------- | ----------------------------------------------------- | ------------------------- |
| `VERBOSE`                       | Enables verbose logging when `./manage.sh` is invoked | `false`                   |
| `DOCKER_NETWORK`                | Name of docker network used to launch services        | `stacks`                  |
| `EXPOSE_POSTGRES`               | Expose postgres service to the host OS                | `false`                   |
| `STACKS_BLOCKCHAIN_VERSION`     | Stacks Blockchain Docker image version                | `latest released version` |
| `STACKS_BLOCKCHAIN_API_VERSION` | Stacks Blockchain API Docker image version            | `latest released version` |
| `POSTGRES_VERSION`              | Postgres Docker image version                         | `14`                      |
| `NGINX_PROXY_PORT`              | HTTP port for the nginx proxy                         | `80`                      |

### API Settings

#### Recommened to leave these settings _as is_

| Name                         | Description                                                                                                 | Default Value                              |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| `NODE_ENV`                   | Application environment the API is running                                                                  | `production`                               |
| `GIT_TAG`                    | Application Git tag                                                                                         | `master`                                   |
| `PG_HOST`                    | Host of the postgres instance for the API's datastore                                                       | `postgres`                                 |
| `PG_PORT`                    | Port of the postgres service                                                                                | `5432`                                     |
| `PG_USER`                    | Postgres username                                                                                           | `postgres`                                 |
| `PG_PASSWORD`                | Postgres password                                                                                           | `postgres`                                 |
| `PG_DATABASE`                | Postgres database name                                                                                      | `postgres`                                 |
| `PG_SHMSIZE`                 | Shared memory size for Postgres                                                                             | `256MB`                                    |
| `STACKS_CORE_EVENT_PORT`     | Port to accept incoming Stacks Blockchain events                                                            | `3700`                                     |
| `STACKS_CORE_EVENT_HOST`     | IPv4 to accept incoming Stacks Blockchain events                                                            | `0.0.0.0`                                  |
| `STACKS_BLOCKCHAIN_API_PORT` | Port to run the HTTP interface                                                                              | `3999`                                     |
| `STACKS_BLOCKCHAIN_API_HOST` | IPv4 to run the HTTP interface                                                                              | `0.0.0.0`                                  |
| `STACKS_BLOCKCHAIN_API_DB`   | Database type to store data                                                                                 | `pg`                                       |
| `STACKS_CORE_RPC_HOST`       | FQDN of the Stacks Blockchain service for RPC proxy requests                                                | `stacks-blockchain`                        |
| `STACKS_CORE_RPC_PORT`       | RPC port of the Stacks Blockchain service                                                                   | `20443`                                    |
| `STACKS_CORE_P2P_PORT`       | P2P port of the Stacks Blockchain service                                                                   | `20444`                                    |
| `STACKS_EXPORT_EVENTS_FILE`  | File to store the API events file.<br>Locally this is stored at `./persistent-data/<network>/event-replay/` | `/tmp/event-replay/stacks-node-events.tsv` |

#### Options commented out by default

| Name                                   | Description                                        | Default Value |
| -------------------------------------- | -------------------------------------------------- | ------------- |
| `STACKS_API_ENABLE_FT_METADATA`        | Enables storing metadata for fungible events       | `0`           |
| `STACKS_API_ENABLE_NFT_METADATA`       | Enables storing metadata for non-fungible events   | `0`           |
| `STACKS_API_TOKEN_METADATA_ERROR_MODE` | Token metadata error handling level                | `warning`     |
| `BNS_IMPORT_DIR`                       | Required with a path to import/use legacy BNS data | `/bns-data`   |

### Stacks Blockchain Settings

| Name                      | Description                                                                                            | Value  |
| ------------------------- | ------------------------------------------------------------------------------------------------------ | ------ |
| `RUST_BACKTRACE`          | Display full rust backtrace on unexepcted binary exit                                                  | `full` |
| `STACKS_LOG_DEBUG`        | Verbose output logs                                                                                    | `0`    |
| `STACKS_LOG_JSON`         | Output logs in json format                                                                             | `0`    |
| `STACKS_SHUTDOWN_TIMEOUT` | Time to wait for Stacks Blockchain to shutdown properly.<br>_recommended to leave this at the default_ | `1200` |

### Burnchain Settings

#### Mainnet Burnchain Defaults

| Name           | Description                           | Default Value                |
| -------------- | ------------------------------------- | ---------------------------- |
| `BTC_HOST`     | FQDN of bitcoin mainnnet host         | `bitcoin.mainnet.stacks.org` |
| `BTC_RPC_USER` | RPC username for bitcoin mainnet host | `stacks`                     |
| `BTC_RPC_PASS` | RPC password for bitcoin mainnet host | `foundation`                 |
| `BTC_RPC_PORT` | RPC port for bitcoin mainnet host     | `8332`                       |
| `BTC_P2P_PORT` | P2P port for bitcoin mainnet host     | `8333`                       |

#### Testnet Burnchain Defaults

| Name            | Description                           | Default Value                |
| --------------- | ------------------------------------- | ---------------------------- |
| `TBTC_HOST`     | FQDN of bitcoin mainnnet host         | `bitcoin.testnet.stacks.org` |
| `TBTC_RPC_USER` | RPC username for bitcoin mainnet host | `stacks`                     |
| `TBTC_RPC_PASS` | RPC password for bitcoin mainnet host | `foundation`                 |
| `TBTC_RPC_PORT` | RPC port for bitcoin mainnet host     | `18332`                      |
| `TBTC_P2P_PORT` | P2P port for bitcoin mainnet host     | `18333`                      |
