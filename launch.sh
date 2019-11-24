#!/usr/bin/env bash
set -e

pushd . > /dev/null

# The following lines ensure we run from the docker folder
DIR=`git rev-parse --show-toplevel`
COMPOSE_DIR="${DIR}/compose-files"

# Default props
export PROJECT_NAME="subsocial"

COMPOSE_FILES=""
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/substrate_node.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/next_ui.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/offchain.yml"

if [[ $1 = 'down' ]]
then
  eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" down
  exit 0
fi

time (
  echo "Starting Subsocial in background!"
  eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" up -d

  echo "Hang on, Offchain is starting..."
  # You have to restart container
  eval docker container restart -t 20 subsocial_offchain
)

printf "Containers are ready.\nWeb-UI is ready on localhost:3000\n"

popd > /dev/null
