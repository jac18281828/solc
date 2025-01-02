#!/usr/bin/env bash

VERSION=$(git rev-parse HEAD | cut -c 1-8)

PROJECT=jac18281828/solc

# cross platform
# --platform=amd64
DOCKER_BUILDKIT=1 docker build --progress plain . -t ${PROJECT}:${VERSION} \
                  --build-arg VERSION=${VERSION} --build-arg MAXIMUM_THREAD=16 && \
    docker run --rm -i -t ${PROJECT}:${VERSION}
