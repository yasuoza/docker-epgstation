REPOSITORY:="yasuoza/epgstation"

all:
	@make build
	@make push

build:
	docker build --build-arg CPUCORE=4 -f Dockerfile -t ${REPOSITORY} .

clean_build:
	docker build --no-cache --build-arg CPUCORE=4 -f Dockerfile -t ${REPOSITORY} .

push:
	docker push ${REPOSITORY}
