SHELL:=/bin/bash

.PHONY: help build download-golang start

PUBLISHERS_LIST_ID ?= '1'
# [The shell Function](https://ftp.gnu.org/old-gnu/Manuals/make-3.79.1/html_chapter/make_8.html#SEC83)
SINCE_DATE ?= $(shell date -I)
uid ?= ''
gid ?= ''

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build worker docker image
	@/bin/bash -c 'source ./bin/console.sh && build'

download-golang: ## Download golang binary
	@/bin/bash -c 'source ./bin/console.sh && download_golang '"${TARGET_DIR}"

start: build ## Migrate publications
	@/bin/bash -c 'source ./bin/console.sh && run_worker_container "${PUBLISHERS_LIST_ID}" "${SINCE_DATE}"'
