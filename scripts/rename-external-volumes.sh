#!/bin/bash

set -e
pushd . > /dev/null

if [[ -z $1 ]]; then
  printf "Instance name should be specified.\nExample: ./rename-external-volumes.sh subsocial"
  exit 1
fi

PROJECT_NAME=$1
EXTERNAL_VOLUME=~/subsocial_data

echo "Sudo rights could be needed..."
echo "Old file names are:"
sudo ls $EXTERNAL_VOLUME

OFFCHAIN_STATE_OLD=$EXTERNAL_VOLUME/offchain_state
OFFCHAIN_STATE_NEW=$EXTERNAL_VOLUME/offchain-state-$PROJECT_NAME

ELASTIC_PASSWORDS_OLD=$EXTERNAL_VOLUME/es_passwords
ELASTIC_PASSWORDS_NEW=$EXTERNAL_VOLUME/es-passwords-$PROJECT_NAME

[[ -d $OFFCHAIN_STATE_OLD ]] && sudo mv $OFFCHAIN_STATE_OLD "$OFFCHAIN_STATE_NEW"
[[ -f $ELASTIC_PASSWORDS_OLD ]] && sudo mv $ELASTIC_PASSWORDS_OLD "$ELASTIC_PASSWORDS_NEW"

echo "Done. New file names are:"
sudo ls $EXTERNAL_VOLUME

popd > /dev/null
exit 0
