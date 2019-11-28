#!/usr/bin/env bash
set -e

pushd . > /dev/null

# The following lines ensure we run from the docker folder
DIR=`git rev-parse --show-toplevel`
COMPOSE_DIR="${DIR}/compose-files"

# Default props
export PROJECT_NAME="subsocial"
export FORCEPULL="false"

export POSTGRES_VERSION=${POSTGRES_VERSION:-latest}
export ELASTICSEARCH_VERSION=${ELASTICSEARCH_VERSION:-7.4.1}
export OFFCHAIN_VERSION=${OFFCHAIN_VERSION:-latest}
export NODE_VERSION=${NODE_VERSION:-latest}
export WEBUI_VERSION=${WEBUI_VERSION:-latest}

COMPOSE_FILES=""
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/offchain.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/substrate_node.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/web_ui.yml"

# colors
COLOR_R="\033[0;31m"    # red
COLOR_Y="\033[0;33m"    # yellow

# reset
COLOR_RESET="\033[00m"

while :; do
    case $1 in
        --force-pull)
            export FORCEPULL="true"
            printf $COLOR_Y'Pulling the latest revision of the used Docker images...\n\n'$COLOR_RESET
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
        #################################################
        # Cleaning switches
        #################################################
        --prune)
            printf $COLOR_Y'Doing a deep clean ...\n\n'$COLOR_RESET
            eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" down
            docker volume rm ${PROJECT_NAME}_chain_data_alice || true
            docker volume rm ${PROJECT_NAME}_chain_data_bob || true
            docker volume rm ${PROJECT_NAME}_es_data || true
            docker volume rm ${PROJECT_NAME}_postgres_data || true

            printf "\nProject pruned successfully\n"
            break;
            ;;
        #################################################
        # Specify branch
        #################################################
        --tag)
            if [ -z $2 ] || [[ $2 == *'--'* ]] ; then
                printf $COLOR_R'WARN: --tag must be provided with a tag name argument\n'$COLOR_RESET "$1" >&2
                break;
            else
                export OFFCHAIN_VERSION=$2
                export NODE_VERSION=$2
                export WEBUI_VERSION=$2
                printf $COLOR_Y'Switched to components by tag '$2'\n\n'$COLOR_RESET
                shift
            fi
            ;;
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

                printf "\nHold on, waiting 30 sec for Elasticsearch, starting Offchain...\n"
                eval docker container restart ${PROJECT_NAME}'_offchain_1' > /dev/null
                eval docker container restart -t 20 ${PROJECT_NAME}'_offchain_1' > /dev/null
            )
            printf "Containers are ready.\nWeb UI is accessible on localhost:3000\n"
            break
    esac
    shift
done

popd > /dev/null
