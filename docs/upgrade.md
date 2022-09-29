# API Upgrades

The current major version of the API (version `5.x.x` ) isn't allowing an event-replay to upgrade from API version `4.x.x` \
An issue has been filed: https://github.com/hirosystems/stacks-blockchain-api/issues/1336 \
For now, it's recommended to sync from genesis if using API version `5.x.x`


## Breaking API schema changes

Typically when there is a major version change in the Stacks Blockchain API, an event-replay import will be required \
⚠️ For upgrades to running instances of this repo, you'll need to [run the API event-replay](https://github.com/hirosystems/stacks-blockchain-api#event-replay)\
\
By default, `STACKS_EXPORT_EVENTS_FILE` is enabled and there should already be an event replay file stored in `./persistent-data/<network>/event-replay` \
_If needed, this file can be (re)created using the `export` command:_
```bash
$ ./manage.sh -n <network> -a export
```

## Running Stacks Blockchain API event-replay

```bash
$ ./manage.sh -n <network> -a stop
$ ./manage.sh -n <network> -a import
$ ./manage.sh -n <network> -a restart
```
