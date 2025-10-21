# Docker

- [Install Docker Compose](https://docs.docker.com/compose/install/)
- [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/install/)
- [Docker Desktop for Windows](https://docs.docker.com/docker-for-windows/install/)
- [Docker Engine for Linux](https://docs.docker.com/desktop/install/linux-install/#generic-installation-steps)

## Verify `docker compose` is installed locally

`docker compose` version `2.2.2` or greater is required:

```bash
$ docker compose version
Docker Compose version v2.2.2
```

## Install/Upgrade docker compose

If the command is not found, or the version is less than `2.2.2`, follow the [official Docker Compose installation instructions](https://docs.docker.com/compose/install/) for your platform.

For Docker Desktop users (Mac/Windows), Compose is included by default.

For Linux users, install the docker-compose-plugin:

```bash
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

## Security note on docker

The Docker daemon always runs as the root user so you will need root privileges to interact with it.

The script `manage.sh` uses docker, so to avoid the requirement of needing to run the script with root privileges it is prefered to be able to _manage Docker as a non-root user_ by following [these steps](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user).

This will avoid the need of running the script with root privileges for all operations **except** the removal of data.

## Debian based install

Copy/paste the following _should_ work to get docker and other requirements setup on a Debian based host

```bash
sudo apt-get update && sudo apt-get install -y git jq sed curl
sudo apt remove docker-desktop
rm -r $HOME/.docker/desktop
sudo rm /usr/local/bin/com.docker.cli
sudo apt purge docker-desktop
sudo apt-get update
sudo apt-get install -y ca-certificates     curl     gnupg     lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo groupadd docker
sudo usermod -aG docker $USER
```
