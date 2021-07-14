# Subsocial Starter by [DappForce](https://github.com/dappforce)

This guide will walk you through starting an entire Subsocial stack with just one shell script.

To learn more about Subsocial, please visit us at [Subsocial.Network](http://subsocial.network/).

## Supported by Web3 Foundation

<img src="https://github.com/dappforce/dappforce-subsocial/blob/master/w3f-badge.svg" width="100%" height="200" alt="Web3 Foundation grants badge" />

Subsocial is the recipient of a technical grant from Web3 Foundation -
[official announcement](https://medium.com/web3foundation/web3-foundation-grants-wave-3-recipients-6426e77f1230).
We have successfully delivered on all three milestones submitted in our grant application.

## Requirements

Linux environment or macOS with [Docker](https://www.docker.com/get-started)
and [Docker Compose](https://docs.docker.com/compose/) installed.

Test that Docker was installed correctly, try to run the following commands:
*NOTE: none of the commands should fail*.

```
docker images
docker ps
docker run --rm -it alpine cat /etc/os-release
```

### Possible issues on Linux

If you are using Linux and having a permission issue with Docker,
try running the following commands:

```
sudo systemctl enable docker
sudo systemctl disable docker
```

After running the commands, logout and log back in.
The Docker commands should now run without sudo.

## Easy start

If you're new to Subsocial, it is best to start with the defaults.

### Clone a starter repo

```
git clone https://github.com/dappforce/dappforce-subsocial-starter.git
cd dappforce-subsocial-starter
```

### Start entire Subsocial project locally

```
./start.sh --substrate-mode rpc --substrate-extra-opts "--dev"
```

## Launch Subsocial parts one by one

### Substrate nodes

| Container name             | External Port | Local URL           | Description            |
| -------------------------- | ------------- | ------------------- | ---------------------- |
| `subsocial-node-rpc`       | `9944`        | ws://localhost:9944 | RPC sync node          |
| `subsocial-node-validator` | `30334`       |                     | Archive authority node |

#### Start Substrate nodes

By default two nodes will be started: *RPC* and *validator*.

We will use `--only-substrate` option to run only Substrate nodes:

```
./start.sh --only-substrate
```

​If you would like to start archive RPC. The command below is the only available method (for now)
which is connected to Subsocial network:

```
./start.sh --only-substrate --substrate-mode-rpc --substrate-extra-opts "--name MyNodeName --pruning archive"
```

However, you will have no ability to manage anything inside of them.
To do this, you may want to launch Substrate node with extra option `--dev`.

For example:

```
./start.sh --only-substrate --substrate-mode rpc --substrate-extra-opts "--dev"
```

Here we also used the `--substrate-mode rpc` option.
That is because running in development mode we do not need any validators.

#### Stop Substrate nodes

To stop Substrate nodes:

```
./start.sh --only-substrate --stop
```

If you want not only stop containers, but also clean data, go with:

```
./start.sh --only-substrate --stop --clean-data
```

### Offchain services

| Container name               | External Ports | Local URL                   | Description                                                                     |
| ---------------------------- | -------------- | --------------------------- | ------------------------------------------------------------------------------- |
| `subsocial-offchain`         | `3001`, `3011` | http://localhost:3001/v1    | [Subsocial Offchain](https://github.com/dappforce/dappforce-subsocial-offchain) |
| `subsocial-elasticsearch`    | `9200`         | http://localhost:9200       | [ElasticSearch](https://www.elastic.co/what-is/elasticsearch)                   |
| `subsocial-postgres`         |                |                             | [PostgreSQL](https://www.postgresql.org/about/)                                 |
| `subsocial-hydra-query-node` | `4000`         | http://localhost:4000       | [Subsocial Hydra Processor](https://github.com/dappforce/subsocial-graphql)     |
| `subsocial-hydra-processor`  |                |                             | [Subsocial Hydra Query Node](https://github.com/dappforce/subsocial-graphql)    |

#### Start containers

By default, three containers will be started:
- Subsocial Offchain – responsible for Substrate events handling and Subsocial REST API.
- ElasticSearch – responsible for full-text search.
- PostgreSQL – responsible personal news feeds and notifications.

We will use `--only-offchain` to run Offchain only:

```
./start.sh --only-offchain
```

In most cases you will want to launch Offchain on a separate server.
If so, you will want to use next command:

```
./start.sh --global --only-substrate --substrate-url <Websocket endpoint> --offchain-cors "<UI URL>"
```

You can start Offchain without IPFS node by following the next steps:

1. [Run IPFS](#ipfs-cluster) on external server
2. Run Offchain with next options:
```bash
./start.sh --only-offchain --no-ipfs --ipfs-ip all <IP of IPFS server>
```

### IPFS cluster

| Container name           | External Ports | Local URL                                       | Description                                                  |
| ------------------------ | -------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| `subsocial-ipfs-node`    | `8080`         | http://localhost:8080                           | [IPFS Node](https://github.com/ipfs/go-ipfs/blob/master/README.md) |
| `subsocial-ipfs-cluster` | `9094`, `9096` | http://localhost:9094                           | [IPFS Cluster](https://github.com/ipfs/ipfs-cluster/blob/master/README.md) |

#### Start containers

By default it will start two containers: IPFS Cluster and IPFS Node (gateway).

We use `--only-ipfs` to run IPFS only:

```
./start.sh --only-ipfs --offchain-url <Offchain URL>
```

`--offchain-url` is mandatory here, because of CORS are used for IPFS cluster access.

You can specify initial IPFS cluster bootnodes in order to connect to Subsocial as a cluster peer. Example:

```
./start.sh --only-ipfs --cluster-bootstrap '"/ip4/172.15.0.9/tcp/9096/p2p/12D3KooWRRyJpS847KJQCEXqWC3AFjaweTBtVvA8DmLz9RxA7yQW","/ip4/174.100.4.101/tcp/9096/p2p/12D3KooWGsddM5p5M2HMF6egoR28mCwnKg75UE6K29BMvzux3WdY"'
```

**NOTE:** `--cluster-bootstrap` value should be provided as a single string with URIs wrapped in double-quotes (`"`) each and separated by commas.

If you want to add, remove or entirely override trusted peers (ones that are able to pin/unpin content on IPFS), you might want to use `--cluster-peers` option:

**To add a peer:**

```
./start.sh --only-ipfs --cluster-peers add '"PeerURI-1", "PeerURI-2"'
```

**To remove a peer:**

```
./start.sh --only-ipfs --cluster-peers remove '"PeerURI-1", "PeerURI-2"'
```

**To entirely override trusted peers:**

```
./start.sh --only-ipfs --cluster-peers override '["*"]'
```

**NOTE:** that when you override, you should provide JSON like array of peers.

**NOTE:** all - add, remove and override should have every Peer URI wrapped by double quotes.

To get *Peer URI* (e.g `/ip4/172.15.0.9/tcp/9096/p2p/12D3KooWD8YVcSx6ERnEDXZpXzJ9ctkTFDhDu8d1eQqdDsLgPz7V`) use `--cluster-id` option:

```
./start.sh --cluster-id
```


## Advanced

### Available options

The [start.sh](start.sh) script comes with a set of options for customizing project startup.

| Option                             | Description                                                  |
| ---------------------------------- | ------------------------------------------------------------ |
| `--instance [name]`                | This allows to run several instances simultaneously. **Note** that instance name must be unique string within Docker images and container names. |
| `--force-pull`                     | Pull Docker images tagged *latest* if only `--tag` isn't specified. |
| `--tag`                            | Specify Docker images tag.                                    |
| `--stop (--clean-data)`            | Stop and delete the Docker containers. If `--clean-data` is specified, Elasticsearch passwords, offchain state and Docker volumes will be deleted. |
| `--no-offchain`                    | Start Subsocial stack without Offchain storage and ElasticSearch. |
| `--no-substrate`                   | Start Subsocial stack without Substrate node.                 |
| `--no-proxy`                       | Start Subsocial stack without Caddy server proxy.             |
| `--no-ipfs`                        | Start Subsocial stack without IPFS Cluster.                   |
| `--no-hydra`                       | Start Subsocial stack without Hydra processor and query-node. |
| `--no-postgres`                    | Start Subsocial stack without PostgreSQL database.            |
| `--only-offchain`                  | Start (or update) only Offchain container.                    |
| `--only-substrate`                 | Start (or update) only Substrate node's container.            |
| `--only-proxy`                     | Start (or update) only Caddy server proxy container.          |
| `--only-ipfs`                      | Start (or update) only IPFS Cluster container.                |
| `--only-hydra`                     | Start (or update) only Hydra processor and query-node.        |
| `--only-postgres`                  | Start (or update) only PostgreSQL database.                   |
| `--substrate-url`                  | Specify Substrate websocket URL. Example: `./start.sh --global --substrate-url ws://172.15.0.20:9944` |
| `--offchain-url`                   | Specify Offchain URL. Example: `./start.sh --global --offchain-url http://172.15.0.3:3001` |
| `--elastic-url`                    | Specify ElasticSearch cluster URL. Example: `./start.sh --global --elastic-url http://172.15.0.5:9200` |
| `--ipfs-ip <readonly/cluster/all>` | Specify custom IPFS IP for IPFS Gateway (readonly), IPFS Cluster or both. |
| `--substrate-extra-opts`           | Start Substrate node with additional Substrate CLI options. Example: `./start.sh --substrate-extra-opts "--dev --name my-subsocial-node"` |
| `--substrate-mode <rpc/validator>` | Start Substrate in a specified mode (`rpc` or `validator`). By default (when isn't specified) starts both nodes RPC and Authority (validator). |
| `--cluster-id`                     | Show IPFS Cluster peers if it's running. |
| `--cluster-peers <add/remove/override>`| Add, remove or override trusted peers to/from IPFS Cluster. Example: `./start.sh --cluster-peers add '["*"]'` |
| `--cluster-bootstrap "list"`       | Specify initial IPFS Cluster peers as if it's done via `ipfs-cluster-service` CLI. Example: `./start.sh --cluster-bootstrap "/ip4/<FIRST_IP>/tcp/9066/<FIRST_IDENTITY_ID>, /ip4/<SECOND_IP>/tcp/9066/<SECOND_IDENTITY_ID>"` |
| `--cluster-mode <crdt/raft>`       | Specify IPFS Cluster consensus mode, which can be `crdt` or `raft`. |
| `--cluster-secret`                 | Specify IPFS Cluster secret if consensus is RAFT. Cluster secret must be equal across all cluster nodes. |
| `--cluster-peername`               | Specify IPFS Cluster peer name. Each Cluster node must have its own unique peer name. |
| `--offchain-cors`                  | Specify Offchain CORS (from what URL or IP it will be accessible). Example: `./start.sh --only-offchain --offchain-cors "https://mydomain.com"` |
| `--offchain-cmd`                   | Override default startup command for offchain image. Example: `./start.sh --only-offchain --offchain-cmd "yarn api"` |
| `--show-ports`                     | Show ports of the current instance. Example: `./start.sh --instance backup --show-ports` |
| `--unsafe-expose-ports`            | Make Docker to unsafely expose ports outside of local machine. |

## License

Subsocial is [GPL 3.0](./LICENSE) licensed.
