#!/bin/bash

set -e
pushd . > /dev/null

if [ -z $1 ]; then
  bold=$(tput bold)
  normal=$(tput sgr0)
  echo "${bold}Usage:${normal} update-ui-from-master TAG [--global]"
  exit 1
else
  TAG=$1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR\/..

DIR=dappforce-subsocial-ui

git clone --depth 1 https://github.com/dappforce/dappforce-subsocial-ui.git $DIR
docker build --no-cache -f $DIR/docker/Dockerfile -t dappforce/subsocial-ui:$TAG $DIR

IS_GLOBAL=[ ${2} = "--global"] && $2
eval ./start.sh --tag $1 $IS_GLOBAL

echo "Cleaning build cache and deprecated images..."
rm -rf $DIR
eval docker system prune -f

popd > /dev/null
exit 0
