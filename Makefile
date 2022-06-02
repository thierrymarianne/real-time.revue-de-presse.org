SHELL:=/bin/bash

.PHONY: help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build-worker: ## Build worker docker image
	@/bin/bash -c 'source ./bin/console.sh && build_worker_container'

download-golang: ## Download golang binary
	@/bin/bash -c 'source ./bin/console.sh && download_golang '"${TARGET_DIR}"

migrate-publications: ## Migrate publications
	@/bin/bash -c "source ./bin/console.sh && run_worker_container ${PUBLISHERS_LIST_ID} ${SINCE_DATE}"
