REPOSITORY:="yasuoza/epgstation"
PLATFORM?=linux/amd64
CPUCORE?=4

all:
	@make build
	@make push

build:
	docker build --platform ${PLATFORM} --build-arg CPUCORE=${CPUCORE} -f Dockerfile -t ${REPOSITORY} .

clean_build:
	docker build --no-cache --platform ${PLATFORM} --build-arg CPUCORE=${CPUCORE} -f Dockerfile -t ${REPOSITORY} .

push:
	docker push ${REPOSITORY}
