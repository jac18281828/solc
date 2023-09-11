# SOLC Docker image

SOLC: 0.8.21

### Building

Build requires BuildKit TARGETARCH

`$ DOCKER_BUILDKIT=1 docker build . -t ... `

### Architecture
* linux/amd64 
* linux/arm64


## Example Dockerfile

```
FROM ghcr.io/jac18281828/solc:latest

```


