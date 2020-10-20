#/bin/sh
echo ""
echo  "Generating keychain as file: '.stx_keychain'"
npx blockstack-cli@1.1.0-beta.1 make_keychain -t > .stx_keychain 2>/dev/null
echo  "Setting local vars from .env file"
export $(grep -v '^#' .env | xargs)
echo  "Retrieving private seed from keychain"
if [ ! -f .stx_keychain ]; then
  echo ""
  echo "*********************************"
  echo "Error:"
  echo "  File .stx_keychain wasn't created"
  echo "    Manually Run: npx blockstack-cli@1.1.0-beta.1 make_keychain -t > .stx_keychain"
  echo "    And note any error output"
  exit 1
fi
export PRIVATE_KEY=$(cat .stx_keychain | jq .keyInfo.privateKey | tr -d '"')
# PUBLIC_KEY=$(cat .stx_keychain | jq .keyInfo.publicKey | tr -d '"')

if [ ! $PRIVATE_KEY ]; then
  echo ""
  echo "*********************************"
  echo "Error:"
  echo "  Private Key missing from .stx_keychain"
  echo "    Likely there were errors creating the file."
  echo "    Manually Run: npx blockstack-cli@1.1.0-beta.1 make_keychain -t"
  echo "    And note any error output"
  exit 2
fi

echo "Updating configs with values from files: .env, .stx_keychain"
envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
  < stacks-node-follower/Config.toml.template \
  > stacks-node-follower/Config.toml
envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
  < stacks-node-miner/Config.toml.template \
  > stacks-node-miner/Config.toml

echo  "Unsetting local vars from .env file"
unset $(grep -v '^#' .env | sed -E 's/(.*)=.*/\1/' | xargs)
unset PRIVATE_KEY
echo "Now, run:"
echo "  docker-compose up -d"
echo "  Hint: to stop everything, run 'docker-compose down'"
echo ""
exit 0
