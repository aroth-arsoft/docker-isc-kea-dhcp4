DOCKER_REGISTRY ?= hub.docker.com
IMAGE_NAME := $(shell basename `pwd` )
IMAGE_VERSION = latest
BUILD_NUMBER ?= unstable
IMAGE_TAG_VER = $(IMAGE_NAME):$(BUILD_NUMBER)
IMAGE_TAG = $(IMAGE_NAME):$(IMAGE_VERSION)
FULL_IMAGE_TAG = $(DOCKER_REGISTRY)/$(IMAGE_TAG)

WORKING_DIR := $(shell pwd)

.DEFAULT_GOAL := help

# List of targets that are commands, not files
.PHONY: release push build

release:: build push ## Builds and pushes the docker image to the registry

push:: ## Pushes the docker image to the registry
		@docker push $(FULL_IMAGE_TAG)

build:: ## Builds the docker image locally
	#curl -1sLf "https://dl.cloudsmith.io/public/isc/kea-2-0/gpg.8029D4AFA58CBB5E.key" | gpg --dearmor > isc-kea.gpg
	curl -1sLf "https://dl.cloudsmith.io/public/isc/stork/gpg.77F64EC28053D1FB.key" | gpg --dearmor > isc-stork.gpg
	@docker build -f Dockerfile -t $(IMAGE_TAG_VER) $(WORKING_DIR)
	@docker tag $(IMAGE_TAG_VER) $(IMAGE_TAG)
	@docker tag $(IMAGE_TAG_VER) $(FULL_IMAGE_TAG)

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
