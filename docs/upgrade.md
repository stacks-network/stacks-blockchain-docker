# API Upgrades

⚠️ For upgrades to running instances of this repo, you'll need to [run the API event-replay](https://github.com/hirosystems/stacks-blockchain-api#event-replay)

## Breaking API schema changes

Typically when there is a major version change in the Stacks Blockchain API, an event-replay import will be required \
\
_This file will need to be created using the `export` command, and will be stored in `./persistent-data/<network>/event-replay`_

```bash
$ ./manage.sh -n <network> -a export
```

## Running Stacks Blockchain API event-replay

```bash
$ ./manage.sh -n <network> -a stop
$ ./manage.sh -n <network> -a import
$ ./manage.sh -n <network> -a restart
```
