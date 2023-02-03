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

ARG SOLC_VERSION=0.8.18
ADD https://github.com/ethereum/solidity/archive/refs/tags/v${SOLC_VERSION}.tar.gz /solidity/solidity-${SOLC_VERSION}.tar.gz
RUN tar -zxvf /solidity/solidity-${SOLC_VERSION}.tar.gz -C /solidity

WORKDIR /solidity/solidity-${SOLC_VERSION}/build
# disable tests on arm due to the length of build in intel emulation
RUN echo 87f61d960cceab32489350726a99c050e6f92c61 | tee ../commit_hash.txt && \
    THREAD_NUMBER=$(cat /proc/cpuinfo | grep processor | wc -l) && \
    echo "using ${THREAD_NUMBER} threads" && \
    [[ "$TARGETARCH" = "arm64" ]] && export CFLAGS=-mno-outline-atomics || true && \
    cmake -DCMAKE_BUILD_TYPE=Release -DSTRICT_Z3_VERSION=OFF -DUSE_CVC4=OFF -DUSE_Z3=OFF -DPEDANTIC=OFF .. && \
    CMAKE_BUILD_PARALLEL_LEVEL=${THREAD_NUMBER} cmake --build . --config Release && \
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

RUN solc --version

LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.name="solc" \
    org.label-schema.description="SOLC Development Container" \
    org.label-schema.url="https://github.com/jac18281828/solc" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="git@github.com:jac18281828/solc.git" \
    org.label-schema.vendor="John Cairns" \
    org.label-schema.version=$VERSION \
    org.label-schema.schema-version="1.0"
