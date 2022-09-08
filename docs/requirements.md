# Requirements

- [Docker](https://docs.docker.com/get-docker/) >= `20.10.12`
- [docker-compose](https://github.com/docker/compose/releases/) >= `2.2.2`
- [git](https://git-scm.com/downloads)
- [jq binary](https://stedolan.github.io/jq/download/)
- [sed](https://www.gnu.org/software/sed/)
- Host with a minimum of:
  - 4GB memory
  - 1 Vcpu (2 Vcpu is recommended)
  - 100GB storage

## **MacOS with an M1 processor is _NOT_ recommended for this repo**

⚠️ The way Docker for Mac on an M1 (Arm) chip is designed makes the I/O incredibly slow, and blockchains are **_very_** heavy on I/O. \
This only seems to affect MacOS, other Arm based systems like Raspberry Pi seem to work fine.
