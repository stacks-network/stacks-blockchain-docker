#!/bin/sh

VERSION=$(curl -sL https://api.github.com/repos/stacks-network/stacks-blockchain/releases/latest | jq .tag_name | tr -d '"')
echo "Setting Version to ${VERSION}"
echo ""
echo "Building private-testnet"
echo "    version: ${VERSION}"
packer build --var-file=vars.json --var "version=${VERSION}" private-testnet.json

