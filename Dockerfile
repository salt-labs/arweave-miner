##################################################
# Notes for GitHub Actions
#       * Dockerfile instructions: https://git.io/JfGwP
#       * Environment variables: https://git.io/JfGw5
##################################################

#########################
# STAGE: GLOBAL
# Description: Global args for reuse
#########################

ARG VERSION="0"

ARG ARWEAVE_VERSION="0"
ARG ARWEAVE_ARCH="x86_64"
ARG ARWEAVE_URL="https://github.com/ArweaveTeam/arweave/releases/download/N.${ARWEAVE_VERSION}/arweave-${ARWEAVE_VERSION}.linux-${ARWEAVE_ARCH}.tar.gz"

ARG ARWEAVE_TOOLS_URL="https://github.com/francesco-adamo/arweave-tools"

#########################
# Arweave
#########################

FROM docker.io/debian:buster-slim AS arweave

ARG VERSION
ARG ARWEAVE_VERSION
ARG ARWEAVE_URL
ARG ARWEAVE_TOOLS_URL

LABEL \
    name="arweave-miner" \
    maintainer="MAHDTech <MAHDTech@saltlabs.tech>" \
    vendor="Salt Labs" \
    version="${VERSION}" \
    arweave_version="${ARWEAVE_VERSION}" \
    summary="Unofficial Arweave miner" \
    url="https://github.com/salt-labs/arweave-miner" \
    org.opencontainers.image.source="https://github.com/salt-labs/arweave-miner"

EXPOSE 1984

WORKDIR /arweave

# hadolint ignore=DL3018,DL3008
RUN export DEBIAN_FRONTEND="noninteractive" \
 && apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y \
    --no-install-recommends \
    bash \
    bc \
    ca-certificates \
    curl \
    git \
    gnupg \
    htop \
    iputils-ping \
    jq \
    nodejs \
    npm \
    procps \
    rocksdb-tools \
    tzdata \
    vim \
    wget \
    zip \
 && rm -rf /var/lib/apt/lists/*

# Check versions
RUN node -v

# hadolint ignore=DL3018,DL3008
RUN wget \
    --progress=dot:giga \
    --output-document \
    arweave.tar.gz \
    "${ARWEAVE_URL}" \
 && tar -xzvf arweave.tar.gz \
 && rm -f arweave.tar.gz

RUN mkdir utilities \
 && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
 && apt-get install -y nodejs \
 && git \
    clone \
    "${ARWEAVE_TOOLS_URL}" \
    "utilities/arweave-tools" \
 && cd "utilities/arweave-tools" \
 && npm install

COPY "scripts" "/scripts"

COPY files/etc/sysctl.d/01-arweave.conf /etc/sysctl.d/01-arweave.conf
COPY files/etc/security/limits.d/01-arweave.conf /etc/security/limits.d/01-arweave.conf
#COPY files/arweave/arweave.conf /arweave/config/arweave.conf

RUN mkdir -p \
    /arweave/config \
    /arweave/logs \
    /arweave/utilities \
    /data

RUN useradd \
    --home-dir /arweave \
    --create-home \
    --shell /bin/bash \
    arweave \
 && chown \
    --recursive \
    arweave:arweave \
    /arweave \
    /data

USER arweave

ENV HOME /arweave

ENV PATH /arweave:/scripts/:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/bin:/sbin

HEALTHCHECK \
       --interval=5m \
       --timeout=5s \
       --start-period=300s \
       --retries=3 \
       CMD "/scripts/healthcheck.sh"

ENTRYPOINT [ "/scripts/entrypoint.sh" ]
#CMD [ "--help" ]
