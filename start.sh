#!/bin/bash

set -e
pushd . > /dev/null

# The following lines ensure we run from the root folder of this Starter
export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
COMPOSE_DIR="${DIR}/compose-files"

# Default props
export IP=127.0.0.1
export WEBUI_URL=http://$IP
export WEB_UI_LOG_LEVEL=info
export EXTERNAL_VOLUME=~/subsocial_data

PROJECT_NAME="subsocial"
FORCEPULL="false"
STOP_MODE="none"
DATA_STATUS_PRUNED="(data pruned)"
DATA_STATUS_SAVED="(data saved)"

# Generated new IPFS Cluster secret in case the ipfs-data was cleaned
export CLUSTER_SECRET=""

# Other IPFS Cluster variables
export CLUSTER_PEERNAME="Subsocial Cluster"
export CLUSTER_BOOTSTRAP=""
export CLUSTER_CONFIG_FOLDER="${EXTERNAL_VOLUME}/ipfs/cluster"
CLUSTER_CONFIG_PATH=$CLUSTER_CONFIG_FOLDER/service.json
export IPFS_CLUSTER_CONSENSUS="crdt"

# ElasticSearch related variables
ELASTIC_PASSWORDS_PATH=${EXTERNAL_VOLUME}/es_passwords
export ES_READONLY_USER="readonly"
export ES_READONLY_PASSWORD=""
export ES_OFFCHAIN_USER="offchain"
export ES_OFFCHAIN_PASSWORD=""

# Substrate related variables
export SUBSTRATE_NODE_EXTRA_OPTS=""

# Offchain related variables
export OFFCHAIN_CORS="http://localhost"
export OFFCHAIN_CUSTOM_CMD=""

# Docker images versions
export POSTGRES_VERSION=12.4
export ELASTICSEARCH_VERSION=7.4.1
export IPFS_CLUSTER_VERSION=v0.13.0
export IPFS_NODE_VERSION=v0.5.1
export OFFCHAIN_VERSION=latest
export NODE_VERSION=latest
export WEBUI_VERSION=latest

# Docker internal IP addresses
export WEBUI_DOCKER_IP=172.15.0.2
export OFFCHAIN_IP=172.15.0.3
export POSTGRES_IP=172.15.0.4
export ELASTICSEARCH_IP=172.15.0.5
export IPFS_NODE_IP=172.15.0.8
export IPFS_CLUSTER_IP=172.15.0.9
export SUBSTRATE_RPC_IP=172.15.0.21
export SUBSTRATE_VALIDATOR_IP=172.15.0.22

# URL variables
export SUBSTRATE_RPC_URL=ws://$SUBSTRATE_RPC_IP:9944
export OFFCHAIN_URL=http://$OFFCHAIN_IP:3001
export OFFCHAIN_WS=ws://127.0.0.1:3011
export ES_URL=http://$ELASTICSEARCH_IP:9200
export IPFS_CLUSTER_URL=http://$IPFS_CLUSTER_IP:9094
export IPFS_NODE_URL=http://$IPFS_NODE_IP:5001
export IPFS_READ_ONLY_NODE_URL=http://$IPFS_NODE_IP:8080

# Docker container names
export CONT_POSTGRES=${PROJECT_NAME}-postgres
export CONT_ELASTICSEARCH=${PROJECT_NAME}-elasticsearch
export CONT_IPFS_CLUSTER=${PROJECT_NAME}-ipfs-cluster
export CONT_IPFS_NODE=${PROJECT_NAME}-ipfs-node
export CONT_OFFCHAIN=${PROJECT_NAME}-offchain
export CONT_NODE_RPC=${PROJECT_NAME}-node-rpc
export CONT_NODE_VALIDATOR=${PROJECT_NAME}-node-validator
export CONT_WEBUI=${PROJECT_NAME}-web-ui
export CONT_PROXY=${PROJECT_NAME}-proxy

# Docker-compose files list
SUBSTRATE_RPC_COMPOSE=" -f ${COMPOSE_DIR}/substrate/substrate_rpc.yml"
SUBSTRATE_VALIDATOR_COMPOSE=" -f ${COMPOSE_DIR}/substrate/substrate_validator.yml"

SELECTED_SUBSTRATE=${SUBSTRATE_RPC_COMPOSE}${SUBSTRATE_VALIDATOR_COMPOSE}

COMPOSE_FILES=""
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/offchain.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/elasticsearch.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/ipfs.yml"
COMPOSE_FILES+=${SELECTED_SUBSTRATE}
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/caddy.yml"
COMPOSE_FILES+=" -f ${COMPOSE_DIR}/web_ui.yml"

