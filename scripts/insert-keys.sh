#!/bin/bash

set -e

pushd . > /dev/null
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
AURA_JSON=$DIR/keys/aura.json
GRAN_JSON=$DIR/keys/gran.json

curl http://localhost:9934 -H "Content-Type:application/json;charset=utf-8" -d "@$AURA_JSON"
curl http://localhost:9934 -H "Content-Type:application/json;charset=utf-8" -d "@$GRAN_JSON"

popd > /dev/null
exit 0
