#!/bin/bash

set -e
pushd . > /dev/null

if [[ -z $1 ]]; then
  printf "Instance name should be specified.\nExample: ./rename-external-volumes.sh subsocial"
  exit 1
fi

PROJECT_NAME=$1
EXTERNAL_VOLUME=~/subsocial_data

OFFCHAIN_STATE_OLD=$EXTERNAL_VOLUME/offchain_state
OFFCHAIN_STATE_NEW=$EXTERNAL_VOLUME/offchain-state-$PROJECT_NAME

ELASTIC_PASSWORDS_OLD=$EXTERNAL_VOLUME/es_passwords
ELASTIC_PASSWORDS_NEW=$EXTERNAL_VOLUME/es-passwords-$PROJECT_NAME

if [[ -d $OFFCHAIN_STATE_OLD || -f $ELASTIC_PASSWORDS_OLD ]]; then
  echo "Sudo rights could be needed..." && sudo ls $EXTERNAL_VOLUME > /dev/null

  printf "\n\033[0;33mOld file names are:\033[00m\n"
  sudo ls $EXTERNAL_VOLUME

  [[ -d $OFFCHAIN_STATE_OLD ]] && sudo mv $OFFCHAIN_STATE_OLD "$OFFCHAIN_STATE_NEW"
  [[ -f $ELASTIC_PASSWORDS_OLD ]] && sudo mv $ELASTIC_PASSWORDS_OLD "$ELASTIC_PASSWORDS_NEW"

  printf "\n\033[0;33mDone. New file names are:\033[00m\n"
  ls $EXTERNAL_VOLUME
fi

popd > /dev/null
exit 0
