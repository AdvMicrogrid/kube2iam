ORG_PATH="github.com/jtblin"
BINARY_NAME := kube2iam
REPO_PATH="$(ORG_PATH)/$(BINARY_NAME)"
VERSION_VAR := $(REPO_PATH)/version.Version
GIT_VAR := $(REPO_PATH)/version.GitCommit
BUILD_DATE_VAR := $(REPO_PATH)/version.BuildDate
REPO_VERSION := $$(git describe --tags)
BUILD_DATE := $$(date +%Y-%m-%d-%H:%M)
GIT_HASH := $$(git rev-parse --short HEAD)
GOBUILD_VERSION_ARGS := -ldflags "-s -X $(VERSION_VAR)=$(REPO_VERSION) -X $(GIT_VAR)=$(GIT_HASH) -X $(BUILD_DATE_VAR)=$(BUILD_DATE)"
# useful for other docker repos
DOCKER_REPO ?= 876270261134.dkr.ecr.us-west-2.amazonaws.com
IMAGE_NAME := $(DOCKER_REPO)/$(BINARY_NAME)
ARCH ?= darwin
METALINTER_CONCURRENCY ?= 4
METALINTER_DEADLINE ?= 180
# useful for passing --build-arg http_proxy :)
DOCKER_BUILD_FLAGS :=

setup:
	go get -v -u github.com/Masterminds/glide
	go get -v -u github.com/githubnemo/CompileDaemon
	go get -v -u github.com/alecthomas/gometalinter
	go get -v -u github.com/jstemmer/go-junit-report
	go get -v github.com/mattn/goveralls
	gometalinter --install --update
	glide install --strip-vendor

.PHONY: build
build: *.go fmt
	go build -o build/bin/$(ARCH)/$(BINARY_NAME) $(GOBUILD_VERSION_ARGS) github.com/jtblin/$(BINARY_NAME)/cmd

.PHONY: build-race
build-race: *.go fmt
	go build -race -o build/bin/$(ARCH)/$(BINARY_NAME) $(GOBUILD_VERSION_ARGS) github.com/jtblin/$(BINARY_NAME)/cmd

.PHONY: build-all
build-all:
	go build $$(glide nv)

.PHONY: fmt
fmt:
	gofmt -w=true -s $$(find . -type f -name '*.go' -not -path "./vendor/*")
	goimports -w=true -d $$(find . -type f -name '*.go' -not -path "./vendor/*")

.PHONY: test
test:
	go test $$(glide nv)

.PHONY: test-race
test-race:
	go test -race $$(glide nv)

.PHONY: bench
bench:
	go test -bench=. $$(glide nv)

.PHONY: bench-race
bench-race:
	go test -race -bench=. $$(glide nv)

.PHONY: cover
cover:
	./cover.sh
	go tool cover -func=coverage.out
	go tool cover -html=coverage.out

.PHONY: coveralls
coveralls:
	./cover.sh
	goveralls -coverprofile=coverage.out -service=travis-ci

.PHONY: junit-test
junit-test: build
	go test -v $$(glide nv) | go-junit-report > test-report.xml

.PHONY: check
check:
	go install ./cmd

	gometalinter --concurrency=$(METALINTER_CONCURRENCY) --deadline=$(METALINTER_DEADLINE)s ./... --vendor --linter='errcheck:errcheck:-ignore=net:Close' --cyclo-over=20 \
		--linter='vet:go vet --no-recurse -composites=false:PATH:LINE:MESSAGE' --disable=interfacer --dupl-threshold=50

.PHONY: check-all
check-all:
	go install ./cmd
	gometalinter --concurrency=$(METALINTER_CONCURRENCY) --deadline=600s ./... --vendor --cyclo-over=20 \
		--linter='vet:govet --no-recurse:PATH:LINE:MESSAGE' --dupl-threshold=50
		--dupl-threshold=50

travis-checks: build test-race check bench-race

.PHONY: watch
watch:
	CompileDaemon -color=true -build "make test"

.PHONY: cross
cross:
	CGO_ENABLED=0 GOOS=linux go build -o build/bin/linux/$(BINARY_NAME) $(GOBUILD_VERSION_ARGS) -a -installsuffix cgo  github.com/jtblin/$(BINARY_NAME)/cmd

.PHONY: docker
docker:
	docker build -t $(IMAGE_NAME):$(GIT_HASH) . $(DOCKER_BUILD_FLAGS)

.PHONY: docker-dev
docker-dev: docker
	docker tag $(IMAGE_NAME):$(GIT_HASH) $(IMAGE_NAME):dev
	docker push $(IMAGE_NAME):dev

.PHONY: release
release:
	docker push $(IMAGE_NAME):$(GIT_HASH)
	docker tag $(IMAGE_NAME):$(GIT_HASH) $(IMAGE_NAME):$(REPO_VERSION)
	docker push $(IMAGE_NAME):$(REPO_VERSION)

.PHONY: version
version:
	@echo $(REPO_VERSION)

.PHONY: clean
clean:
	rm -rf build/bin/*
	-docker rm $(docker ps -a -f 'status=exited' -q)
	-docker rmi $(docker images -f 'dangling=true' -q)
