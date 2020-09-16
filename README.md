# Subsocial Starter by [DappForce](https://github.com/dappforce)

This guide will walk you through starting an entire Subsocial stack with just one shell script.

To learn more about Subsocial, please visit us at [Subsocial.Network](http://subsocial.network/).



## Supported by Web3 Foundation

[![Web3 Foundation grants badge](https://github.com/dappforce/dappforce-subsocial/raw/master/w3f-badge.svg)](https://github.com/dappforce/dappforce-subsocial/blob/master/w3f-badge.svg)

Subsocial is the recipient of a technical grant from Web3 Foundation - [official announcement](https://medium.com/web3foundation/web3-foundation-grants-wave-3-recipients-6426e77f1230). We have successfully delivered on all three milestones submitted in our grant application. 



## Requirements

Linux environment or macOS with [Docker](https://www.docker.com/get-started) and [Docker Compose](https://docs.docker.com/compose/) installed.

1. Test that Docker was installed correctly, try to run the following commands:
   *NOTE: none of the commands should fail*

```
docker images
docker ps
docker run --rm -it -p 80:80 nginx
```

#### Possible issues on Linux

If you are using Linux and having a permission issue with Docker, try running the following commands:

```
sudo systemctl enable docker
sudo systemctl disable docker
```

After running the commands, logout and log back in.  The Docker commands should now run without sudo.



## Getting Started

### Easy start

If you're new to Subsocial, it is best to start with the defaults.

1. Clone a starter repo:


```
git clone https://github.com/dappforce/dappforce-subsocial-starter.git
cd dappforce-subsocial-starter 
```

2. Start the entire Subsocial project locally:

```
./start.sh --substrate-mode rpc --substrate-extra-opts "--dev"
```



### Launch Subsocial parts one by one

#### Substrate Nodes

| Container name             | External Port | Local URL           | Description            |
| -------------------------- | ------------- | ------------------- | ---------------------- |
| `subsocial-node-rpc`       | `9944`        | ws://localhost:9944 | RPC sync node          |
| `subsocial-node-validator` | `30334`       |                     | Archive authority node |

##### Starting Substrate Nodes

By default two nodes will be started: *validator* and *RPC*.

​	We will use `--only-substrate` to run only Substrate nodes:

```
./start.sh --only-substrate
```

​	If you would like to start archive RPC. The command below is the only available method (for now) which is connected to Subsocial network:

```
./start.sh --only-substrate --substrate-mode-rpc --substrate-extra-opts "--name MyNodeName --pruning archive"
```

​	However, you will have no ability to manage anything inside of them. To do this, you may want to launch Substrate node with extra option `--dev`.

​	*For example*:

```
./start.sh --only-substrate --substrate-mode rpc --substrate-extra-opts "--dev"
```

​	Here we also used the `--substrate-mode rpc` argument. That is because running in development mode we do not need any validators.

##### Stopping Substrate Nodes

To stop Substrate nodes:

```
./start.sh --only-substrate --stop
```

​	If you want not only stop containers, but also clean data, go with:

```
./start.sh --only-substrate --stop purge-volumes
```

#### Off-chain Storage

| Container name            | External Ports | Local URL                                       | Description                                                  |
| ------------------------- | -------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| `subsocial-offchain`      | `3001`, `3011` | http://localhost:3001/v1                        | [Subsocial Offchain](https://github.com/dappforce/dappforce-subsocial-offchain) |
| `subsocial-elasticsearch` | `9200`         | [http://localhost:9200](http://localhost:9200/) | [Elasticsearch](https://www.elastic.co/what-is/elasticsearch) |
| `subsocial-postgres`      |                |                                                 | [PostgreSQL](https://www.postgresql.org/about/)              |

By default, three containers will be started: PostgreSQL, ElasticSearch and offchain (Substrate events handler, Subsocial API).

​	We will use `--only-offchain` to run offchain only:

```
./start.sh --only-offchain
```

​	In most cases you will want to launch offchain on a separate server. If so, you will want to use next command:

```
./start.sh --global --only-substrate --substrate-url <Websocket endpoint> --offchain-cors "<UI URL>"
```

To start offchain without IPFS (considering running it on another server) by following the next steps:

- [Run IPFS](https://github.com/LearnPolkadot/dappforce-subsocial-starter/blob/master/README.md#ipfs-cluster) on external server

- Run offchain with next arguments:

```
./start.sh --only-offchain --no-ipfs --ipfs-ip all <IPFS hosting server IP>
```

#### IPFS Cluster

| Container name           | External Ports | Local URL                                       | Description                                                  |
| ------------------------ | -------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| `subsocial-ipfs-node`    | `8080`         | [http://localhost:8080](http://localhost:8080/) | [IPFS Node](https://github.com/ipfs/go-ipfs/blob/master/README.md) |
| `subsocial-ipfs-cluster` | `9094`, `9096` | [http://localhost:9094](http://localhost:9094/) | [IPFS Cluster](https://github.com/ipfs/ipfs-cluster/blob/master/README.md) |

By default it will start two containers: IPFS Cluster and IPFS Node (Gateway).

​	We use `--only-ipfs` to run IPFS only:

```
./start.sh --only-ipfs --offchain-url <Offchain URL>
```

`--offchain-url` is mandatory here, because of CORS are used for IPFS cluster access.

⚠️ ***Experimentally*** ⚠️ you can specify `identity.json` and initial peers (bootnodes) with `--cluster-identity-path` and `--cluster-bootstrap` to be able to connect to Subsocial as a cluster peer **(this may not work yet)**.

------



### Advanced

#### Startup Options 

The [start.sh](https://github.com/LearnPolkadot/dappforce-subsocial-starter/blob/master/start.sh) script comes with a set of options for customizing project startup.

| Argument                           | Description                                                  |
| ---------------------------------- | ------------------------------------------------------------ |
| `--global`                         | Binds the project parts to global IP visible on ifconfig.me  |
| `--force-pull`                     | Pull Docker images tagged *latest* if only `--tag` isn't specified |
| `--tag`                            | Specify Docker images tag                                    |
| `--stop (purge-volumes)`           | Stop and delete the Docker containers. If `purge-volumes` is specified, delete volumes as well |
| `--no-offchain`                    | Start Subsocial stack without offchain storage and Elasticsearch |
| `--no-substrate`                   | Start Subsocial stack without Substrate node                 |
| `--no-webui`                       | Start Subsocial stack without Web UI                         |
| `--no-apps`                        | Start Subsocial stack without JS Apps                        |
| `--no-proxy`                       | Start Subsocial stack without NGINX proxy                    |
| `--no-ipfs`                        | Start Subsocial stack without IPFS Cluster                   |
| `--only-offchain`                  | Start (or update) only offchain container                    |
| `--only-substrate`                 | Start (or update) only Substrate node's container            |
| `--only-webui`                     | Start (or update) only Web UI container                      |
| `--only-apps`                      | Start (or update) only JS Apps container                     |
| `--only-proxy`                     | Start (or update) only NGINX proxy container                 |
| `--only-ipfs`                      | Start (or update) only IPFS Cluster container                |
| `--substrate-url`                  | Specify Substrate websocket URL. Example: `./start.sh --global --substrate-url ws://172.15.0.20:9944` |
| `--offchain-url`                   | Specify Offchain URL. Example: `./start.sh --global --offchain-url http://172.15.0.3:3001` |
| `--elastic-url`                    | Specify Elasticsearch cluster URL. Example: `./start.sh --global --elastic-url http://172.15.0.5:9200` |
| `--webui-ip`                       | Specify Web UI ip address. Example: `./start.sh --global --substrate-url http://172.15.0.2` |
| `--apps-url`                       | Specify JS Apps URL. Example: `./start.sh --global --apps-url http://172.15.0.6:3002` |
| `--ipfs-ip <readonly/cluster/all>` | Specify custom IPFS ip for IPFS Gateway (readonly), IPFS Cluster or both. |
| `--substrate-extra-opts`           | Start Substrate node with additional Substrate CLI arguments. Example: `./start.sh --substrate-extra-opts "--dev --name my-subsocial-node"` |
| `--substrate-mode <rpc/validator>` | Start Substrate in a specified mode (`rpc` or `validator`). By default (when isn't specified) starts both nodes RPC and Authority (validator). |
| `--cluster-peers`                  | Shows IPFS Cluster peers if it's running.                    |
| `--cluster-bootstrap "list"`       | Specify initial IPFS Cluster peers as if it's done via `ipfs-cluster-service` CLI. Example: `./start.sh --cluster-bootstrap "/ip4/FIRST_IP/tcp/9066/FIRST_IDENTITY_ID, /ip4/SECOND_IP/tcp/9066/SECOND_IDENTITY_ID"` |
| `--cluster-identity-path "path"`   | Specify IPFS Cluster `identity.json` to copy to initial cluster config. |
| `--offchain-cors`                  | Specify offchain CORS (from what URL or IP it will be accessible). Example: `./start.sh --only-offchain --offchain-cors "https://mydomain.com"` |

#### Proxy

By default the project will start one Nginx container with automatically configured proxy. If it is running, you can open the **[Web UI](https://github.com/LearnPolkadot/dappforce-subsocial-starter/blob/master/README.md#web-ui)** or **[Blockchain Explorer](https://github.com/LearnPolkadot/dappforce-subsocial-starter/blob/master/README.md#blockchain-explorer-aka-js-apps)** .

| Container name    | External Port | Local URL | Description |
| ----------------- | ------------- | --------- | ----------- |
| `subsocial-proxy` | `80`          |           |             |

#### Web UI

By default the project will start one container for the Web UI. If running, you can open the **Subsocial** in your browser:

http://localhost/

This can be managed with `--no-webui` and `--only-webui` flags.

| Container name     | External Port | Local URL                             | Description                                                  |
| ------------------ | ------------- | ------------------------------------- | ------------------------------------------------------------ |
| `subsocial-web-ui` |               | [http://localhost](http://localhost/) | [Subsocial UI](https://github.com/dappforce/dappforce-subsocial-ui) |

#### Blockchain Explorer (aka JS Apps)

By default the project will start one container for JS Apps. If it is running, you can successfully go to the '*Advanced*' tab in the Web UI side-menu:

http://localhost/bc

This can be managed with `--no-apps` and `--only-apps` flags.

| Container name   | External Port | Local URL           | Description                                                  |
| ---------------- | ------------- | ------------------- | ------------------------------------------------------------ |
| `subsocial-apps` |               | http://localhost/bc | [Subsocial Apps](https://github.com/dappforce/dappforce-subsocial-apps) |



## License

Subsocial is [GPL 3.0](https://github.com/LearnPolkadot/dappforce-subsocial-starter/blob/master/LICENSE) licensed.
