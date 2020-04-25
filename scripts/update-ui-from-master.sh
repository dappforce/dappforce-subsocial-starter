#!/bin/bash

set -e
pushd . > /dev/null

TAG=$(docker ps | grep subsocial-ui | cut -d ':' -f 2 | cut -d ' ' -f 1)
if [ -z $TAG ]; then
  printf '\033[0;31mWARN:\033[00m Web UI must be running to execute this script\n' >&2
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR\/..

echo "Running start.sh with: --tag ${TAG} --global --only-webui --force-pull"
eval ./start.sh --tag $TAG --global --only-webui --force-pull

echo "Cleaning deprecated images..."
eval docker system prune -f

popd > /dev/null
exit 0