# colors
COLOR_R="\033[0;31m"    # red
COLOR_Y="\033[0;33m"    # yellow

# reset
COLOR_RESET="\033[00m"

parse_substrate_extra_opts(){
    while :; do
        if [[ -z $1 ]]; then
            break
        else
            SUBSTRATE_NODE_EXTRA_OPTS+=' '$1
            shift
        fi
    done
}

write_boostrap_peers(){
    test_jq_installation

    printf "\nIPFS Cluster peers:\n"
    while :; do
        if [[ -z $1 ]]; then
            break
        else
            printf $1'\n'
            local temp_file_name=tmp.$$.json
            local new_trusted_peers_query=".cluster.peer_addresses += [$1]"
            jq "$new_trusted_peers_query" $CLUSTER_CONFIG_PATH > $temp_file_name
            mv $temp_file_name $CLUSTER_CONFIG_PATH
            shift
        fi
    done
}

wait_for_ipfs_node(){
    until curl -s ${IPFS_READ_ONLY_NODE_URL}/version > /dev/null; do
        sleep 1
    done
}

stop_container() {
    local cont_name=""

    [[ -z $1 ]] || [[ ! -z $2 ]] \
        && printf $COLOR_R"FATAL: 'stop_container' command must be provided with one argument" \
        && exit -1

    [[ $1 == offchain ]] && [[ $COMPOSE_FILES =~ 'offchain' ]] \
        && docker container stop ${CONT_OFFCHAIN} > /dev/null

    if [[ $COMPOSE_FILES =~ 'ipfs' ]]; then
        [[ $1 == ipfs-cluster ]] && cont_name=$CONT_IPFS_CLUSTER
        [[ $1 == ipfs-node ]] && cont_name=$CONT_IPFS_NODE

        [[ ! -z $cont_name ]] && docker container stop $cont_name > /dev/null \
            || echo "nothing to stop" > /dev/null
    fi
}

# Starts a container if the next conditions are met:
# - Corresponding service exists in $COMPOSE_FILES set
# - Container is paused at the moment
start_container(){
    local cont_name

    [[ -z $1 ]] || [[ ! -z $2 ]] \
        && printf $COLOR_R"FATAL: 'start_container' command must be provided with one argument" && exit -1

    [[ $1 == offchain ]] && [[ $COMPOSE_FILES =~ 'offchain' ]] \
        && cont_name=${CONT_OFFCHAIN}

    if [[ $COMPOSE_FILES =~ 'ipfs' ]]; then
        [[ $1 == ipfs-cluster ]] && cont_name=$CONT_IPFS_CLUSTER
        [[ $1 == ipfs-node ]] && cont_name=$CONT_IPFS_NODE
    fi

    local is_running=$(docker ps | grep -wi "${cont_name}")
    local exists=$(docker ps -a | grep -wi "${cont_name}")
    if [[ -z $exists ]]; then
        printf $COLOR_R"ERROR: container ${cont_name} doesn't exist\n"
        exit 1
    else
        [[ -z $is_running ]] && [[ ! -z $cont_name ]] \
            && docker container start $cont_name > /dev/null
    fi
}

recreate_container(){
    local recreate_allowed=""

    [[ -z $1 ]] || [[ ! -z $2 ]] \
        && printf $COLOR_R"FATAL: 'recreate_container' command must be provided with one argument" && exit -1

    [[ $1 == offchain && $COMPOSE_FILES =~ 'offchain' ]] \
        && recreate_allowed="true"

    [[ $1 == ipfs-cluster || $1 == ipfs-node ]] && [[ $COMPOSE_FILES =~ 'ipfs' ]] \
        && recreate_allowed="true"

    if [[ -z $recreate_allowed ]]; then
        printf $COLOR_R"ERROR: $1 cannot be restarted before corresponding service included"
        exit 1
    else
        exec_docker_compose up -d $1
    fi
}

