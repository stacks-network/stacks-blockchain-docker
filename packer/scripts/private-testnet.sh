#!/bin/sh
echo === Cloning stacks-blockchain-docker ===
git clone -b private-testnet  --depth 1 https://github.com/stacks-network/stacks-blockchain-docker /stacks-blockchain-docker
ln -s /stacks-blockchain-docker/sample.env /stacks-blockchain-docker/.env

echo === Adding testnet unit-file ===
cat <<EOF> /etc/systemd/system/testnet.service
# testnet.service
[Unit]
Description=Private Testnet Service
After=docker.service
ConditionFileIsExecutable=/usr/local/bin/docker-compose

[Service]
WorkingDirectory=/stacks-blockchain-docker
TimeoutStartSec=0
Restart=on-failure
RemainAfterExit=yes
RestartSec=30
ExecStartPre=-/bin/bash manage.sh private-testnet pull
ExecStart=/bin/bash manage.sh private-testnet up

ExecStop=-/bin/bash manage.sh private-testnet down
ExecReload=-/bin/bash manage.sh private-testnet restart

[Install]
WantedBy=testnet.service
EOF

systemctl daemon-reload
sudo systemctl disable testnet.service
