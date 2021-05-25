#!/bin/bash

set -e
pushd . > /dev/null

# The following lines ensure we run from the root folder of this Starter
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export DIR
COMPOSE_DIR="$DIR/compose-files"

# Default props
export EXPOSE_IP=127.0.0.1
export EXTERNAL_VOLUME=~/subsocial_data

# colors
COLOR_R="\033[0;31m"    # red
COLOR_Y="\033[0;33m"    # yellow
COLOR_RESET="\033[00m"  # reset color

# Start another instance of this project
if [[ "$1" == "--instance" ]]; then
    if [[ -n $2 ]] && [[ $2 =~ [a-zA-Z]{0,16} ]]; then
        PROJECT_NAME=$2
        shift 2
    else
        printf $COLOR_R"FATAL: '--instance' option must be provided with instance name\n"
        exit 1
    fi
else
    PROJECT_NAME="subsocial"
fi

FORCEPULL="false"
STOP_MODE="none"
DATA_STATUS_PRUNED="(data pruned)"
DATA_STATUS_SAVED="(data saved)"

# Generated new IPFS Cluster secret in case the ipfs-data was cleaned
export CLUSTER_SECRET=""

# Other IPFS Cluster variables
export CLUSTER_PEERNAME="Subsocial Cluster"
export CLUSTER_BOOTSTRAP=""
export IPFS_CLUSTER_CONSENSUS="crdt"

# ElasticSearch related variables
ELASTIC_PASSWORDS_PATH=$EXTERNAL_VOLUME/es-passwords-$PROJECT_NAME
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
export SUBSTRATE_NODE_VERSION=latest
export HYDRA_QUERY_NODE_VERSION=latest
export HYDRA_PROCESSOR_VERSION=latest

# Docker services
export SERVICE_POSTGRES=postgres
export SERVICE_ELASTICSEARCH=elasticsearch
export SERVICE_IPFS_CLUSTER=ipfs-cluster
export SERVICE_IPFS_NODE=ipfs-node
export SERVICE_OFFCHAIN=offchain
export SERVICE_NODE_RPC=node-rpc
export SERVICE_NODE_VALIDATOR=node-validator
export SERVICE_CADDY=caddy
export SERVICE_HYDRA_QUERY_NODE=hydra-query-node
export SERVICE_HYDRA_PROCESSOR=hydra-processor

set_port_if_available(){
    local var_to_write="$1"
    local port_to_check="$2"
    local offset=0

    local final_port
    final_port="$((port_to_check + offset))"

    until ! sudo lsof -i:"$final_port" > /dev/null; do
        docker ps | grep ":$final_port->" | grep -q " $PROJECT_NAME" && break
        offset="$((offset + 1))"
        final_port="$((port_to_check + offset))"
    done

    export "$var_to_write"="$final_port"
}

# URL variables
export_container_urls(){
    export SUBSTRATE_RPC_URL=ws://$SERVICE_NODE_RPC:$SUBSTRATE_WS_PORT
    export OFFCHAIN_URL=http://$SERVICE_OFFCHAIN:$OFFCHAIN_API_PORT
    export OFFCHAIN_WS=ws://$SERVICE_OFFCHAIN:$OFFCHAIN_WS_PORT
    export ES_URL=http://$SERVICE_ELASTICSEARCH:$ES_PORT
    export IPFS_CLUSTER_URL=http://$SERVICE_IPFS_CLUSTER:$IPFS_CLUSTER_API_PORT
    export IPFS_NODE_URL=http://$SERVICE_IPFS_NODE:$IPFS_NODE_PORT
    export IPFS_READ_ONLY_NODE_URL=http://$SERVICE_IPFS_NODE:$IPFS_READONLY_PORT
}

