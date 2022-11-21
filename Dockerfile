FROM debian:stable-slim as builder

# defined from build kit
# DOCKER_BUILDKIT=1 docker build . -t ...
ARG TARGETARCH

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
    git curl gnupg2 build-essential \
    cmake g++-10 libboost-all-dev libc6-dev \ 
    openssl libssl-dev pkg-config \
    ca-certificates apt-transport-https \
  python3 && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

## SOLC
WORKDIR /solidity

ARG SOLC_VERSION=0.8.17
ADD https://github.com/ethereum/solidity/archive/refs/tags/v${SOLC_VERSION}.tar.gz /solidity/solidity-${SOLC_VERSION}.tar.gz
RUN tar -zxvf /solidity/solidity-${SOLC_VERSION}.tar.gz -C /solidity

WORKDIR /solidity/solidity-${SOLC_VERSION}/build
# disable tests on arm due to the length of build in intel emulation
RUN echo 8df45f5f8632da4817bc7ceb81497518f298d290 | tee ../commit_hash.txt && \
    cmake -DCMAKE_BUILD_TYPE=Release -DSTRICT_Z3_VERSION=OFF -DUSE_CVC4=OFF -DUSE_Z3=OFF -DPEDANTIC=OFF .. && \
    CMAKE_BUILD_PARALLEL_LEVEL=2 cmake --build . --config Release && \
    make install \
    || :

RUN for exe in solc yul-phaser solidity-upgrade; do echo strip ${exe}; strip /usr/local/bin/${exe}; done

FROM debian:stable-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
  apt update && \
  apt install -y -q --no-install-recommends \
  git gnupg2 curl build-essential \
  ca-certificates apt-transport-https && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

# SOLC
COPY --from=builder /usr/local/bin/solc /usr/local/bin
COPY --from=builder /usr/local/bin/yul-phaser /usr/local/bin
COPY --from=builder /usr/local/bin/solidity-upgrade /usr/local/bin

RUN solc --version
