
# Subsocial Starter by [DappForce](https://github.com/dappforce)
Starts entire Subsocial stack with one shell script. 

## Requirements

You should have Linux or macOS with [Docker](https://www.docker.com/get-started) and [Docker Compose](https://docs.docker.com/compose/) installed.

To test that Docker installed correctly, try to run the next commands - none of them should fail.

```bash
docker images
docker ps
docker run --rm -it -p 80:80 nginx
```

## Get started

If you're new to Subsocial, it's best to start with the defaults:

```bash
git clone git@github.com:dappforce/dappforce-subsocial-starter.git
cd dappforce-subsocial-starter

./start.sh 
```

### Possible issues on Linux

If you are using Linux and having permission issues with Docker, then you may want to do this:

```bash
sudo systemctl enable docker
sudo systemctl disable docker
```

Then logout and log back in and all the Docker commands you find online should work fine without sudo.

## Options

The [start.sh](start.sh) script comes with a set of options for customizing project startup.

| Argument                 | Description                                                                                          |
| ------------------------ | ---------------------------------------------------------------------------------------------------- |
| `--global`               | Binds the project parts to global IP visible on ifconfig.me
| `--force-pull`           | Pull Docker images tagged _latest_ if only `--tag` isn't specified
| `--tag`                  | Specify Docker images tag
| `--prune (all-volumes)`  | Remove the Docker containers. If `all-volumes` is specified, remove volumes as well
| `--no-offchain`          | Start Subsocial stack without offchain storage and Elasticsearch
| `--no-substrate`         | Start Subsocial stack without Substrate node
| `--no-webui`             | Start Subsocial stack without Web UI
| `--no-apps`              | Start Subsocial stack without JS Apps
| `--only-offchain`        | Start (or update) only offchain container
| `--only-substrate`       | Start (or update) only Substrate node's container
| `--only-webui`           | Start (or update) only Web UI container
| `--only-apps`            | Start (or update) only JS Apps container
| `--substrate-url`        | Specify Substrate websocket URL. Example: `./start.sh --global --substrate-url ws://172.15.0.20:9944`
| `--offchain-url`         | Specify Offchain URL. Example: `./start.sh --global --offchain-url http://172.15.0.3:3001`
| `--elastic-url`          | Specify Elasticsearch cluster URL. Example: `./start.sh --global --elastic-url http://172.15.0.5:9200`
| `--webui-ip`             | Specify Web UI ip address. Example: `./start.sh --global --substrate-url http://172.15.0.2`
| `--apps-url`             | Specify JS Apps URL. Example: `./start.sh --global --apps-url http://172.15.0.6:3002`

### Web UI

By default it will start one container for Web UI. If it is running, you can open the **Subsocial** in your browser:

[http://localhost/](http://localhost)

This one can be managed with `--no-webui` and `--only-webui` flags.

| Container name     | External Port | Local URL        | Description   |
| ------------------ | ------------- | ---------------- | ------------- |
| `subsocial-web-ui` | `80`          | http://localhost | [Subsocial UI](https://github.com/dappforce/dappforce-subsocial-ui)

### JS Apps

By default it will start one container for JS Apps. If it is running, you can successfully go to the 'Advanced' tab in the Web UI side-menu:

[http://localhost:3002/](http://localhost:3002)

This one can be managed with `--no-apps` and `--only-apps` flags.

| Container name     | External Port | Local URL             | Description     |
| ------------------ | ------------- | --------------------- | --------------- |
| `subsocial-apps` | `3002`          | http://localhost:3002 | [Subsocial Apps](https://github.com/dappforce/dappforce-subsocial-apps)

### Offchain storage

By default it will start three containers: PostgreSQL, ElasticSearch and offchain (Substrate events handler, Subsocial API) itself.

This one can be managed with `--no-offchain` and `--only-offchain` flags.

| Container name            | External Port   | Local URL                | Description         |
| ------------------------- | --------------- | ------------------------ | ------------------- |
| `subsocial-offchain`      | `3001`          | http://localhost:3001/v1 | [Subsocial Offchain](https://github.com/dappforce/dappforce-subsocial-offchain)
| `subsocial-elasticsearch` | `9200`          | http://localhost:9200    | [Elasticsearch](https://www.elastic.co/what-is/elasticsearch)
| `subsocial-postgres`      |                 |                          | [PostgreSQL](https://www.postgresql.org/about/)

### Substrate node

By  default it will start two local validator nodes in Docker containers: Alice and Bob. Offchain and others connect to Alice's node, because it's external.

Additional options can be added using `--substrate-extra-opts` (beta).
This one can be managed with `--no-substrate` and `--only-substrate` flags.

| Container name          | External Port   | Local URL             | Description                  |
| ----------------------- | --------------- | --------------------- | ---------------------------- |
| `subsocial-node-alice`  | `9944`          | http://localhost:9944 |
| `subsocial-node-bob`    |                 |                       | Local chain of Substrate Node