# Docker container ports
printf $COLOR_Y'Trying to check whether ports are available, root permissions may be required...\n'$COLOR_RESET
export_container_ports(){
    set_port_if_available "SUBSTRATE_WS_PORT" 9944
    set_port_if_available "SUBSTRATE_RPC_PORT" 9933
    set_port_if_available "SUBSTRATE_TCP_PORT" 30333
    set_port_if_available "SUBSTRATE_VALIDATOR_RPC_PORT" 9934
    set_port_if_available "SUBSTRATE_VALIDATOR_TCP_PORT" 30334

    set_port_if_available "ES_PORT" 9200

    set_port_if_available "IPFS_READONLY_PORT" 8080
    set_port_if_available "IPFS_NODE_PORT" 5001
    set_port_if_available "IPFS_SWARM_PORT" 4001

    set_port_if_available "IPFS_CLUSTER_API_PORT" 9094
    set_port_if_available "IPFS_CLUSTER_TCP_PORT" 9096

    set_port_if_available "OFFCHAIN_API_PORT" 3001
    set_port_if_available "OFFCHAIN_WS_PORT" 3011

    set_port_if_available "OFFCHAIN_POSTGRES_PORT" 5432

    set_port_if_available "GRAPHQL_SERVER_PORT" 4000
    export WARTHOG_APP_PORT=$GRAPHQL_SERVER_PORT

    export_container_urls
}
export_container_ports

show_ports_info(){
    local is_running
    printf $COLOR_Y'\nSubsocial related ports that are listening on your host:\n'$COLOR_RESET

    is_running="$(docker ps | grep -wi "$CONT_NODE_RPC")" || printf ""
    if [[ -n "$is_running" ]]; then
        echo "Substrate WebSocket:" "$SUBSTRATE_WS_PORT"
        echo "Substrate RPC:" "$SUBSTRATE_RPC_PORT"
        echo "Substrate TCP:" "$SUBSTRATE_TCP_PORT"
    fi

    is_running="$(docker ps | grep -wi "$CONT_NODE_VALIDATOR")" || printf ""
    if [[ -n "$is_running" ]]; then
        echo "Substrate Validator RPC:" "$SUBSTRATE_VALIDATOR_RPC_PORT"
        echo "Substrate Validator TCP:" "$SUBSTRATE_VALIDATOR_TCP_PORT"
    fi

    is_running="$(docker ps | grep -wi "$CONT_ELASTICSEARCH")" || printf ""
    [[ -n "$is_running" ]] && echo "Elasticsearch:" "$ES_PORT"

    is_running="$(docker ps | grep -wi "$CONT_IPFS_NODE")" || printf ""
    if [[ -n "$is_running" ]]; then
        echo "IPFS Node Read-only:" "$IPFS_READONLY_PORT"
        echo "IPFS Node API:" "$IPFS_NODE_PORT"
        echo "IPFS Node Swarm:" "$IPFS_SWARM_PORT"
    fi

    is_running="$(docker ps | grep -wi "$CONT_IPFS_CLUSTER")" || printf ""
    if [[ -n "$is_running" ]]; then
        echo "IPFS Cluster API:" "$IPFS_CLUSTER_API_PORT"
        echo "IPFS Cluster TCP:" "$IPFS_CLUSTER_TCP_PORT"
    fi

    is_running="$(docker ps | grep -wi "$CONT_OFFCHAIN")" || printf ""
    if [[ -n "$is_running" ]]; then
        echo "Offchain API:" "$OFFCHAIN_API_PORT"
        echo "Offchain Notifications WebSocket:" "$OFFCHAIN_WS_PORT"
    fi

    is_running="$(docker ps | grep -wi "$CONT_POSTGRES")" || printf ""
    if [[ -n "$is_running" ]]; then
        echo "PostgreSQL:" "$OFFCHAIN_POSTGRES_PORT"
    fi

    is_running="$(docker ps | grep -wi "$CONT_HYDRA_PROCESSOR")" || printf ""
    if [[ -n "$is_running" ]]; then
        echo "Hydra processor:" "$GRAPHQL_SERVER_PORT"
        echo "Warthog app:" "$WARTHOG_APP_PORT"
    fi
}

# Docker container names
export_container_names(){
    export CONT_POSTGRES=$PROJECT_NAME-postgres
    export CONT_ELASTICSEARCH=$PROJECT_NAME-elasticsearch
    export CONT_IPFS_CLUSTER=$PROJECT_NAME-ipfs-cluster
    export CONT_IPFS_NODE=$PROJECT_NAME-ipfs-node
    export CONT_OFFCHAIN=$PROJECT_NAME-offchain
    export CONT_NODE_RPC=$PROJECT_NAME-node-rpc
    export CONT_NODE_VALIDATOR=$PROJECT_NAME-node-validator
    export CONT_CADDY=$PROJECT_NAME-proxy
    export CONT_HYDRA_QUERY_NODE=$PROJECT_NAME-hydra-query-node
    export CONT_HYDRA_PROCESSOR=$PROJECT_NAME-hydra-processor
}
export_container_names

