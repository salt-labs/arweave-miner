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

#ARG ERLANG_VERSION="1:22.3.4.9-1"

#########################
# STAGE: BUILD
# Description: Build the app
#########################

FROM docker.io/debian:buster-slim AS BUILD

ARG ARWEAVE_URL
#ARG ERLANG_VERSION

WORKDIR /build

# hadolint ignore=DL3018,DL3008
RUN export DEBIAN_FRONTEND="noninteractive" \
 &&  apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y \
        --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        gnupg \
        jq \
        tzdata \
        wget \
        zip \
 && rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3018,DL3008
#RUN wget \
#    --progress=dot:giga \
#    --output-document \
#    erlang_solutions.asc \
#    https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc \
# && apt-key add erlang_solutions.asc \
# && rm -f erlang_solutions.asc \
# && echo "deb https://packages.erlang-solutions.com/ubuntu focal contrib" > /etc/apt/sources.list.d/erlang.list

# hadolint ignore=DL3018,DL3008
#RUN export DEBIAN_FRONTEND="noninteractive" \
# && apt-get update \
# && apt-get install -y \
#        --no-install-recommends \
#        esl-erlang=${ERLANG_VERSION} \
# && rm -rf /var/lib/apt/lists/*

RUN wget \
    --progress=dot:giga \
    --output-document \
    arweave.tar.gz \
    "${ARWEAVE_URL}" \
 && tar -xzvf arweave.tar.gz \
 && rm -f arweave.tar.gz

#########################
# STAGE: RUN
# Description: Run the app
#########################

FROM docker.io/debian:buster-slim as RUN

ARG VERSION
ARG ARWEAVE_VERSION

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
       ca-certificates \
       curl \
       git \
       gnupg \
       htop \
       iputils-ping \
       jq \
       procps \
       tzdata \
       vim \
       wget \
       zip \
 && rm -rf /var/lib/apt/lists/*

COPY --from=BUILD "/build" "/arweave"
#COPY --from=BUILD "/ca-certificates.crt" "/etc/ssl/ca-certificates.crt"

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
       --start-period=60s \
       --retries=3 \
       CMD "/scripts/healthcheck.sh"

ENTRYPOINT [ "/scripts/entrypoint.sh" ]
#CMD [ "--help" ]
