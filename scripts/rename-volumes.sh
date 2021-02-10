#!/bin/bash

set -e
pushd . > /dev/null

EXTERNAL_VOLUME=~/subsocial_data
VOLUMES_UPDATED=false

set_external_volumes_names(){
  OFFCHAIN_STATE_OLD=$EXTERNAL_VOLUME/offchain_state
  OFFCHAIN_STATE_NEW=$EXTERNAL_VOLUME/offchain-state-$NEW_INSTANCE

  ELASTIC_PASSWORDS_OLD=$EXTERNAL_VOLUME/es_passwords
  ELASTIC_PASSWORDS_NEW=$EXTERNAL_VOLUME/es-passwords-$NEW_INSTANCE
}

rename_docker_volumes(){
  return 0
}

if [[ -z $1 || $1 == "--help" || $1 == "-h" ]]; then
  printf "\033[0;31mInstance name should be specified.\n\033[00mExamples:"
  printf "\033[0;33mRename old volumes to the new format:\033[00m ./rename-external-volumes.sh subsocial"
  printf "\033[0;33mRename instance A to instance B:\033[00m ./rename-external-volumes.sh instance-a instance-b"
  exit 1
fi

NEW_INSTANCE=$1
set_external_volumes_names

printf "\n\033[0;33mCurrent file names are:\033[00m\n"
ls $EXTERNAL_VOLUME

if [[ -d $OFFCHAIN_STATE_OLD || -f $ELASTIC_PASSWORDS_OLD ]]; then
  echo "Sudo rights could be needed..." && sudo ls $EXTERNAL_VOLUME > /dev/null

  [[ -d $OFFCHAIN_STATE_OLD ]] && sudo mv $OFFCHAIN_STATE_OLD "$OFFCHAIN_STATE_NEW"
  [[ -f $ELASTIC_PASSWORDS_OLD ]] && sudo mv $ELASTIC_PASSWORDS_OLD "$ELASTIC_PASSWORDS_NEW"

  VOLUMES_UPDATED=true
fi

# if [[ -n $2 ]]; then
#   OLD_INSTANCE=$1
#   NEW_INSTANCE=$2

#   # node_rpc_data
#   # node_validator_data
#   # caddy_certs
#   # es_data
#   # postgres_data

#   VOLUMES_UPDATED=true
# fi

if [[ $VOLUMES_UPDATED == "true" ]]; then
  printf "\n\033[0;33mDone. New file names are:\033[00m\n"
  ls $EXTERNAL_VOLUME
fi

popd > /dev/null
exit 0
