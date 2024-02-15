BINARY_NAME=s0ck3t
BINARY_VERSION ?= 0.0.0
ARCH := $(shell uname -m)

.PHONY: run build build_all clean ${BINARY_NAME}-linux-x86_64 ${BINARY_NAME}-linux-aarch64 ${BINARY_NAME}-linux-armhf docker

${BINARY_NAME}-linux-amd64:
	GOARCH=amd64 GOOS=linux go build -ldflags="-X 'main.Version=v${BINARY_VERSION}'" -o ${BINARY_NAME}-linux-amd64

${BINARY_NAME}-linux-x86_64: ${BINARY_NAME}-linux-amd64

${BINARY_NAME}-linux-arm64:
	GOARCH=arm64 GOOS=linux go build -ldflags="-X 'main.Version=v${BINARY_VERSION}'" -o ${BINARY_NAME}-linux-arm64

${BINARY_NAME}-linux-aarch64: ${BINARY_NAME}-linux-arm64

${BINARY_NAME}-linux-arm:
	GOARCH=arm GOARM=6 GOOS=linux go build -ldflags="-X 'main.Version=v${BINARY_VERSION}'" -o ${BINARY_NAME}-linux-arm

${BINARY_NAME}-linux-armhf: ${BINARY_NAME}-linux-arm

build: ${BINARY_NAME}-linux-${ARCH}

build_all: ${BINARY_NAME}-linux-amd64 ${BINARY_NAME}-linux-arm64 ${BINARY_NAME}-linux-arm

run: build
	./${BINARY_NAME}.sh

build_and_run: build_all run

docker: build_all
	@cp ${BINARY_NAME}-linux-amd64 .docker/${BINARY_NAME}-${BINARY_VERSION}-linux-amd64
	@cp ${BINARY_NAME}-linux-arm64 .docker/${BINARY_NAME}-${BINARY_VERSION}-linux-arm64
	@cp ${BINARY_NAME}-linux-arm .docker/${BINARY_NAME}-${BINARY_VERSION}-linux-arm
	@docker buildx build --platform linux/amd64 -t ${BINARY_NAME}:${BINARY_VERSION} -o type=docker,dest=${BINARY_NAME}_${BINARY_VERSION}_amd64.tar .docker
	@docker buildx build --platform linux/arm64 -t ${BINARY_NAME}:${BINARY_VERSION} -o type=docker,dest=${BINARY_NAME}_${BINARY_VERSION}_arm64.tar .docker
	@docker buildx build --platform linux/arm/v6 -t ${BINARY_NAME}:${BINARY_VERSION} -o type=docker,dest=${BINARY_NAME}_${BINARY_VERSION}_arm.tar .docker

clean:
	go clean
	rm -f ${BINARY_NAME}-linux-amd64
	rm -f ${BINARY_NAME}-linux-arm64
	rm -f ${BINARY_NAME}-linux-arm
	rm -f .docker/${BINARY_NAME}-*-linux-amd64
	rm -f .docker/${BINARY_NAME}-*-linux-arm64
	rm -f .docker/${BINARY_NAME}-*-linux-arm
	rm -f ${BINARY_NAME}_*.tar
