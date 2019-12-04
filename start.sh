#!/usr/bin/env bash
set -e

pushd . > /dev/null

# The following lines ensure we run from the docker folder
IP=$(curl -s ifconfig.me)
DIR=`git rev-parse --show-toplevel`
COMPOSE_DIR="${DIR}/compose-files"

# Default props
export PROJECT_NAME="subsocial"
export FORCEPULL="false"
export VOLUME_LOCATION=~/subsocial_data

# Version variables
export POSTGRES_VERSION=${POSTGRES_VERSION:-latest}
export ELASTICSEARCH_VERSION=${ELASTICSEARCH_VERSION:-7.4.1}
export OFFCHAIN_VERSION=${OFFCHAIN_VERSION:-latest}
export NODE_VERSION=${NODE_VERSION:-latest}
export WEBUI_VERSION=${WEBUI_VERSION:-latest}

# URL variables
export SUBSTRATE_URL=${SUBSTRATE_URL:-ws://$IP:9944}
export OFFCHAIN_URL=${OFFCHAIN_URL:-http://$IP:3001}
export ELASTIC_URL=${ELASTIC_URL:-http://$IP:9200}
export WEBUI_IP=${WEBUI_IP:-$IP:80}

COMPOSE_FILES=""
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network_volumes.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/offchain.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/substrate_node.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/web_ui.yml"

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

            if [[ $2 == "--allvolumes" ]] ; then
                # docker volume rm ${PROJECT_NAME}_chain_data_alice || true
                # docker volume rm ${PROJECT_NAME}_chain_data_bob || true
                docker volume rm ${PROJECT_NAME}_es_data || true
                docker volume rm ${PROJECT_NAME}_postgres_data || true
                shift
            fi

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

        #################################################
        # Modify Web UI environmental variables
        #################################################

        --substrate-url)
            if [ -z $2 ] || [[ $2 =~ --.* ]] ; then
                printf $COLOR_R'WARN: --substrate-url must be provided with an IP:PORT argument\n'$COLOR_RESET "$1" >&2
                break;
            else
                export SUBSTRATE_URL='ws://'$2
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

        #################################################
        # Extra options for substrate node
        #################################################

        --substrate-extra-opts)
            if [ -z $2 ] ; then
                printf $COLOR_R'WARN: --substrate-extra-opts must be provided with arguments\n'$COLOR_RESET "$1" >&2
                break;
            else
                parse_substrate_extra_opts $2
                printf "$SUBSTRATE_NODE_EXTRA_OPTS"';'
            fi
            ;;

        #################################################
        # Start project locally
        #################################################

        --local)
            export SUBSTRATE_URL='ws://127.0.0.1:9944'
            export OFFCHAIN_URL='http://127.0.0.1:3001'
            export ELASTIC_URL='http://127.0.0.1:9200'
            export WEBUI_IP='127.0.0.1:80'

            printf $COLOR_Y'Starting locally...\n\n'$COLOR_RESET
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
            printf $COLOR_Y'Starting Subsocial...\n\n'$COLOR_RESET
            [ ${FORCEPULL} = "true" ] && eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" pull
            time (
                eval docker-compose --project-name=$PROJECT_NAME "$COMPOSE_FILES" up -d

                if [[ $COMPOSE_FILES =~ 'offchain' ]] ; then
                    eval docker container stop ${PROJECT_NAME}'_offchain_1' > /dev/null
                    printf "\nHold on, waiting for Elasticsearch, starting Offchain...\n"
                    until curl -s ${ELASTIC_URL} > /dev/null ; do
                        sleep 2
                    done
                    printf 'Started container '
                    eval docker container start ${PROJECT_NAME}'_offchain_1'
                fi

                if [[ $COMPOSE_FILES =~ 'web_ui' ]] ; then
                    printf "\nWaiting for Web UI to build...\n"
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
