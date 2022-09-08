# Workarounds to potential issues

## Port(s) already in use

If you have a port conflict, typically this means you already have a process using that same port. \
To resolve, find the port you have in use (i.e. `3999`) and edit your `.env` file to use a different port.

```bash
$ netstat -anl | grep 3999
tcp46      0      0  *.3999                 *.*                    LISTEN
```

## Containers not starting (hanging on start)

Occasionally, docker can get **stuck** and not allow new containers to start. If this happens, simply restart your docker daemon and try again.

```bash
$ sudo systemctl restart docker
```

## API Missing Parent Block Error

If the Stacks blockchain is no longer syncing blocks, and the API reports an error similar to this:\
`Error processing core node block message DB does not contain a parent block at height 1970 with index_hash 0x3367f1abe0ee35b10e77fbcaa00d3ca452355478068a0662ec492bb30ee0f13e"`,\
The API (and by extension the DB) is out of sync with the blockchain. \
The only known method to recover is to resync from genesis (**event-replay _may_ work, but in all likelihood will restore data to the same broken state**).

### Attempt the event-replay

```bash
$ ./manage.sh -n <network> -a stop
$ ./manage.sh -n <network> -a import
$ ./manage.sh -n <network> -a logs # check logs for completion
$ ./manage.sh -n <network> -a restart
```

## Missing bit_xor
If the `stacks-blockchain-api` emits an error like the following: \
`stacks-blockchain-api    | {"level":"error","message":"Error executing:\nSELECT bit_xor(1)\n       ^^^^\n\nfunction bit_xor(integer) does not exist\n","timestamp":"2022-08-23T15:40:56.929Z"}` \
The postgres instance will need to be upgraded from version `13` to >= `14` (postgres 14 has _bit_xor_ enabled by default). \
There is a script that will attempt to upgrade the database from 13 -> 14 at [`./scripts/postgres_upgrade.sh`](../scripts/postgres_upgrade.sh). 

### Attempt to upgrade the postgres data
```bash
$ ./manage.sh -n mainnet -a stop
$ ./scripts/postgres_upgrade.sh
$ ./manage.sh -n mainnet -a start
```



## Database Issues

For any of the various Postgres/sync issues, it may be easier to simply remove the persistent data dir and resync from genesis. \
The most common Postgres issue looks like: `Error: DB does not contain a parent block at height xxxxx`

```bash
$ ./manage.sh -n <network> -a stop
$ sudo ./manage.sh -n <network> -a reset
$ ./manage.sh -n <network> -a start
```