create_subsocial_elastic_users(){
    local password
    local elastic_password=$(cat ${ELASTIC_PASSWORDS_PATH} | grep -wi 'elastic' | cut -d "=" -f2- | tr -d '[:space:]')

    curl -XPOST -su elastic:$elastic_password 'localhost:9200/_security/role/index_subsocial' \
    -H "Content-Type: application/json" --data-binary "@${DIR}/elastic/add_index_role.json" > /dev/null

    curl -XPOST -su elastic:$elastic_password 'localhost:9200/_security/role/read_subsocial' \
    -H "Content-Type: application/json" --data-binary "@${DIR}/elastic/add_read_role.json" > /dev/null

    password=$(od  -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')
    curl -XPOST -su elastic:$elastic_password 'localhost:9200/_security/user/'$ES_OFFCHAIN_USER'' \
    -H "Content-Type: application/json" -d '{ "password": "'$password'", "roles" : [ "index_subsocial" ] }' > /dev/null \
    && echo "PASSWORD offchain = $password" >> $ELASTIC_PASSWORDS_PATH

    password=$(od  -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')
    curl -XPOST -su elastic:$elastic_password 'localhost:9200/_security/user/'$ES_READONLY_USER'' \
    -H "Content-Type: application/json" -d '{ "password": "'$password'", "roles" : [ "read_subsocial" ] }' > /dev/null \
    && echo "PASSWORD readonly = $password" >> $ELASTIC_PASSWORDS_PATH
}

resolve_subsocial_elastic_passwords(){
    ES_OFFCHAIN_PASSWORD=$(cat ${ELASTIC_PASSWORDS_PATH} | grep -wi "$ES_OFFCHAIN_USER" | cut -d "=" -f2- | tr -d '[:space:]')
    ES_READONLY_PASSWORD=$(cat ${ELASTIC_PASSWORDS_PATH} | grep -wi "$ES_READONLY_USER" | cut -d "=" -f2- | tr -d '[:space:]')
    printf 'ElasticSearch passwords are set to offchain container\n\n'
}

exec_docker_compose(){
    [[ -z $1 ]] && printf $COLOR_R'FATAL: wrong usage of `exec_docker_compose`. Empty parameter $1\n'$COLOR_RESET \
        && exit -1

    docker-compose -p $PROJECT_NAME $COMPOSE_FILES $1 $2 $3 > /dev/null
}

test_jq_installation(){
    # Test whether jq is installed and install if not
    while ! type jq > /dev/null; do
        printf $COLOR_R'WARN: jq is not installed on your system.'$COLOR_RESET >&2
        printf 'Trying to install the jq, root permissions may be required...\n'
        sudo apt install jq
        break
    done
}

while :; do
    case $1 in

        #################################################
        # Misc
        #################################################

        # Start binding components to global ip
        # TODO: do we need this?
        --global)

            IP=$(curl -s ifconfig.me)

            SUBSTRATE_RPC_URL='ws://'$IP':9944'
            OFFCHAIN_URL='http://'$IP':3001'
            OFFCHAIN_WS='ws://'$IP':3011'
            ES_URL='http://'$IP':9200'
            WEBUI_URL='http://'$IP
            IPFS_READ_ONLY_NODE_URL='http://'$IP':8080'
            IPFS_NODE_URL='http://'$IP':5001'

            printf $COLOR_Y'Starting globally...\n\n'$COLOR_RESET
            ;;

        # Pull latest changes by tag (ref. 'Version variables' or '--tag')
        --force-pull)
            FORCEPULL="true"
            printf $COLOR_Y'Pulling the latest revision of the used Docker images...\n\n'$COLOR_RESET
            ;;

        # Specify docker images tag
        --tag)
            if [[ -z $2 ]] || [[ $2 == *'--'* ]]; then
                printf $COLOR_R'WARN: --tag must be provided with a tag name argument\n'$COLOR_RESET >&2
                break
            else
                export OFFCHAIN_VERSION=$2
                export NODE_VERSION=$2
                export WEBUI_VERSION=$2
                printf $COLOR_Y'Switched to components by tag '$2'\n\n'$COLOR_RESET
                shift
            fi
            ;;

        # Delete project's docker containers
        --stop)
            if [[ $2 == "purge-volumes" ]]; then
                STOP_MODE=$2
            else
                STOP_MODE="default"
            fi
            ;;

        #################################################
        # Exclude switches
        #################################################

        --no-offchain)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/offchain.yml/}"
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/elastic\/compose.yml/}"
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

        --no-proxy)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/caddy.yml/}"
            printf $COLOR_Y'Starting without Caddy server Proxy...\n\n'$COLOR_RESET
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
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/offchain.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/elasticsearch.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/ipfs.yml"
            printf $COLOR_Y'Starting Offchain only...\n\n'$COLOR_RESET
            ;;

        --only-elastic)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/elasticsearch.yml"
            printf $COLOR_Y'Starting ElasticSearch only...\n\n'$COLOR_RESET
            ;;

        --only-substrate)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network.yml"
            COMPOSE_FILES+=${SELECTED_SUBSTRATE}
            printf $COLOR_Y'Starting only Substrate...\n\n'$COLOR_RESET
            ;;

        --only-webui)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/web_ui.yml"
            printf $COLOR_Y'Starting only Web UI...\n\n'$COLOR_RESET
            ;;

        --only-proxy)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/caddy.yml"
            printf $COLOR_Y'Starting only Caddy server proxy...\n\n'$COLOR_RESET
            ;;

        --only-ipfs)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/network.yml"
            COMPOSE_FILES+=" -f ${COMPOSE_DIR}/ipfs.yml"
            printf $COLOR_Y'Starting only IPFS cluster...\n\n'$COLOR_RESET
            ;;

        #################################################
        # Specify component's URLs (ref. 'URL variables')
        #################################################

        --substrate-url)
            if [[ -z $2 ]] || [[ $2 =~ --.* ]] || ! [[ $2 =~ wss?://.*:?.* ]]; then
                printf $COLOR_R'WARN: --substrate-url must be provided with an ws(s)://IP:PORT argument\n'$COLOR_RESET >&2
                break
            else
                export SUBSTRATE_RPC_URL=$2
                printf $COLOR_Y'Substrate URL set to %s\n\n'$COLOR_RESET "$SUBSTRATE_RPC_URL"
                shift
            fi
            ;;

        --offchain-url)
            if [[ -z $2 ]] || ! [[ $2 =~ https?://.* ]]; then
                printf $COLOR_R'WARN: --offchain-url must be provided with URL argument\n'$COLOR_RESET >&2
                break
            else
                export OFFCHAIN_URL=$2
                printf $COLOR_Y'Offchain URL set to %s\n\n'$COLOR_RESET "$2"
                shift
            fi
            ;;

        --elastic-url)
            if [[ -z $2 ]] || ! [[ $2 =~ https?://.* ]]; then
                printf $COLOR_R'WARN: --elastic-url must be provided with an URL argument\n'$COLOR_RESET >&2
                break
            else
                export ES_URL=$2
                printf $COLOR_Y'ElasticSearch URL set to %s\n\n'$COLOR_RESET "$2"
                shift
            fi
            ;;

        --webui-url)
            if [[ -z $2 ]] || ! [[ $2 =~ https?://.* ]]; then
                printf $COLOR_R'WARN: --webui-url must be provided with a URL string\n'$COLOR_RESET >&2
                break
            else
                WEBUI_URL=$2
                printf $COLOR_Y'Web UI IP set to %s\n\n'$COLOR_RESET "$2"
                shift
            fi
            ;;

        --ipfs-ip)
            # TODO: regex check
            # TODO: add https support
            if [[ -z $2 ]] || [[ -z $3 ]]; then
                printf $COLOR_R'ERROR: --ipfs-ip must be provided with (node/cluster/all) and IP arguments\nExample: --ipfs-ip cluster 172.15.0.9\n'$COLOR_RESET >&2
                break
            fi
            case $2 in
                "node")
                    IPFS_NODE_URL=http://$3:5001
                    IPFS_READ_ONLY_NODE_URL=http://$3:8080
                    ;;
                "cluster")
                    IPFS_CLUSTER_URL=http://$3:9094
                    ;;
                "all")
                    IPFS_NODE_URL=http://$3:5001
                    IPFS_READ_ONLY_NODE_URL=http://$3:8080
                    IPFS_CLUSTER_URL=http://$3:9094
                    ;;
                *)
                    printf $COLOR_R'ERROR: --ipfs-ip must be provided with (readonly/cluster/all)\n'$COLOR_RESET >&2
                    break
                    ;;
            esac

            printf $COLOR_Y'IPFS %s IP is set to %s\n\n'$COLOR_RESET "$2" "$3"
            shift 2
            ;;

        #################################################
        # Extra options for substrate node
        #################################################

        --substrate-extra-opts)
            if [[ -z $2 ]]; then
                printf $COLOR_R'WARN: --substrate-extra-opts must be provided with arguments string\n'$COLOR_RESET >&2
                break
            # elif [[ $2 =~ ^\"*\" ]]; then
            #     printf 'Usage example: '$COLOR_Y'--substrate-extra-opts "--name node --validator"\n'$COLOR_RESET >&2
            #     break
            else
                parse_substrate_extra_opts $2
                shift
            fi
            ;;

        --substrate-mode)
            if [[ -z $2 ]]; then
                printf $COLOR_R'USAGE: --substrate-mode (all/rpc/validator)\n'$COLOR_RESET >&2
                break
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
                    *)
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

        --cluster-id)
            docker exec subsocial-ipfs-cluster ipfs-cluster-ctl id
            break
            ;;

        --cluster-bootstrap)
            if [[ -z $2 ]]; then
                printf $COLOR_R'WARN: --cluster-bootstrap must be provided with arguments string\n'$COLOR_RESET >&2
                break
            else
                CLUSTER_BOOTSTRAP=$2
                shift
            fi
            ;;

        --cluster-mode)
            case $2 in
                raft)
                    CLUSTER_SECRET=$(od  -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')
                    ;;
                crtd)
                    ;;
                *)
                    printf $COLOR_R'WARN: --cluster-mode provided with unknown option %s\n'$COLOR_RESET "$2" >&2
                    break
                    ;;
            esac

            IPFS_CLUSTER_CONSENSUS=$2
            shift
            ;;

        --cluster-secret)
            if [[ -z $2 ]]; then
                printf $COLOR_R'WARN: --cluster-secret must be provided with a secret string\n'$COLOR_RESET >&2
                break
            else
                CLUSTER_SECRET=$2
            fi
            ;;

        --cluster-peername)
            if [[ -z $2 ]]; then
                printf $COLOR_R'WARN: --cluster-peername must be provided with a peer name string\n'$COLOR_RESET >&2
                break
            else
                CLUSTER_PEERNAME=$2
                shift
            fi
            ;;

        --cluster-peers)
            test_jq_installation

            if [[ -z '$2' ]] || [[ -z '$3' ]]; then
                printf $COLOR_R'ERROR: --cluster-peers must be provided with (add/remove/override) and URI(s) JSON array\n' >&2
                printf "Example of rewriting peers: "$COLOR_RESET"--cluster-peers override '[\"*\"]'\n" >&2
                printf $COLOR_R"Example of adding a peer: "$COLOR_RESET"--cluster-peers add '\"PeerURI-1\",\"PeerURI-2\"'\n" >&2
                printf $COLOR_R"Example of removing a peer: "$COLOR_RESET"--cluster-peers remove '\"PeerURI-1\",\"PeerURI-2\"'\n" >&2
                printf $COLOR_R"\nWhere "$COLOR_RESET"\"Peer URI\""$COLOR_R" looks like: "$COLOR_RESET"/ip4/172.15.0.9/tcp/9096/p2p/12D3KooWD8YVcSx6ERnEDXZpXzJ9ctkTFDhDu8d1eQqdDsLgPz7V\n" >&2
                break
            fi

            if [[ ! -f $CLUSTER_CONFIG_PATH ]]; then
                printf $COLOR_R'ERROR: IPFS Cluster is not yet started.\n' >&2
                prtinf '>> Start IPFS Cluster to create config JSON\n'$COLOR_RESET >&2
                break
            fi

            case $2 in
                "add")
                    _new_trusted_peers_query=".consensus.$IPFS_CLUSTER_CONSENSUS.trusted_peers += [$3]"
                    ;;
                "remove")
                    _new_trusted_peers_query=".consensus.$IPFS_CLUSTER_CONSENSUS.trusted_peers -= [$3]"
                    ;;
                "override")
                    _new_trusted_peers_query=".consensus.$IPFS_CLUSTER_CONSENSUS.trusted_peers = $3"
                    ;;
                *)
                    printf $COLOR_R'ERROR: --cluster-peers must be provided with (add/remove/override) only\n'$COLOR_RESET >&2
                    break
                    ;;
            esac

            _temp_file_name=tmp.$$.json
            jq "$_new_trusted_peers_query" $CLUSTER_CONFIG_PATH > $_temp_file_name
            mv $_temp_file_name $CLUSTER_CONFIG_PATH

            printf $COLOR_Y'%s (%s) on IPFS Cluster trusted peers\n\n'$COLOR_RESET "$3" "$2"
            shift 2
            ;;

        #################################################
        # Extra options for offchain
        #################################################

        # TODO: add support of multiple addresses
        --offchain-cors)
            if [[ -z $2 ]]; then
                printf $COLOR_R'WARN: --offchain-cors must be provided with URL(s) string\n'$COLOR_RESET >&2
                break
            else
                OFFCHAIN_CORS=$2
                printf $COLOR_Y'Offchain CORS set to '$2'\n\n'$COLOR_RESET
                shift
            fi
            ;;

        --offchain-cmd)
            if [[ -z $2 ]]; then
                printf $COLOR_R'WARN: --offchain-cmd must be provided with a command string\n'$COLOR_RESET >&2
                break
            else
                # parse_offchain_command $2
                OFFCHAIN_CUSTOM_CMD="'$2'"
                shift
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
            mkdir ${EXTERNAL_VOLUME} 2> /dev/null || true
            if [[ ${STOP_MODE} != "none" ]]; then
                printf $COLOR_Y'Doing a deep clean ...\n\n'$COLOR_RESET
                data_status=$DATA_STATUS_SAVED

                exec_docker_compose down
                if [[ ${STOP_MODE} == "purge-volumes" ]]; then
                    printf $COLOR_R'"purge-volumes" will clean all data produced by the project (Postgres, ElasticSearch, etc).\n'
                    printf 'Do you really want to continue?'$COLOR_RESET' [Y/N]: ' && read answer_to_purge
                    if [[ $answer_to_purge == "Y" ]]; then
                        docker-compose --project-name=$PROJECT_NAME $COMPOSE_FILES down -v 2> /dev/null || true

                        printf $COLOR_Y'Cleaning IPFS data, Offchain state and ES passwords. Root may be required.\n'$COLOR_RESET
                        [[ -d $EXTERNAL_VOLUME ]] && sudo rm -rf $EXTERNAL_VOLUME || true
                        [[ -f $ELASTIC_PASSWORDS_PATH ]] && rm $ELASTIC_PASSWORDS_PATH || true
                        data_status=$DATA_STATUS_PRUNED
                    fi
                fi

                printf "\nProject stopped successfully $data_status\n"
                printf $COLOR_RESET'\nNon empty Docker volumes:\n'
                docker volume ls
                [[ -d $EXTERNAL_VOLUME ]] && printf "External volume path: '$EXTERNAL_VOLUME'\n"
                break
            fi

            printf $COLOR_Y'Starting Subsocial...\n\n'$COLOR_RESET

            [[ ${FORCEPULL} = "true" ]] && exec_docker_compose pull
            exec_docker_compose up -d

            [[ $COMPOSE_FILES =~ 'offchain' ]] && printf "\nHold on, starting Offchain:\n\n"

            if [[ $COMPOSE_FILES =~ 'elasticsearch' ]]; then
                stop_container offchain

                # ElasticSearch
                printf "Waiting until ElasticSearch starts...\n"
                until curl -s ${ES_URL} > /dev/null; do
                    sleep 1
                done

                # TODO: check whether it's the first start of ElasticSearch instead
                if [[ ! -f $ELASTIC_PASSWORDS_PATH ]]; then
                    printf "Generating passwords for ElasticSearch...\n"
                    docker exec -t subsocial-elasticsearch bin/elasticsearch-setup-passwords auto -b \
                    | grep -wi 'password.*=' > $ELASTIC_PASSWORDS_PATH
                    printf "ES passwords are successfully saved to ${ELASTIC_PASSWORDS_PATH}\n\n"

                    create_subsocial_elastic_users
                fi

                resolve_subsocial_elastic_passwords
            fi

            if [[ $COMPOSE_FILES =~ 'ipfs' ]]; then
                stop_container offchain
                stop_container ipfs-cluster

                printf "Wait until IPFS node starts\n"

                until (
                    docker exec ${CONT_IPFS_NODE} ipfs config --json \
                        API.HTTPHeaders.Access-Control-Allow-Origin \
                        '["'$IPFS_CLUSTER_URL'", "'$OFFCHAIN_URL'"]' 2> /dev/null &&
                    docker restart ${CONT_IPFS_NODE} > /dev/null
                ); do
                    sleep 1
                done
                wait_for_ipfs_node

                printf "Setting up IPFS cluster...\n"
                [[ ! -z $CLUSTER_BOOTSTRAP ]] && write_boostrap_peers $CLUSTER_BOOTSTRAP
                start_container ipfs-cluster
            fi

            if [[ $COMPOSE_FILES =~ 'offchain' ]]; then
                recreate_container offchain
                printf 'Offchain successfully started\n\n'
            fi

            if [[ $COMPOSE_FILES =~ 'web_ui' ]]; then
                printf "\nWaiting for Web UI to start...\n"
                until curl -s ${WEBUI_URL} > /dev/null; do
                    sleep 1
                done

                printf 'Web UI is available at '$WEBUI_URL'\n'
            fi
            printf '\nContainers are ready.\n'
            break
    esac
    shift
done

popd > /dev/null
exit 0