# Docker external volumes
export IPFS_NODE_STAGING=$EXTERNAL_VOLUME/ipfs/daemon/staging
export IPFS_NODE_DATA=$EXTERNAL_VOLUME/ipfs/daemon/data
export CLUSTER_CONFIG_FOLDER=$EXTERNAL_VOLUME/ipfs/cluster
CLUSTER_CONFIG_PATH=$CLUSTER_CONFIG_FOLDER/service.json
export OFFCHAIN_STATE=$EXTERNAL_VOLUME/offchain-state-$PROJECT_NAME

# Docker-compose files list
SUBSTRATE_RPC_COMPOSE=" -f $COMPOSE_DIR/substrate/substrate_rpc.yml"
SUBSTRATE_VALIDATOR_COMPOSE=" -f $COMPOSE_DIR/substrate/substrate_validator.yml"

SELECTED_SUBSTRATE=$SUBSTRATE_RPC_COMPOSE$SUBSTRATE_VALIDATOR_COMPOSE

COMPOSE_FILES=""
COMPOSE_FILES+=" -f $COMPOSE_DIR/postgres.yml"
COMPOSE_FILES+=" -f $COMPOSE_DIR/hydra.yml"
COMPOSE_FILES+=" -f $COMPOSE_DIR/offchain.yml"
COMPOSE_FILES+=" -f $COMPOSE_DIR/elasticsearch.yml"
COMPOSE_FILES+=" -f $COMPOSE_DIR/ipfs.yml"
COMPOSE_FILES+=$SELECTED_SUBSTRATE
# TODO: temporarily it is not needed to use caddy proxy in starter
# COMPOSE_FILES+=" -f $COMPOSE_DIR/caddy.yml"

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
            printf "%s\n" "$1"
            local temp_file_name=tmp.$$.json
            local new_trusted_peers_query=".cluster.peer_addresses += [$1]"
            jq "$new_trusted_peers_query" $CLUSTER_CONFIG_PATH > $temp_file_name
            mv $temp_file_name $CLUSTER_CONFIG_PATH
            shift
        fi
    done
}

wait_for_ipfs_node(){
    until curl -s "localhost:$IPFS_NODE_PORT/version" > /dev/null; do
        sleep 1
    done
}

stop_container() {
    local cont_name=""

    [[ -z $1 ]] || [[ -n $2 ]] \
        && printf $COLOR_R"FATAL: 'stop_container' command must be provided with one argument" \
        && exit 1

    [[ $1 == offchain ]] && [[ $COMPOSE_FILES =~ 'offchain' ]] \
        && docker container stop $CONT_OFFCHAIN > /dev/null

    if [[ $COMPOSE_FILES =~ 'ipfs' ]]; then
        [[ $1 == ipfs-cluster ]] && cont_name=$CONT_IPFS_CLUSTER
        [[ $1 == ipfs-node ]] && cont_name=$CONT_IPFS_NODE

        [[ -n $cont_name ]] && docker container stop $cont_name > /dev/null \
            || echo "nothing to stop" > /dev/null
    fi
}

# Starts a container if the next conditions are met:
# - Corresponding service exists in $COMPOSE_FILES set
# - Container is paused at the moment
start_container(){
    local cont_name

    [[ -z $1 ]] || [[ -n $2 ]] \
        && printf $COLOR_R"FATAL: 'start_container' command must be provided with one argument" && exit 1

    [[ $1 == offchain ]] && [[ $COMPOSE_FILES =~ 'offchain' ]] \
        && cont_name=$CONT_OFFCHAIN

    if [[ $COMPOSE_FILES =~ 'ipfs' ]]; then
        [[ $1 == ipfs-cluster ]] && cont_name=$CONT_IPFS_CLUSTER
        [[ $1 == ipfs-node ]] && cont_name=$CONT_IPFS_NODE
    fi

    local is_running="$(docker ps | grep -wi $cont_name)"
    local exists="$(docker ps -a | grep -wi $cont_name)"
    if [[ -z $exists ]]; then
        printf $COLOR_R"ERROR: container %s doesn't exist\n" "$cont_name"
        exit 1
    else
        [[ -z $is_running ]] && [[ -n $cont_name ]] \
            && docker container start $cont_name > /dev/null
    fi
}

