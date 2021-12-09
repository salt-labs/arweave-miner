# Readme

**NOTE:** Here be 🐉 dragons, this is early testing software.

## Workflow Status

| Status | Description |
| :----- | :---------- |
| ![Dependabot](https://api.dependabot.com/badges/status?host=github&repo=salt-labs/arweave-miner) | Automated dependency updates |
| ![Greetings](https://github.com/salt-labs/arweave-miner/workflows/Greetings/badge.svg) | Greets new users to the project. |
| ![Docker](https://github.com/salt-labs/arweave-miner/workflows/Docker/badge.svg) | Testing and building containers with Docker |
| ![Labeler](https://github.com/salt-labs/arweave-miner/workflows/Labeler/badge.svg) | Automates label addition to issues and PRs |
| ![Release](https://github.com/salt-labs/arweave-miner/workflows/Release/badge.svg) | Ships new releases :ship: |
| ![Stale](https://github.com/salt-labs/arweave-miner/workflows/Stale/badge.svg) | Checks for Stale issues and PRs  |

## Description

Container image for mining ⛏️ on the Arweave Network.

# via: https://docs.docker.com/engine/install/ubuntu/
Install Docker on server

```
apt-get remove docker docker-engine docker.io containerd runc

apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```