#!/bin/bash

set -e
pushd . > /dev/null

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

if [[ ! -f ".env" ]]; then
  echo "Error: .env file is missing in hydra-indexer directory"
  exit 1
fi

DOWN_FLAGS="down"
if [[ $1 == "--stop" ]]; then
  [[ $2 == "--clean" ]] && DOWN_FLAGS+=" -v"
  docker-compose -p hydra $DOWN_FLAGS
  exit 0
fi

echo "Running docker-compose of Hydra Indexer for Subsocial..."
docker-compose -p hydra up -d

popd > /dev/null
