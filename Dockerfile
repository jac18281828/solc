# Stage 1: Build yamlfmt
FROM golang:1 AS go-builder
# defined from build kit
# DOCKER_BUILDKIT=1 docker build . -t ...
ARG TARGETARCH

# Install yamlfmt
WORKDIR /yamlfmt
RUN go install github.com/google/yamlfmt/cmd/yamlfmt@latest && \
    strip $(which yamlfmt) && \
    yamlfmt --version

# Stage 2: solc docker container
FROM debian:stable-slim AS builder
ARG MAXIMUM_THREADS=16

# defined from build kit
# DOCKER_BUILDKIT=1 docker build . -t ...
ARG TARGETARCH

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    gnupg2 \
    libboost-all-dev \
    libc6-dev \
    libssl-dev \
    openssl \
    pkg-config \
    python3 \
    && \
  apt clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## SOLC
WORKDIR /solidity

ARG SOLC_VERSION=0.8.28
ADD https://github.com/ethereum/solidity/releases/download/v${SOLC_VERSION}/solidity_${SOLC_VERSION}.tar.gz /solidity/solidity_${SOLC_VERSION}.tar.gz
RUN tar -zxf /solidity/solidity_${SOLC_VERSION}.tar.gz -C /solidity

WORKDIR /solidity/solidity_${SOLC_VERSION}/build

# https://github.com/ethereum/solidity/commit/7893614a31fbeacd1966994e310ed4f760772658
# disable tests on arm due to the length of build in intel emulation
RUN echo 7893614a31fbeacd1966994e310ed4f760772658 | tee ../commit_hash.txt && \
    THREAD_NUMBER=$(cat /proc/cpuinfo | grep -c ^processor) && \
    MAX_THREADS=$(( THREAD_NUMBER > ${MAXIMUM_THREADS} ?  ${MAXIMUM_THREADS} : THREAD_NUMBER )) && \
    echo "building with ${MAX_THREADS} threads" && \
    cmake -DCMAKE_BUILD_TYPE=Release -DSTRICT_Z3_VERSION=OFF -DUSE_CVC4=OFF -DUSE_Z3=OFF -DPEDANTIC=OFF .. && \
    CMAKE_BUILD_PARALLEL_LEVEL=${MAX_THREADS} cmake --build . --config Release && \
    make install \
    || :

RUN for exe in solc yul-phaser; do echo strip ${exe}; strip /usr/local/bin/${exe}; done

FROM debian:stable-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg2 \
    python3 \
    && \
  apt clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=go-builder /go/bin/yamlfmt /go/bin/yamlfmt

COPY ./bin/sha3sum /usr/local/bin/sha3sum

# SOLC
COPY --from=builder /usr/local/bin/solc /usr/local/bin
COPY --from=builder /usr/local/bin/yul-phaser /usr/local/bin

ENV SOLC_PATH=/usr/local/etc/solc
RUN mkdir -p ${SOLC_PATH}
RUN for exe in solc yul-phaser; do echo ${exe}; sha3sum /usr/local/bin/${exe} | tee ${SOLC_PATH}/${exe}.sha3; done

CMD solc --version

ENV PATH=${PATH}:/usr/local/bin:/go/bin

LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.name="solc" \
    org.label-schema.description="SOLC Development Container" \
    org.label-schema.url="https://github.com/jac18281828/solc" \
    org.label-schema.vcs-url="git@github.com:jac18281828/solc.git" \
    org.label-schema.vendor="John Cairns" \
    org.label-schema.version=$VERSION \
    org.label-schema.schema-version="1.0" \
    org.opencontainers.image.description="Ethereum/solidity solc container"
