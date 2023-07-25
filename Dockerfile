FROM debian:stable-slim as builder
ARG MAXIMUM_THREADS=8

# defined from build kit
# DOCKER_BUILDKIT=1 docker build . -t ...
ARG TARGETARCH

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
    git curl gnupg2 build-essential \
    cmake libboost-all-dev libc6-dev \
    openssl libssl-dev pkg-config \
    ca-certificates apt-transport-https \
  python3 && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

## SOLC
WORKDIR /solidity

ARG SOLC_VERSION=0.8.21
ADD https://github.com/ethereum/solidity/releases/download/v${SOLC_VERSION}/solidity_${SOLC_VERSION}.tar.gz /solidity/solidity_${SOLC_VERSION}.tar.gz
RUN tar -zxf /solidity/solidity_${SOLC_VERSION}.tar.gz -C /solidity

WORKDIR /solidity/solidity_${SOLC_VERSION}/build


# https://github.com/ethereum/solidity/commit/d9974bed7134e043f7ccc593c0c19c67d2d45dc4
# disable tests on arm due to the length of build in intel emulation
RUN echo d9974bed7134e043f7ccc593c0c19c67d2d45dc4 | tee ../commit_hash.txt && \
    THREAD_NUMBER=$(cat /proc/cpuinfo | grep processor | wc -l) && \
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
    git gnupg2 curl build-essential \
    ca-certificates apt-transport-https \
    python3 \
    && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

RUN mkdir /solc

COPY ./bin/sha3sum /usr/local/bin/sha3sum

# SOLC
COPY --from=builder /usr/local/bin/solc /usr/local/bin
COPY --from=builder /usr/local/bin/yul-phaser /usr/local/bin

RUN for exe in solc yul-phaser; do echo ${exe}; sha3sum /usr/local/bin/${exe} | tee /solc/${exe}.sha3; done

CMD solc --version

LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.name="solc" \
    org.label-schema.description="SOLC Development Container" \
    org.label-schema.url="https://github.com/jac18281828/solc" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="git@github.com:jac18281828/solc.git" \
    org.label-schema.vendor="John Cairns" \
    org.label-schema.version=$VERSION \
    org.label-schema.schema-version="1.0" \
    org.opencontainers.image.description="Ethereum/solidity solc container"