recreate_container(){
    local recreate_allowed=""

    [[ -z $1 ]] || [[ -n $2 ]] \
        && printf $COLOR_R"FATAL: 'recreate_container' command must be provided with one argument" && exit 1

    [[ $1 == offchain && $COMPOSE_FILES =~ 'offchain' ]] \
        && recreate_allowed="true"

    [[ $1 == ipfs-cluster || $1 == ipfs-node ]] && [[ $COMPOSE_FILES =~ 'ipfs' ]] \
        && recreate_allowed="true"

    if [[ -z $recreate_allowed ]]; then
        printf $COLOR_R"ERROR: %s cannot be restarted before corresponding service included" "$1"
        exit 1
    else
        exec_docker_compose up -d "$1"
    fi
}

create_subsocial_elastic_users(){
    local password
    local elastic_password="$(< $ELASTIC_PASSWORDS_PATH grep -wi 'elastic' | cut -d "=" -f2- | tr -d '[:space:]')"

    curl -XPOST -su elastic:"$elastic_password" 'localhost:9200/_security/role/index_subsocial' \
    -H "Content-Type: application/json" --data-binary "@$DIR/elastic/add_index_role.json" > /dev/null

    curl -XPOST -su elastic:"$elastic_password" 'localhost:9200/_security/role/read_subsocial' \
    -H "Content-Type: application/json" --data-binary "@$DIR/elastic/add_read_role.json" > /dev/null

    password=$(od  -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')
    curl -XPOST -su elastic:"$elastic_password" 'localhost:9200/_security/user/'$ES_OFFCHAIN_USER'' \
    -H "Content-Type: application/json" -d '{ "password": "'$password'", "roles" : [ "index_subsocial" ] }' > /dev/null \
    && echo "PASSWORD offchain = $password" >> $ELASTIC_PASSWORDS_PATH

    password=$(od  -vN 32 -An -tx1 /dev/urandom | tr -d ' \n')
    curl -XPOST -su elastic:"$elastic_password" 'localhost:9200/_security/user/'$ES_READONLY_USER'' \
    -H "Content-Type: application/json" -d '{ "password": "'$password'", "roles" : [ "read_subsocial" ] }' > /dev/null \
    && echo "PASSWORD readonly = $password" >> $ELASTIC_PASSWORDS_PATH
}

resolve_subsocial_elastic_passwords(){
    ES_OFFCHAIN_PASSWORD="$(< $ELASTIC_PASSWORDS_PATH grep -wi $ES_OFFCHAIN_USER | cut -d "=" -f2- | tr -d '[:space:]')"
    ES_READONLY_PASSWORD="$(< $ELASTIC_PASSWORDS_PATH grep -wi $ES_READONLY_USER | cut -d "=" -f2- | tr -d '[:space:]')"
    printf 'ElasticSearch passwords are set to offchain container\n\n'
}

exec_docker_compose(){
    [[ -z $1 ]] && printf $COLOR_R'FATAL: wrong usage of `exec_docker_compose`. Empty parameter $1\n'$COLOR_RESET \
        && exit 1

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

        --unsafe-expose-ports)
            EXPOSE_IP="0.0.0.0"
            printf $COLOR_R'UNSAFE:'$COLOR_Y' Exposing docker ports outside a local machine.\n'
            printf 'We recommend to use proxy or local http server with SSL\n\n'$COLOR_RESET
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
                export SUBSTRATE_NODE_VERSION=$2
                printf $COLOR_Y'Switched to components by tag '$2'\n\n'$COLOR_RESET
                shift
            fi
            ;;

        # Delete project's docker containers
        --stop)
            if [[ $2 == "--clean-data" ]]; then
                STOP_MODE=$2
                shift
            else
                STOP_MODE="default"
            fi
            ;;

        # Show Subsocail related ports currently listening on the host machine
        --show-ports)
            show_ports_info
            exit 0
        ;;

        #################################################
        # Exclude switches
        #################################################

        --no-offchain)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/postgres.yml/}"
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/offchain.yml/}"
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/elasticsearch.yml/}"
            printf $COLOR_Y'Starting without Offchain...\n\n'$COLOR_RESET
            ;;

        --no-substrate)
            COMPOSE_FILES="${COMPOSE_FILES/${SELECTED_SUBSTRATE}/}"
            printf $COLOR_Y'Starting without Substrate Nodes...\n\n'$COLOR_RESET
            ;;

        --no-proxy)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/caddy.yml/}"
            printf $COLOR_Y'Starting without Caddy server Proxy...\n\n'$COLOR_RESET
            ;;

        --no-ipfs)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/ipfs.yml/}"
            printf $COLOR_Y'Starting without IPFS Cluster...\n\n'$COLOR_RESET
            ;;

        --no-elasticsearch)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/elasticsearch.yml/}"
            printf $COLOR_Y'Starting without Elasticsearch...\n\n'$COLOR_RESET
            ;;

        --no-hydra)
            COMPOSE_FILES="${COMPOSE_FILES/ -f ${COMPOSE_DIR}\/hydra.yml/}"
            printf $COLOR_Y'Starting without Hydra processor and query-node...\n\n'$COLOR_RESET
            ;;

        #################################################
        # Include-only switches
        #################################################

        --only-offchain)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f $COMPOSE_DIR/postgres.yml"
            COMPOSE_FILES+=" -f $COMPOSE_DIR/hydra.yml"
            COMPOSE_FILES+=" -f $COMPOSE_DIR/offchain.yml"
            COMPOSE_FILES+=" -f $COMPOSE_DIR/elasticsearch.yml"
            COMPOSE_FILES+=" -f $COMPOSE_DIR/ipfs.yml"
            printf $COLOR_Y'Starting Offchain only...\n\n'$COLOR_RESET
            ;;

        --only-elastic)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f $COMPOSE_DIR/elasticsearch.yml"
            printf $COLOR_Y'Starting ElasticSearch only...\n\n'$COLOR_RESET
            ;;

        --only-substrate)
            COMPOSE_FILES=""
            COMPOSE_FILES+=$SELECTED_SUBSTRATE
            printf $COLOR_Y'Starting only Substrate...\n\n'$COLOR_RESET
            ;;

        --only-proxy)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f $COMPOSE_DIR/caddy.yml"
            printf $COLOR_Y'Starting only Caddy server proxy...\n\n'$COLOR_RESET
            ;;

        --only-ipfs)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f $COMPOSE_DIR/ipfs.yml"
            printf $COLOR_Y'Starting only IPFS cluster...\n\n'$COLOR_RESET
            ;;

        --only-hydra)
            COMPOSE_FILES=""
            COMPOSE_FILES+=" -f $COMPOSE_DIR/postgres.yml"
            COMPOSE_FILES+=" -f $COMPOSE_DIR/hydra.yml"
            printf $COLOR_Y'Starting Hydra processor and query-node...\n\n'$COLOR_RESET
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
                        SELECTED_SUBSTRATE=$SUBSTRATE_RPC_COMPOSE$SUBSTRATE_VALIDATOR_COMPOSE
                        ;;
                    rpc)
                        SELECTED_SUBSTRATE=$SUBSTRATE_RPC_COMPOSE
                        ;;
                    validator)
                        SELECTED_SUBSTRATE=$SUBSTRATE_VALIDATOR_COMPOSE
                        ;;
                    *)
                        printf $COLOR_R'WARN: --substrate-mode provided with unknown option %s\n'$COLOR_RESET "$2" >&2
                        break
                        ;;
                esac
                shift
                COMPOSE_FILES+=$SELECTED_SUBSTRATE
            fi
            ;;

        #################################################
        # Extra options for IPFS cluster
        #################################################

        --cluster-id)
            docker exec $CONT_IPFS_CLUSTER ipfs-cluster-ctl id
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

            if [[ -z "$2" ]] || [[ -z "$3" ]]; then
                printf $COLOR_R'ERROR: --cluster-peers must be provided with (add/remove/override) and URI(s) JSON array\n' >&2
                printf "Example of rewriting peers: $COLOR_RESET--cluster-peers override '[\"*\"]'\n" >&2
                printf $COLOR_R"Example of adding a peer: $COLOR_RESET--cluster-peers add '\"PeerURI-1\",\"PeerURI-2\"'\n" >&2
                printf $COLOR_R"Example of removing a peer: $COLOR_RESET--cluster-peers remove '\"PeerURI-1\",\"PeerURI-2\"'\n" >&2
                printf $COLOR_R"\nWhere $COLOR_RESET\"Peer URI\"$COLOR_R looks like: $COLOR_RESET/ip4/172.15.0.9/tcp/9096/p2p/12D3KooWD8YVcSx6ERnEDXZpXzJ9ctkTFDhDu8d1eQqdDsLgPz7V\n" >&2
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

        --instance)
            printf $COLOR_R"FATAL: '--instance' option must be provided as the first option\n"
            exit 1
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
            mkdir $EXTERNAL_VOLUME 2> /dev/null || true
            if [[ $STOP_MODE != "none" ]]; then
                printf $COLOR_Y'Doing a deep clean ...\n\n'$COLOR_RESET
                data_status=$DATA_STATUS_SAVED

                exec_docker_compose down
                if [[ $STOP_MODE == "--clean-data" ]]; then
                    printf $COLOR_R'"clean-data" will clean all data produced by the project (Postgres, ElasticSearch, etc).\n'
                    printf $COLOR_RESET"Note that IPFS data ${COLOR_Y}will not$COLOR_RESET be removed. You can do this manually.\n"
                    printf $COLOR_R'Do you really want to continue?'$COLOR_RESET' [Y/N]: ' && read -r answer_to_purge
                    if [[ $answer_to_purge == "Y" ]]; then
                        docker-compose --project-name=$PROJECT_NAME $COMPOSE_FILES down -v 2> /dev/null || true

                        printf $COLOR_Y'Cleaning Offchain state and ES passwords. Root may be required.\n'$COLOR_RESET
                        [[ -d $OFFCHAIN_STATE ]] && sudo rm -rf $OFFCHAIN_STATE
                        [[ -f $ELASTIC_PASSWORDS_PATH ]] && sudo rm -f $ELASTIC_PASSWORDS_PATH
                        data_status=$DATA_STATUS_PRUNED
                    fi
                fi

                printf "\nProject stopped successfully %s\n" "$data_status"
                printf $COLOR_RESET'\nNon empty Docker volumes:\n'
                docker volume ls
                [[ -d $EXTERNAL_VOLUME ]] && printf "External volume path: '%s'\n" "$EXTERNAL_VOLUME"
                break
            fi

            printf $COLOR_Y'Starting Subsocial...\n\n'$COLOR_RESET

            [[ $FORCEPULL = "true" ]] && exec_docker_compose pull
            exec_docker_compose up -d

            if [[ $COMPOSE_FILES =~ 'offchain' ]]; then
                if [[ ! -f "$DIR/.env" ]]; then
                    printf $COLOR_R"Error: you must specify environmental variables for offchain\n"
                    exec_docker_compose down > /dev/null
                    exit 1
                fi
                printf "\nHold on, starting Offchain:\n\n"
            fi

            if [[ $COMPOSE_FILES =~ 'elasticsearch' ]]; then
                stop_container offchain

                # ElasticSearch
                printf "Waiting until ElasticSearch starts...\n"
                until curl -s "localhost:$ES_PORT" > /dev/null; do
                    sleep 1
                done

                # TODO: check whether it's the first start of ElasticSearch instead
                if [[ ! -f $ELASTIC_PASSWORDS_PATH ]]; then
                    printf "Generating passwords for ElasticSearch...\n"
                    docker exec -t $CONT_ELASTICSEARCH bin/elasticsearch-setup-passwords auto -b \
                    | grep -wi 'password.*=' > $ELASTIC_PASSWORDS_PATH
                    printf "ES passwords are successfully saved to %s\n\n" "$ELASTIC_PASSWORDS_PATH"
                    create_subsocial_elastic_users
                fi

                resolve_subsocial_elastic_passwords
            fi

            if [[ $COMPOSE_FILES =~ 'ipfs' ]]; then
                stop_container offchain
                stop_container ipfs-cluster

                printf "Wait until IPFS node starts\n"
                wait_for_ipfs_node

                docker exec $CONT_IPFS_NODE ipfs config --json \
                    API.HTTPHeaders.Access-Control-Allow-Origin '["'$IPFS_CLUSTER_URL'", "'$OFFCHAIN_URL'"]' 2> /dev/null

                docker restart $CONT_IPFS_NODE > /dev/null
                wait_for_ipfs_node

                printf "Setting up IPFS cluster...\n"
                [[ -n $CLUSTER_BOOTSTRAP ]] && write_boostrap_peers $CLUSTER_BOOTSTRAP
                start_container ipfs-cluster
            fi

            if [[ $COMPOSE_FILES =~ 'offchain' ]]; then
                recreate_container offchain
                printf 'Offchain successfully started\n\n'
            fi

            show_ports_info

            printf '\nContainers are ready.\n'
            break
    esac
    shift
done

popd > /dev/null
exit 0
