SHELL:=/bin/bash

.PHONY: doc build clean help install restart start stop test

WORKER ?= 'trends.revue-de-presse.org'
TMP_DIR ?= '/tmp/tmp_${WORKER}'

doc:
	@cat doc/commands.md && echo ''

help: doc
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build worker image
	@/bin/bash -c 'source fun.sh && build'

clean: ## Remove worker container
	@/bin/bash -c 'source fun.sh && clean "${TMP_DIR}"'

install: build ## Install requirements
	@/bin/bash -c 'source fun.sh && install'

start: ## Run worker e.g. COMMAND=''
	@/bin/bash -c 'source fun.sh && start'