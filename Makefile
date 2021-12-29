DOCKER_REGISTRY ?= hub.docker.com
#IMAGE_NAME := $(shell basename `pwd` )
IMAGE_NAME ?= docker-isc-kea
IMAGE_VERSION = latest
BUILD_NUMBER ?= unstable
DHCP4_IMAGE_NAME = $(IMAGE_NAME)-dhcp4
DHCP4_IMAGE_TAG_BUILD = $(DHCP4_IMAGE_NAME):$(BUILD_NUMBER)
DHCP4_IMAGE_TAG_VER = $(DHCP4_IMAGE_NAME):$(IMAGE_VERSION)
DHCP4_IMAGE_TAG_REMOTE = $(DOCKER_REGISTRY)/$(DHCP4_IMAGE_TAG_VER)
DHCP6_IMAGE_NAME = $(IMAGE_NAME)-dhcp6
DHCP6_IMAGE_TAG_BUILD = $(DHCP6_IMAGE_NAME):$(BUILD_NUMBER)
DHCP6_IMAGE_TAG_VER = $(DHCP6_IMAGE_NAME):$(IMAGE_VERSION)
DHCP6_IMAGE_TAG_REMOTE = $(DOCKER_REGISTRY)/$(DHCP6_IMAGE_TAG_VER)

FULL_IMAGE_NAME = $(IMAGE_NAME)-full
FULL_IMAGE_TAG_BUILD = $(FULL_IMAGE_NAME):$(BUILD_NUMBER)
FULL_IMAGE_TAG_VER = $(FULL_IMAGE_NAME):$(IMAGE_VERSION)
FULL_IMAGE_TAG_REMOTE = $(DOCKER_REGISTRY)/$(FULL_IMAGE_TAG_VER)


WORKING_DIR := $(shell pwd)

.DEFAULT_GOAL := help

# List of targets that are commands, not files
.PHONY: release push build

release:: build push ## Builds and pushes the docker image to the registry

push:: ## Pushes the docker image to the registry
	@docker push $(FULL_IMAGE_TAG)


isc-stork.gpg:
	curl -1sLf "https://dl.cloudsmith.io/public/isc/stork/gpg.77F64EC28053D1FB.key" | gpg --dearmor > isc-stork.gpg

## Builds the docker image locally
build-dhcp4: isc-stork.gpg
	@docker build -f Dockerfile --target isc-kea-dhcp4-server -t $(DHCP4_IMAGE_TAG_BUILD) $(WORKING_DIR)
	@docker tag $(DHCP4_IMAGE_TAG_BUILD) $(DHCP4_IMAGE_TAG_VER)
	@docker tag $(DHCP4_IMAGE_TAG_BUILD) $(DHCP4_IMAGE_TAG_REMOTE)

build-dhcp6: isc-stork.gpg
	@docker build -f Dockerfile --target isc-kea-dhcp6-server -t $(DHCP6_IMAGE_TAG_BUILD) $(WORKING_DIR)
	@docker tag $(DHCP6_IMAGE_TAG_BUILD) $(DHCP6_IMAGE_TAG_VER)
	@docker tag $(DHCP6_IMAGE_TAG_BUILD) $(DHCP6_IMAGE_TAG_REMOTE)

build-full: isc-stork.gpg
	@docker build -f Dockerfile --target isc-kea-full -t $(FULL_IMAGE_TAG_BUILD) $(WORKING_DIR)
	@docker tag $(FULL_IMAGE_TAG_BUILD) $(FULL_IMAGE_TAG_VER)
	@docker tag $(FULL_IMAGE_TAG_BUILD) $(FULL_IMAGE_TAG_REMOTE)

build: build-full

image: release
		@docker image save $(IMAGE_TAG_VER) | xz --threads=2 -z > $(WORKING_DIR)/$(IMAGE_NAME)_$(BUILD_NUMBER).tar.xz

# A help target including self-documenting targets (see the awk statement)
define HELP_TEXT
Usage: make [TARGET]... [MAKEVAR1=SOMETHING]...

Available targets:
endef
export HELP_TEXT
help: ## This help target
	@echo "$$HELP_TEXT"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
		{printf "\033[36m%-30s\033[0m  %s\n", $$1, $$2}' $(MAKEFILE_LIST)
