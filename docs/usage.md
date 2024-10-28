# Script Options

## Usage

```
Usage:
    ./manage.sh -n <network> -a <action> <optional args>
        -n|--network: [ mainnet | testnet | mocknet ]
        -a|--action: [ start | stop | logs | reset | upgrade | import | export | bns ]
    optional args:
        -f|--flags: [ signer,proxy ]
        export: combined with 'logs' action, exports logs to a text file
    ex: ./manage.sh -n mainnet -a start -f proxy
	ex: ./manage.sh -n mainnet -a start -f signer,proxy
    ex: ./manage.sh --network mainnet --action start --flags proxy
    ex: ./manage.sh -n mainnet -a logs export
```

### Starting Services

```bash
./manage.sh -n <network> -a start
```

```bash
./manage.sh -n <network> -a restart
```

#### With optional signer

```bash
./manage.sh -n <network> -a start -f signer
```

```bash
./manage.sh -n <network> -a restart -f signer
```

#### With optional proxy

```bash
./manage.sh -n <network> -a start -f proxy
```

```bash
./manage.sh -n <network> -a restart -f proxy
```

---

### Stopping Services

```bash
./manage.sh -n <network> -a stop
```

---

### Event Replay

#### Export stacks-blockchain-api events (_Not applicable for mocknet_)

```bash
./manage.sh -n <network> -a export
./manage.sh -n <network> -a logs # check logs for completion
./manage.sh -n <network> -a restart
```

#### Replay stacks-blockchain-api events (_Not applicable for mocknet_)

```bash
./manage.sh -n <network> -a import
./manage.sh -n <network> -a logs # check logs for completion
./manage.sh -n <network> -a restart
```

---

### Logging

#### Stream logs to terminal

```bash
./manage.sh -n <network> -a logs
```

#### Export docker log files

This will create a log file in `./exported-logs` for every running service. \
_Note that each time you run this command the log files will be overwritten._

```bash
./manage.sh -n <network> -a logs export
```

---

### Ensure all images are up to date

```bash
./manage.sh -n <network> -a pull
```

### Delete all chainstate data

Some of the data in `./persistent-data/<network>` is owned by root, so this will need to run with **sudo** privileges.

```bash
sudo ./manage.sh -n <network> -a reset
```

### Download BNS data

Store legacy BNS data to `./persistent-data/bns-data` \
_This step is required if the env var `BNS_IMPORT_DIR` is uncommented_

```bash
./manage.sh bns
```
