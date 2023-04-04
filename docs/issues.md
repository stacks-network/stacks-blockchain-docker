# Workarounds to potential issues

## Error message

## Postgres error: No Space left on device

tl;dr - This doesn't mean what the error message suggests it means. \
Basically, it needs more memory than is provided by default in Docker - but it can be addressed by modifying the `./env` setting `PG_SHMSIZE` to match the memory resources on your system. \
Currently, the default is set to `256MB` and this has shown to be sufficient to bypass this error, but more is obviously better if you can afford it. \
<https://stackoverflow.com/questions/56751565/pq-could-not-resize-shared-memory-segment-no-space-left-on-device>

Sample error from postgres/API logs:

```
pq: could not resize shared memory segment "/PostgreSQL.2058389254" to 12615680 bytes: No space left on device
```

## Changes to BNS import using stacks-blockchain-api version >= 5.0.0

Some changes introduced in this version of the API breaks the way BNS has been imported in the past. \
In this version, the BNS import has been moved to the event-replay. Notably, this makes it impossible to _first_ import BNS data before syncing. \
The only way I've found to import BNS data using this version is to start the sync, stop it, then run the event-replay import with `BNS_IMPORT_DIR` uncommented, then restart the services. \
<https://github.com/hirosystems/stacks-blockchain-api/issues/1327>

```bash
$ ./manage.sh -n <network> -a start
# let this run until some blocks have been downloaded
$ ./manage.sh -n <network> -a stop
$ ./manage.sh -n <network> -a import
# this will take a while since it should now import BNS data
$ ./manage.sh -n <network> -a restart
```

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

**Alternatively** you can use the script `./scripts/seed-chainstate.sh` to attempt to use a public archive of the data. \
_This requires at least 150GB of free disk and does take a long while to complete_. \

```bash
sudo ./scripts/seed-chainstate.sh
```
