SHELL:=/bin/bash

## See also https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

.PHONY: help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build-worker: ## Build worker docker image
	@/bin/bash -c 'source ./bin/console.sh && build_worker_container'

create-network: ## Create Docker network
	@/bin/bash -c 'source ./bin/console.sh && create_network'

run-worker: ## Run a worker container
	@/bin/bash -c 'source ./bin/console.sh && run_worker_container ${AGGREGATE_ID} ${SINCE_DATE}'

download-golang: ## Download golang binary
	@/bin/bash -c 'source ./bin/console.sh && download_golang '"${TARGET_DIR}"

build-application: ## Build application
	@/bin/bash -c 'source ./bin/console.sh && build_application'

install-application: ## Install application
	@/bin/bash -c 'source ./bin/console.sh && install_application'

build: ## Build application
	@/bin/bash -c 'source ./bin/console.sh && build_application'

install: ## Install application
	@/bin/bash -c 'source ./bin/console.sh && install_application'

migrate-publications: ## Migrate publications
	@/bin/bash -c 'source ./bin/console.sh && migrate_publications'
