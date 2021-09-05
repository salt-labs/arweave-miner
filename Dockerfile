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

#########################
# STAGE: BUILD
# Description: Build the app
#########################

FROM docker.io/debian:buster-slim AS BUILD

ARG ARWEAVE_URL

WORKDIR /build

ADD ${ARWEAVE_URL} arweave.tar.gz

RUN tar -xzvf arweave.tar.gz \
 && rm -f arweave.tar.gz

#########################
# STAGE: CERTS
# Description: Generate latest ca-certificates
#########################

FROM docker.io/debian:buster-slim AS CERTS

# hadolint ignore=DL3008
RUN \
    apt-get update \
 && apt-get install -y \
    --no-install-recommends \
    ca-certificates && \
    cat /etc/ssl/certs/* > /ca-certificates.crt

#########################
# STAGE: RUN
# Description: Run the app
#########################

FROM docker.io/debian:buster-slim as RUN

ARG VERSION
ARG ARWEAVE_VERSION

LABEL name="arweave-miner" \
    maintainer="MAHDTech <MAHDTech@saltlabs.tech>" \
    vendor="Salt Labs" \
    version="${VERSION}" \
    arweave_version="${ARWEAVE_VERSION}" \
    summary="Unofficial Arweave miner" \
    url="https://github.com/salt-labs/arweave-miner" \
    org.opencontainers.image.source="https://github.com/salt-labs/arweave-miner"

EXPOSE 1984

WORKDIR /arweave

# hadolint ignore=DL3018
RUN DEBIAN_FRONTEND="noninteractive" \
    apt update \
 && apt upgrade -y \
 && apt install -y \
        bash \
        curl \
        git \
        gnupg \
        jq \
        tzdata \
        wget \
        zip \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
    /arweave/config \
    /arweave/logs \
    /data

COPY --from=BUILD "/build" "/arweave"
COPY --from=CERTS "/ca-certificates.crt" "/etc/ssl/ca-certificates.crt"

COPY "scripts" "/scripts"

COPY files/sysctl/01-arweave.conf /etc/sysctl.d/01-arweave.conf
#COPY files/arweave/arweave.conf /arweave/config/arweave.conf

ENV PATH /arweave:/scripts/:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/bin:/sbin

ENV HOME /arweave

ENTRYPOINT [ "/scripts/entrypoint.sh" ]
#CMD [ "--help" ]
