#!/bin/bash

set -e
pushd . > /dev/null

EXTERNAL_VOLUME=~/subsocial_data
VOLUMES_UPDATED=false

SUBSTRATE_RPC_DATA=node_rpc_data
SUBSTRATE_VALIDATOR_DATA=node_validator_data
CADDY_CERTS=caddy_certs
ELASTICSEARCH_DATA=es_data
POSTGRES_DATA=postgres_data

ELASTIC_PASSWORDS=$EXTERNAL_VOLUME/es-passwords
OFFCHAIN_STATE=$EXTERNAL_VOLUME/offchain-state

set_external_volumes_names(){
  OFFCHAIN_STATE_OLD=$EXTERNAL_VOLUME/offchain_state
  OFFCHAIN_STATE_NEW=$OFFCHAIN_STATE-$NEW_INSTANCE

  ELASTIC_PASSWORDS_OLD=$EXTERNAL_VOLUME/es_passwords
  ELASTIC_PASSWORDS_NEW=$ELASTIC_PASSWORDS-$NEW_INSTANCE
}

rename_docker_volume(){
  if [[ -z $1 || -z $OLD_INSTANCE || -z $NEW_INSTANCE ]]; then
    printf "\033[0;31mIncorrect usage of rename_docker_volume function\n\033[00m"
  fi

  local old_volume=${OLD_INSTANCE}_$1
  local new_volume=${NEW_INSTANCE}_$1

  if ! docker volume inspect "$old_volume" > /dev/null 2> /dev/null; then
    return 0
  fi

  if docker volume inspect "$new_volume" > /dev/null 2> /dev/null; then
    printf "\033[0;31mThe destination volume %s already exists. You should manually remove it.\n\033[00m" "$new_volume"
    exit 1
  fi

  printf '\nCreating destination volume "%s"...\n' "$new_volume"
  docker volume create --name "$new_volume" > /dev/null
  printf 'Copying data from source volume "%s" to destination volume "%s"...\n' "$old_volume" "$new_volume"
  docker run --rm \
    -it \
    -v $old_volume:/from -v $new_volume:/to \
    alpine ash -c "cd /from ; cp -av . /to" > /dev/null
}

rename_offchain_volume(){
  if [[ -z $1 || -z $2 ]]; then
    printf "\033[0;31mIncorrect usage of rename_offchain_volume function\n\033[00m"
  fi

  local volume_old=$1
  local volume_new=$2

  if [[ -d $volume_old ]]; then
    sudo mv "$volume_old" "$volume_new"
    printf "External volume %s successfully renamed to %s\n" "$volume_old" "$volume_new"
  fi
}

rename_elastic_volume(){
  if [[ -z $1 || -z $2 ]]; then
    printf "\033[0;31mIncorrect usage of rename_elastic_volume function\n\033[00m"
  fi

  local volume_old=$1
  local volume_new=$2

  if [[ -f $volume_old ]]; then
    sudo mv "$volume_old" "$volume_new"
    printf "External volume %s successfully renamed to %s\n" "$volume_old" "$volume_new"
  fi
}


if [[ -z $1 || $1 == "--help" || $1 == "-h" ]]; then
  printf "\033[0;31mInstance name should be specified.\n\033[00mExamples:"
  printf "\033[0;33mRename old volumes to the new format:\033[00m ./rename-external-volumes.sh subsocial"
  printf "\033[0;33mRename instance A to instance B:\033[00m ./rename-external-volumes.sh instance-a instance-b"
  exit 1
fi

NEW_INSTANCE=$1

printf "\n\033[0;33mCurrent file names are:\033[00m\n"
ls $EXTERNAL_VOLUME

if [[ -d $OFFCHAIN_STATE_OLD || -f $ELASTIC_PASSWORDS_OLD ]]; then
  echo "Sudo rights could be needed..." && sudo ls $EXTERNAL_VOLUME > /dev/null

  set_external_volumes_names

  rename_offchain_volume $OFFCHAIN_STATE_OLD "$OFFCHAIN_STATE_NEW"
  rename_elastic_volume $ELASTIC_PASSWORDS_OLD "$ELASTIC_PASSWORDS_NEW"

  VOLUMES_UPDATED=true
fi

if [[ -n $2 ]]; then
  OLD_INSTANCE=$1
  NEW_INSTANCE=$2

  rename_docker_volume $SUBSTRATE_RPC_DATA
  rename_docker_volume $SUBSTRATE_VALIDATOR_DATA
  rename_docker_volume $CADDY_CERTS
  rename_docker_volume $ELASTICSEARCH_DATA
  rename_docker_volume $POSTGRES_DATA

  set_external_volumes_names

  echo ""

  rename_offchain_volume "$OFFCHAIN_STATE-$OLD_INSTANCE" "$OFFCHAIN_STATE-$NEW_INSTANCE"
  rename_elastic_volume "$ELASTIC_PASSWORDS-$OLD_INSTANCE" "$ELASTIC_PASSWORDS-$NEW_INSTANCE"

  VOLUMES_UPDATED=true
fi

if [[ $VOLUMES_UPDATED == "true" ]]; then
  printf "\n\033[0;33mDone. New file names are:\033[00m\n"
  ls $EXTERNAL_VOLUME
fi

popd > /dev/null
exit 0
