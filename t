NETWORK="mainnet"
PROFILE="stacks-blockchain"
PROFILE="bns"

if [[ "${NETWORK}" == "mainnet" || "${NETWORK}" == "testnet" ]] && [ "${PROFILE}" != "bns" ]; then
  echo "network: $NETWORK"
  echo "profile: $PROFILE"
fi