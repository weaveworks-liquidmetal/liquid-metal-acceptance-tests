CMD_DIR := cmd
CMD_BIN := bin/e2e
E2E := $(CMD_DIR)/$(CMD_BIN)
E2E_ARGS ?= ""

.PHONY: all
all: pip-deps tf-up e2e tf-down

.PHONY: pip-deps
pip-deps:
	pip3 install -r scripts/requirements.txt

.PHONY: tf-vars
tf-vars:
	./scripts/tf.sh -v

.PHONY: tf-up
tf-up: tf-vars
	./scripts/tf.sh -u

.PHONY: tf-down
tf-down:
	./scripts/tf.sh -d

.PHONY: e2e
e2e: build-e2e
	$(E2E) $(E2E_ARGS)

.PHONY: build-e2e
build-e2e:
	cd $(CMD_DIR); go build -o $(CMD_BIN)
