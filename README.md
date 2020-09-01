
# Subsocial Starter by [DappForce](https://github.com/dappforce)

Starts entire Subsocial stack with one shell script.

To learn more about Subsocial, please visit [Subsocial Network](http://subsocial.network).

## Supported by Web3 Foundation

<img src="https://github.com/dappforce/dappforce-subsocial/blob/master/w3f-badge.svg" width="100%" height="200" alt="Web3 Foundation grants badge" />

Subsocial is a recipient of the technical grant from Web3 Foundation. We have successfully delivered all three milestones described in Subsocial's grant application. [Official announcement](https://medium.com/web3foundation/web3-foundation-grants-wave-3-recipients-6426e77f1230).

## Requirements

You should have Linux or macOS with [Docker](https://www.docker.com/get-started) and [Docker Compose](https://docs.docker.com/compose/) installed.

To test that Docker installed correctly, try to run the next commands - none of them should fail.

```bash
docker images
docker ps
docker run --rm -it -p 80:80 nginx
```

## Get Started

If you're new to Subsocial, it's best to start with the defaults:

```bash
git clone git@github.com:dappforce/dappforce-subsocial-starter.git
cd dappforce-subsocial-starter

./start.sh 
```

### Launch Subsocial based on Substrate v2

First of all, you have to clone a starter repo:
```bash
git clone git@github.com:dappforce/dappforce-subsocial-starter.git
cd dappforce-subsocial-starter 
```

There are two ways of starting Subsocial.
If you want to play with Subsocial and launch it as an independent node that is not accessible from outside and not connected to the [official](http://subsocial.network) Subsocial network:
```bash
./start.sh --tag df-v2
```
If you want to launch your own Subsocial network that is accessible from outside, yet independent and not connected to the [official](http://subsocial.network) Subsocial network:
```bash
./start.sh --tag df-v2 --global
```

If you want to launch only some parts of Subsocial (e.g. offchain only) or specify custom URLs of other parts, then you can use flags listed in the section [Options](#options).

### Possible issues on Linux

If you are using Linux and having permission issues with Docker, then you may want to do this:

```bash
sudo systemctl enable docker
sudo systemctl disable docker
```

Then logout and log back in and all the Docker commands you find online should work fine without sudo.

## Options

The [start.sh](start.sh) script comes with a set of options for customizing project startup.

| Argument                          | Description                                                                                          |
| --------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `--global`                        | Binds the project parts to global IP visible on ifconfig.me
| `--force-pull`                    | Pull Docker images tagged _latest_ if only `--tag` isn't specified
| `--tag`                           | Specify Docker images tag
| `--prune (all-volumes)`           | Remove the Docker containers. If `all-volumes` is specified, remove volumes as well
| `--no-offchain`                   | Start Subsocial stack without offchain storage and Elasticsearch
| `--no-substrate`                  | Start Subsocial stack without Substrate node
| `--no-webui`                      | Start Subsocial stack without Web UI
| `--no-apps`                       | Start Subsocial stack without JS Apps
| `--no-proxy`                      | Start Subsocial stack without NGINX proxy
| `--no-ipfs`                       | Start Subsocial stack without IPFS Cluster
| `--only-offchain`                 | Start (or update) only offchain container
| `--only-substrate`                | Start (or update) only Substrate node's container
| `--only-webui`                    | Start (or update) only Web UI container
| `--only-apps`                     | Start (or update) only JS Apps container
| `--only-proxy`                    | Start (or update) only NGINX proxy container
| `--only-ipfs`                     | Start (or update) only IPFS Cluster container
| `--substrate-url`                 | Specify Substrate websocket URL. Example: `./start.sh --global --substrate-url ws://172.15.0.20:9944`
| `--offchain-url`                  | Specify Offchain URL. Example: `./start.sh --global --offchain-url http://172.15.0.3:3001`
| `--elastic-url`                   | Specify Elasticsearch cluster URL. Example: `./start.sh --global --elastic-url http://172.15.0.5:9200`
| `--webui-ip`                      | Specify Web UI ip address. Example: `./start.sh --global --substrate-url http://172.15.0.2`
| `--apps-url`                      | Specify JS Apps URL. Example: `./start.sh --global --apps-url http://172.15.0.6:3002`
| `--substrate-extra-opts`          | Start Substrate node with additional Substrate CLI arguments. Example: `./start.sh --substrate-extra-opts "--dev --name my-subsocial-node"`
| `--substrate-mode <rpc/validator>`| Start Substrate in a specified mode (`rpc` or `validator`). By default (when isn't specified) starts both nodes RPC and Authority (validator).
| `--cluster-peers`                 | Shows IPFS Cluster peers if it's running.
| `--cluster-bootstrap "list"`      | Specify initial IPFS Cluster peers as if it's done via `ipfs-cluster-service` CLI. Example: `./start.sh --cluster-bootstrap "/ip4/FIRST_IP/tcp/9066/FIRST_IDENTITY_ID, /ip4/SECOND_IP/tcp/9066/SECOND_IDENTITY_ID"`
| `--cluster-identity-path "path"`  | Specify IPFS Cluster `identity.json` to copy to initial cluster config. 

### Proxy

By default it will start one Nginx container with automatically configured proxy. If it is running, you can open the **Web UI** or **Blockchain Explorer** .

| Container name     | External Port | Local URL        | Description   |
| ------------------ | ------------- | ---------------- | ------------- |
| `subsocial-proxy`  | `80`          |

### Web UI

By default it will start one container for Web UI. If it is running, you can open the **Subsocial** in your browser:

[http://localhost/](http://localhost)

This one can be managed with `--no-webui` and `--only-webui` flags.

| Container name     | External Port | Local URL        | Description   |
| ------------------ | ------------- | ---------------- | ------------- |
| `subsocial-web-ui` |               | http://localhost | [Subsocial UI](https://github.com/dappforce/dappforce-subsocial-ui)

### Blockchain Explorer (aka JS Apps)

By default it will start one container for JS Apps. If it is running, you can successfully go to the 'Advanced' tab in the Web UI side-menu:

[http://localhost/bc](http://localhost/bc)

This one can be managed with `--no-apps` and `--only-apps` flags.

| Container name     | External Port | Local URL             | Description     |
| ------------------ | ------------- | --------------------- | --------------- |
| `subsocial-apps`   |               | http://localhost/bc   | [Subsocial Apps](https://github.com/dappforce/dappforce-subsocial-apps)

### Off-chain Storage

By default it will start three containers: PostgreSQL, ElasticSearch and offchain (Substrate events handler, Subsocial API) itself.

This one can be managed with `--no-offchain` and `--only-offchain` flags.

| Container name            | External Ports  | Local URL                | Description         |
| ------------------------- | --------------- | ------------------------ | ------------------- |
| `subsocial-offchain`      | `3001`, `3011`  | http://localhost:3001/v1 | [Subsocial Offchain](https://github.com/dappforce/dappforce-subsocial-offchain)
| `subsocial-elasticsearch` | `9200`          | http://localhost:9200    | [Elasticsearch](https://www.elastic.co/what-is/elasticsearch)
| `subsocial-postgres`      |                 |                          | [PostgreSQL](https://www.postgresql.org/about/)

### IPFS Cluster

By default it will start two containers: IPFS Cluster and IPFS Node (Gateway).

This can be managed with `--no-ipfs`, `--only-ipfs` and `--cluster-peers` flags.\
**!!EXPERIMENTAL!!:** you can specify `identity.json` and initial peers (bootnodes) with `--cluster-identity-path` and `--cluster-bootstrap` to be able to connect as a cluster peer. 

| Container name            | External Ports  | Local URL                | Description         |
| ------------------------- | --------------- | ------------------------ | ------------------- |
| `subsocial-ipfs-node`     | `8080`          | http://localhost:8080    | [IPFS Node](https://github.com/ipfs/go-ipfs/blob/master/README.md)
| `subsocial-ipfs-cluster`  | `9094`, `9096`  | http://localhost:9094    | [IPFS Cluster](https://github.com/ipfs/ipfs-cluster/blob/master/README.md)

### Substrate Node

By  default it will start two local validator nodes in Docker containers: Alice and Bob. Offchain and others connect to Alice's node, because it's external.

Additional options can be added using `--substrate-extra-opts`.
This one can be managed with `--no-substrate`, `--only-substrate` and `--substrate-mode` flags.

| Container name            | External Port   | Local URL             | Description                  |
| ------------------------- | --------------- | --------------------- | ---------------------------- |
| `subsocial-node-rpc`      | `9944`          | ws://localhost:9944   | RPC sync node
| `subsocial-node-validator`| `30334`         |                       | Archive authority node


## License

Subsocial is [GPL 3.0](./LICENSE) licensed.
