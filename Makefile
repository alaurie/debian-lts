.DEFAULT_GOAL := help

ROOT_DIR := $(shell pwd)
SRC_DIR  := $(ROOT_DIR)/src/linux-6.18

.PHONY: help
help:
	@echo "Debian 6.18 LTS Kernel Build System"
	@echo "====================================="
	@echo "make check        - Check kernel.org for new 6.18 LTS point releases"
	@echo "make setup        - Verify and install Debian build dependencies"
	@echo "make fetch        - Fetch or update upstream linux-6.18.y git branch"
	@echo "make config       - Apply Debian baseline configuration (.config)"
	@echo "make menuconfig   - Open interactive menuconfig on current .config"
	@echo "make build        - Compile kernel on host (.deb packages)"
	@echo "make container-build - Compile kernel inside clean Podman container"
	@echo "make container-shell - Open interactive shell in Podman build container"
	@echo "make clean        - Clean build artifacts inside kernel tree"
	@echo "make distclean    - Remove build artifacts, packages, and kernel tree"

.PHONY: setup
setup:
	@./scripts/setup-env.sh

.PHONY: check
check:
	@./scripts/check-upstream.sh --summary || true

.PHONY: fetch
fetch:
	@./scripts/fetch-kernel.sh

.PHONY: config
config:
	@./scripts/prepare-config.sh

.PHONY: menuconfig
menuconfig:
	@if [ ! -d "$(SRC_DIR)" ]; then echo "Error: Run 'make fetch' first."; exit 1; fi
	@make -C $(SRC_DIR) menuconfig

.PHONY: build
build:
	@./scripts/build.sh

.PHONY: container-image
container-image:
	@podman build -t debian-lts-builder:latest -f $(ROOT_DIR)/Containerfile $(ROOT_DIR)

.PHONY: container-build
container-build:
	@./scripts/podman-build.sh

.PHONY: container-shell
container-shell:
	@./scripts/podman-build.sh bash

.PHONY: clean
clean:
	@if [ -d "$(SRC_DIR)" ]; then make -C $(SRC_DIR) clean; fi
	@rm -rf $(ROOT_DIR)/dist

.PHONY: distclean
distclean: clean
	@rm -rf $(ROOT_DIR)/src
