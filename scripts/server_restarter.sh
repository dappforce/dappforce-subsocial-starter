#!/usr/bin/env bash

WEBUI_CONT=subsocial-web-ui
SUBSTRATE_CONT=subsocial-node-alice
STORAGE=last_log_line.txt

while :; do

  # Check UI for disconnect
  docker logs --tail 1 $WEBUI_CONT >& $STORAGE
  LOG_STR=$(cat $STORAGE)
  
  if [[ "$LOG_STR" == *"disconnected"* ]] ; then
    eval docker restart $WEBUI_CONT
  fi

  # Check Substrate node for Capacity error
  docker logs --tail 5 $SUBSTRATE_CONT >& $STORAGE
  LOG_STR=$(cat $STORAGE)
  echo LOG_STR
  
  if [[ "$LOG_STR" == *"<Capacity>"* ]] ; then
    eval docker restart $SUBSTRATE_CONT
  fi

  sleep 5
done
