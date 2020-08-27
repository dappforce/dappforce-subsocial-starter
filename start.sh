#!/bin/bash

set -e
pushd . > /dev/null

# The following lines ensure we run from the root folder of this Starter
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
COMPOSE_DIR="${DIR}/compose-files"

# Default props
export IP=127.0.0.1
WEBUI_IP=127.0.0.1:80

PROJECT_NAME="subsocial"
FORCEPULL="false"
export EXTERNAL_VOLUME=~/subsocial_data
PRUNING_MODE="none"

# Generated new IPFS Cluster secret in case the ipfs-data was cleaned
export CLUSTER_SECRET=$(od  -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')

# Other IPFS Cluster variables
export CLUSTER_BOOTSTRAP=""
export CLUSTER_CONFIG_FOLDER="${EXTERNAL_VOLUME}/ipfs/cluster"

# Version variables
export POSTGRES_VERSION=latest
export ELASTICSEARCH_VERSION=7.4.1
export IPFS_CLUSTER_VERSION=latest
export IPFS_NODE_VERSION=v0.5.1
export OFFCHAIN_VERSION=latest
export NODE_VERSION=latest
export WEBUI_VERSION=latest
export APPS_VERSION=latest
export PROXY_VERSION=latest

# Internal Docker IP variables
# [!] Update files in nginx folder if changed
export WEBUI_DOCKER_IP=172.15.0.2
export OFFCHAIN_IP=172.15.0.3
export POSTGRES_IP=172.15.0.4
export ELASTICSEARCH_IP=172.15.0.5
export JS_APPS_IP=172.15.0.6
export NGINX_PROXY_IP=172.15.0.7
export IPFS_NODE_IP=172.15.0.8
export IPFS_CLUSTER_IP=172.15.0.9
export SUBSTRATE_RPC_IP=172.15.0.21
export SUBSTRATE_VALIDATOR_IP=172.15.0.22

# URL variables
export SUBSTRATE_RPC_URL=ws://$SUBSTRATE_RPC_IP:9944
export OFFCHAIN_URL=http://$OFFCHAIN_IP:3001
export ELASTIC_URL=http://$ELASTICSEARCH_IP:9200
export IPFS_URL=http://$IPFS_CLUSTER_IP:9094
export IPFS_READONLY_URL=http://$IPFS_NODE_IP:8080
export APPS_URL=http://127.0.0.1/bc
export OFFCHAIN_WS=ws://127.0.0.1:3011

# Container names
export CONT_POSTGRES=${PROJECT_NAME}-postgres
export CONT_ELASTICSEARCH=${PROJECT_NAME}-elasticsearch
export CONT_IPFS_CLUSTER=${PROJECT_NAME}-ipfs-cluster
export CONT_IPFS_NODE=${PROJECT_NAME}-ipfs-node
export CONT_OFFCHAIN=${PROJECT_NAME}-offchain
export CONT_NODE_RPC=${PROJECT_NAME}-node-rpc
export CONT_NODE_VALIDATOR=${PROJECT_NAME}-node-validator
export CONT_WEBUI=${PROJECT_NAME}-web-ui
export CONT_APPS=${PROJECT_NAME}-apps
export CONT_PROXY=${PROJECT_NAME}-proxy

# Compose files list
SUBSTRATE_RPC_COMPOSE=" -f ${COMPOSE_DIR}/substrate/substrate_rpc.yml"
SUBSTRATE_VALIDATOR_COMPOSE=" -f ${COMPOSE_DIR}/substrate/substrate_validator.yml"

SELECTED_SUBSTRATE=${SUBSTRATE_RPC_COMPOSE}${SUBSTRATE_VALIDATOR_COMPOSE}

COMPOSE_FILES=""
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/offchain.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/ipfs.yml"
COMPOSE_FILES+=${SELECTED_SUBSTRATE}
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/nginx_proxy.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/web_ui.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/apps.yml"

export SUBSTRATE_NODE_EXTRA_OPTS=""

# colors
COLOR_R="\033[0;31m"    # red
COLOR_Y="\033[0;33m"    # yellow

# reset
COLOR_RESET="\033[00m"

parse_substrate_extra_opts(){
    while :; do
        if [ -z $1 ] ; then
            break;
        else
            SUBSTRATE_NODE_EXTRA_OPTS+=' '$1
            shift
        fi
    done
}

write_boostrap_peers(){
    printf "\nIPFS Cluster peers:\n"
    while :; do
        if [ -z $1 ] ; then
            break;
        else
            printf $1'\n'
            shift
        fi
    done
}

while :; do
    case $1 in

        #################################################
        # Misc
        #################################################

        # Start binding components to global ip
        --global)

            IP=$(curl -s ifconfig.me)

            SUBSTRATE_RPC_URL='ws://'$IP':9944'
            OFFCHAIN_URL='http://'$IP':3001'
            ELASTIC_URL='http://'$IP':9200'
            WEBUI_IP=$IP':80'
            APPS_URL='http://'$IP'/bc'
            IPFS_READONLY_URL='http://'$IP':8080'
            OFFCHAIN_WS='ws://'$IP':3011'

            printf $COLOR_Y'Starting globally...\n\n'$COLOR_RESET
            ;;

        # Pull latest changes by tag (ref. 'Version variables' or '--tag')
        --force-pull)
            FORCEPULL="true"
            printf $COLOR_Y'Pulling the latest revision of the used Docker images...\n\n'$COLOR_RESET
            ;;

        # Specify docker images tag
        --tag)
            if [ -z $2 ] || [[ $2 == *'--'* ]] ; then
                printf $COLOR_R'WARN: --tag must be provided with a tag name argument\n'$COLOR_RESET "$1" >&2
                break;
            else
                export OFFCHAIN_VERSION=$2
                export NODE_VERSION=$2
                export WEBUI_VERSION=$2
                export APPS_VERSION=$2
                printf $COLOR_Y'Switched to components by tag '$2'\n\n'$COLOR_RESET
                shift
            fi
            ;;

        # Delete project's docker containers
        --prune)
            if [[ $2 == "all-volumes" ]] ; then PRUNING_MODE=$2
            else PRUNING_MODE="default"
            fi
            ;;

        #################################################
        # Exclude switches
        #################################################

        --no-offchain)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/offchain.yml/}"
            printf $COLOR_Y'Starting without Offchain...\n\n'$COLOR_RESET
            ;;

        --no-substrate)
            COMPOSE_FILES="${COMPOSE_FILES/${SELECTED_SUBSTRATE}/}"
            printf $COLOR_Y'Starting without Substrate Nodes...\n\n'$COLOR_RESET
            ;;

        --no-webui)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/web_ui.yml/}"
            printf $COLOR_Y'Starting without Web UI...\n\n'$COLOR_RESET
            ;;

        --no-apps)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/apps.yml/}"
            printf $COLOR_Y'Starting without JS Apps...\n\n'$COLOR_RESET
            ;;

        --no-ipfs)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/ipfs.yml/}"
            printf $COLOR_Y'Starting without IPFS Cluster...\n\n'$COLOR_RESET
            ;;

        #################################################
        # Include-only switches
        #################################################

        --only-offchain)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/offchain.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/ipfs.yml"
            printf $COLOR_Y'Starting only Offchain...\n\n'$COLOR_RESET
            ;;

        --only-substrate)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
            COMPOSE_FILES+=${SELECTED_SUBSTRATE}
            printf $COLOR_Y'Starting only Substrate...\n\n'$COLOR_RESET
            ;;

        --only-webui)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/web_ui.yml"
            printf $COLOR_Y'Starting only Web UI...\n\n'$COLOR_RESET
            ;;

        --only-apps)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/apps.yml"
            printf $COLOR_Y'Starting only JS Apps...\n\n'$COLOR_RESET
            ;;

        --only-proxy)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/nginx_proxy.yml"
            printf $COLOR_Y'Starting only Nginx proxy...\n\n'$COLOR_RESET
            ;;

        --only-ipfs)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/ipfs.yml"
            printf $COLOR_Y'Starting only IPFS cluster...\n\n'$COLOR_RESET
            ;;

        #################################################
        # Specify component's URLs (ref. 'URL variables')
        #################################################

        --substrate-url)
            if [ -z $2 ] || [[ $2 =~ --.* ]] || ! [[ $2 =~ wss?://.*:.* ]] ; then
                printf $COLOR_R'WARN: --substrate-url must be provided with an ws(s)://IP:PORT argument\n'$COLOR_RESET "$1" >&2
                break;
            else
                export SUBSTRATE_RPC_URL=$2
                printf $COLOR_Y'Substrate URL set to '$SUBSTRATE_RPC_URL'\n\n'$COLOR_RESET
                shift
            fi
            ;;

        --offchain-url)
            if [ -z $2 ] || ! [[ $2 =~ https?://.* ]] ; then
                printf $COLOR_R'WARN: --offchain-url must be provided with URL argument\n'$COLOR_RESET "$1" >&2
                break;
            else
                export OFFCHAIN_URL=$2
                printf $COLOR_Y'Offchain URL set to '$2'\n\n'$COLOR_RESET
                shift
            fi
            ;;

        --elastic-url)
            if [ -z $2 ] || ! [[ $2 =~ https?://.* ]] ; then
                printf $COLOR_R'WARN: --elastic-url must be provided with an URL argument\n'$COLOR_RESET "$1" >&2
                break;
            else
                export ELASTIC_URL=$2
                printf $COLOR_Y'Elasticsearch URL set to '$2'\n\n'$COLOR_RESET
                shift
            fi
            ;;

        --webui-ip)
            if [ -z $2 ] || [[ $2 =~ --.* ]] ; then
                printf $COLOR_R'WARN: --webui-ip must be provided with an IP:PORT argument\n'$COLOR_RESET "$1" >&2
                break;
            else
                export WEBUI_IP=$2
                printf $COLOR_Y'Web UI IP set to '$2'\n\n'$COLOR_RESET
                shift
            fi
            ;;

        --apps-url)
            if [ -z $2 ] || ! [[ $2 =~ https?://.* ]] ; then
                printf $COLOR_R'WARN: --apps-url must be provided with an URL argument\n'$COLOR_RESET "$1" >&2
                break;
            else
                export APPS_URL=$2
                printf $COLOR_Y'JS Apps URL set to '$2'\n\n'$COLOR_RESET
                shift
            fi
            ;;

        #################################################
        # Extra options for substrate node
        #################################################

        --substrate-extra-opts)
            if [[ -z $2 ]] ; then
                printf $COLOR_R'WARN: --substrate-extra-opts must be provided with arguments string\n'$COLOR_RESET "$1" >&2
                break;
            # elif [[ $2 =~ ^\"*\" ]]; then
            #     printf 'Usage example: '$COLOR_Y'--substrate-extra-opts "--name node --validator"\n'$COLOR_RESET >&2
            #     break;
            else
                parse_substrate_extra_opts $2
                shift
            fi
            ;;

        --substrate-mode)
            if [ -z $2 ] ; then
                printf $COLOR_R'USAGE: --substrate-mode (all/rpc/validator)\n'$COLOR_RESET "$1" >&2
                break;
            else
                COMPOSE_FILES="${COMPOSE_FILES/${SELECTED_SUBSTRATE}/}"
                case $2 in
                    all)
                        SELECTED_SUBSTRATE=${SUBSTRATE_RPC_COMPOSE}${SUBSTRATE_VALIDATOR_COMPOSE}
                        ;;
                    rpc)
                        SELECTED_SUBSTRATE=${SUBSTRATE_RPC_COMPOSE}
                        ;;
                    validator)
                        SELECTED_SUBSTRATE=${SUBSTRATE_VALIDATOR_COMPOSE}
                        ;;
                    -?*)
                        printf $COLOR_R'WARN: --substrate-mode provided with unknown option %s\n'$COLOR_RESET "$2" >&2
                        break
                        ;;
                esac
                shift
                COMPOSE_FILES+=${SELECTED_SUBSTRATE}
            fi
            ;;

        #################################################
        # Extra options for IPFS cluster
        #################################################

        --cluster-peers)
            docker exec subsocial-ipfs-cluster ipfs-cluster-ctl peers ls
            break;
            ;;

        --cluster-bootstrap)
            if [[ -z $2 ]] ; then
                printf $COLOR_R'WARN: --cluster-bootstrap must be provided with arguments string\n'$COLOR_RESET "$1" >&2
                break;
            else
                CLUSTER_BOOTSTRAP=$2
                shift
            fi
            ;;

        --cluster-identity-path)
            if [[ -z $2 ]]; then
                printf $COLOR_R'WARN: --cluster-identity-path must be provided with path string\n'$COLOR_RESET "$1" >&2
                break;
            else
                mkdir -p $CLUSTER_CONFIG_FOLDER
                cp $2 $CLUSTER_CONFIG_FOLDER
            fi
            ;;

        #################################################

        --) # End of all options.
            shift
            break
            ;;

        -?*)
            printf $COLOR_R'WARN: Unknown option (ignored): %s\n'$COLOR_RESET "$1" >&2
            break
            ;;

        *)
            if [ ${PRUNING_MODE} != "none" ]; then
                printf $COLOR_Y'Doing a deep clean ...\n\n'$COLOR_RESET

                eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" down
                if [[ ${PRUNING_MODE} == "all-volumes" ]]; then
                    eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" down -v

                    printf $COLOR_Y'Cleaning IPFS data, root may be required.\n'$COLOR_RESET
                    sudo rm -rf $EXTERNAL_VOLUME || true
                fi

                printf "\nProject pruned successfully\n"
                break;
            fi

            printf $COLOR_Y'Starting Subsocial...\n\n'$COLOR_RESET
            
            # Cut out subsocial-proxy from images to be pulled
            PULL_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/nginx_proxy.yml/}"
            [ ${FORCEPULL} = "true" ] && eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" pull
            eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" up -d

            if [[ $COMPOSE_FILES =~ 'offchain' ]] ; then

                # Elasticsearch
                printf "\nHold on, starting Offchain:\nSetting up ElasticSearch...\n"
                docker container stop ${CONT_OFFCHAIN} > /dev/null
                until curl -s ${ELASTIC_URL} > /dev/null ; do
                    sleep 2
                done

                # Offchain itself
                docker container start ${CONT_OFFCHAIN} > /dev/null
                printf 'Offchain successfully started\n'
            fi

            if [[ $COMPOSE_FILES =~ 'ipfs' ]] ; then
                printf "Setting up IPFS\n"
                until (
                    docker exec ${CONT_IPFS_NODE} ipfs config --json \
                        API.HTTPHeaders.Access-Control-Allow-Origin \
                        '["'$IPFS_CLUSTER_IP'", "'$OFFCHAIN_URL'"]' 2> /dev/null &&
                    # docker exec ${CONT_IPFS_NODE} ipfs config --json \
                    #     API.HTTPHeaders.Access-Control-Allow-Methods '["GET"]' 2> /dev/null &&
                    docker restart ${CONT_IPFS_NODE} > /dev/null
                ); do
                    sleep 2
                done
                if [[ ! -z $CLUSTER_BOOTSTRAP ]]; then
                    write_boostrap_peers $CLUSTER_BOOTSTRAP
                    echo $CLUSTER_BOOTSTRAP >> $CLUSTER_CONFIG_FOLDER/peerstore
                    # eval cat $CLUSTER_CONFIG_FOLDER/peerstore
                    # docker commit --change \
                        # "CMD \"daemon --bootstrap "$CLUSTER_BOOTSTRAP"\"]" $CONT_IPFS_CLUSTER
                    docker restart ${CONT_IPFS_CLUSTER} > /dev/null
                fi
            fi

            if [[ $COMPOSE_FILES =~ 'web_ui' ]] ; then
                printf "\nWaiting for Web UI to start...\n"
                until curl -s ${WEBUI_IP} > /dev/null ; do
                    sleep 2
                done

                printf 'Web UI is accessible on '$WEBUI_IP'\n'
            fi
            printf 'Containers are ready.\n'
            break
    esac
    shift
done

popd > /dev/null
