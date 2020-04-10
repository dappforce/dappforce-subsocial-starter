#!/usr/bin/env bash
set -e

pushd . > /dev/null

# The following lines ensure we run from the root
DIR=`git rev-parse --show-toplevel`
COMPOSE_DIR="${DIR}/compose-files"

# Default props
export IP=${IP:-127.0.0.1}
export PROJECT_NAME="subsocial"
export FORCEPULL="false"
export VOLUME_LOCATION=~/subsocial_data

# Version variables
export POSTGRES_VERSION=${POSTGRES_VERSION:-latest}
export ELASTICSEARCH_VERSION=${ELASTICSEARCH_VERSION:-7.4.1}
export IPFS_VERSION=${IPFS_VERSION:-master-latest}
export OFFCHAIN_VERSION=${OFFCHAIN_VERSION:-latest}
export NODE_VERSION=${NODE_VERSION:-latest}
export WEBUI_VERSION=${WEBUI_VERSION:-latest}
export APPS_VERSION=${APPS_VERSION:-latest}
export PROXY_VERSION=${PROXY_VERSION:-latest}

# URL variables
export SUBSTRATE_URL=${SUBSTRATE_URL:-ws://172.15.0.21:9944}
export OFFCHAIN_URL=${OFFCHAIN_URL:-http://172.15.0.3:3001}
export ELASTIC_URL=${ELASTIC_URL:-http://172.15.0.5:9200}
export IPFS_URL=${IPFS_URL:-/ip4/172.15.0.8/tcp/5001}
export IPFS_READONLY_URL=${IPFS_READONLY_URL:-/ip4/172.15.0.8/tcp/8080}
export WEBUI_IP=${WEBUI_IP:-127.0.0.1:80}
export APPS_URL=${APPS_URL:-http://127.0.0.1/bc}

# Container names
export CONT_POSTGRES=${PROJECT_NAME}-postgres
export CONT_ELASTICSEARCH=${PROJECT_NAME}-elasticsearch
export CONT_IPFS=${PROJECT_NAME}-ipfs
export CONT_OFFCHAIN=${PROJECT_NAME}-offchain
export CONT_NODE_ALICE=${PROJECT_NAME}-node-alice
export CONT_NODE_BOB=${PROJECT_NAME}-node-bob
export CONT_WEBUI=${PROJECT_NAME}-web-ui
export CONT_APPS=${PROJECT_NAME}-apps
export CONT_PROXY=${PROJECT_NAME}-proxy

# Compose files list
COMPOSE_FILES=""
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/offchain.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/substrate_node.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/web_ui.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/apps.yml"

SUBSTRATE_NODE_EXTRA_OPTS="${SUBSTRATE_NODE_EXTRA_OPTS:-}"

# colors
COLOR_R="\033[0;31m"    # red
COLOR_Y="\033[0;33m"    # yellow

# reset
COLOR_RESET="\033[00m"

parse_substrate_extra_opts(){
    while :; do
        if ! [[ -z $2 ]] ; then
            SUBSTRATE_NODE_EXTRA_OPTS+=$1' '
            shift
        else
            break;
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

            export IP=$(curl -s ifconfig.me)

            export SUBSTRATE_URL='ws://'$IP':9944'
            export OFFCHAIN_URL='http://'$IP':3001'
            export ELASTIC_URL='http://'$IP':9200'
            export WEBUI_IP=$IP':80'
            export APPS_URL='http://'$IP'/bc'
            export IPFS_READONLY_URL='/ip4/'$IP'/tcp/8080'

            printf $COLOR_Y'Starting globally...\n\n'$COLOR_RESET
            ;;

        # Pull latest changes by tag (ref. 'Version variables' or '--tag')
        --force-pull)
            export FORCEPULL="true"
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
            printf $COLOR_Y'Doing a deep clean ...\n\n'$COLOR_RESET
            eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" down

            # Include volumes pruning
            if [[ $2 == "all-volumes" ]] ; then
                docker volume rm ${PROJECT_NAME}_es_data || true
                docker volume rm ${PROJECT_NAME}_postgres_data || true
                shift
            fi

            printf "\nProject pruned successfully\n"
            break;
            ;;

        #################################################
        # Exclude switches
        #################################################

        --no-offchain)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/offchain.yml/}"
            printf $COLOR_Y'Starting without Offchain...\n\n'$COLOR_RESET
            ;;

        --no-substrate)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/substrate_node.yml/}"
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

        #################################################
        # Include-only switches
        #################################################

        --only-offchain)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/offchain.yml"
            printf $COLOR_Y'Starting only Offchain...\n\n'$COLOR_RESET
            ;;

        --only-substrate)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/substrate_node.yml"
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

        #################################################
        # Specify component's URLs (ref. 'URL variables')
        #################################################

        --substrate-url)
            if [ -z $2 ] || [[ $2 =~ --.* ]] || ! [[ $2 =~ wss?://.*:.* ]] ; then
                printf $COLOR_R'WARN: --substrate-url must be provided with an ws(s)://IP:PORT argument\n'$COLOR_RESET "$1" >&2
                break;
            else
                export SUBSTRATE_URL=$2
                printf $COLOR_Y'Substrate URL set to '$SUBSTRATE_URL'\n\n'$COLOR_RESET
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

        # WIP:
        --substrate-extra-opts)
            if [ -z $2 ] ; then
                printf $COLOR_R'WARN: --substrate-extra-opts must be provided with arguments\n'$COLOR_RESET "$1" >&2
                break;
            else
                parse_substrate_extra_opts $2
                printf "$SUBSTRATE_NODE_EXTRA_OPTS"';'
            fi
            ;;
        #

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
            printf $COLOR_Y'Starting Subsocial...\n\n'$COLOR_RESET
            [ ${FORCEPULL} = "true" ] && eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" pull
            time (
                eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" up -d

                if [[ $COMPOSE_FILES =~ 'offchain' ]] ; then

                    # Elasticsearch
                    printf "\nHold on, starting Offchain:\nSetting up ElasticSearch...\n"
                    docker container stop ${CONT_OFFCHAIN} > /dev/null
                    until curl -s ${ELASTIC_URL} > /dev/null ; do
                        sleep 2
                    done

                    # IPFS
                    printf "Setting up IPFS...\n"
                    docker exec ${CONT_IPFS} \
                        ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
                    docker exec ${CONT_IPFS} \
                        ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "GET", "POST"]'
                    docker restart ${CONT_IPFS} > /dev/null

                    # Offchain itself
                    docker container start ${CONT_OFFCHAIN} > /dev/null
                    printf 'Offchain successfully started\n'
                fi

                if [[ $COMPOSE_FILES =~ 'web_ui' ]] ; then
                    printf "\nWaiting for Web UI to start...\n"
                    until curl -s ${WEBUI_IP} > /dev/null ; do
                        sleep 2
                    done 

                    printf 'Web UI is accessible on '$WEBUI_IP'\n'
                fi
            )
            printf 'Containers are ready.\n'
            break

    esac
    shift
done

popd > /dev/null
