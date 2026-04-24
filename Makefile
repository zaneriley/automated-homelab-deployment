SHELL := /bin/bash
.DEFAULT_GOAL := help

PLAYBOOK := site.yml

.PHONY: help lint syntax check apply smoke

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

lint: ## ansible-lint + yamllint
	@command -v ansible-lint >/dev/null || { echo "ansible-lint not installed — run ./bootstrap.sh"; exit 1; }
	@command -v yamllint >/dev/null || { echo "yamllint not installed — run ./bootstrap.sh"; exit 1; }
	ansible-lint
	yamllint .

syntax: ## ansible-playbook --syntax-check
	ansible-playbook $(PLAYBOOK) --syntax-check

check: syntax ## Dry run (--check --diff); the second run of this target IS the verify (ADR-0009)
	ansible-playbook $(PLAYBOOK) --check --diff

apply: ## Apply the playbook. Review `make check` output first.
	ansible-playbook $(PLAYBOOK)

smoke: ## Optional runtime-fact smoke test (Tailscale up, Ollama listening, etc.)
	@if [ -f smoke.yml ]; then ansible-playbook smoke.yml; else echo "smoke.yml not present (optional)"; fi
