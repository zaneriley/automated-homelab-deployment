SHELL := /bin/bash
.DEFAULT_GOAL := help

PLAYBOOK := site.yml

.PHONY: help lint syntax check apply smoke rehearse rehearse-base

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

rehearse: ## Rehearse a destructive layer in a Tart VM (LAYER=layer2|layer3, default layer2)
	@command -v /opt/homebrew/bin/tart >/dev/null || { echo "tart not installed — brew bundle"; exit 1; }
	@/opt/homebrew/bin/tart list 2>/dev/null | awk 'NR>1 {print $$2}' | grep -qx tahoe-clt-base || { echo "tahoe-clt-base image missing — run 'make rehearse-base' (one-time, ~10 min)"; exit 1; }
	scripts/rehearse-tart.sh $(or $(LAYER),layer2)

rehearse-base: ## One-time setup: pull vanilla Tart image, bake CLT into tahoe-clt-base
	@command -v /opt/homebrew/bin/tart >/dev/null || { echo "tart not installed — brew bundle"; exit 1; }
	@command -v /opt/homebrew/bin/sshpass >/dev/null || { echo "sshpass not installed — brew bundle"; exit 1; }
	scripts/bake-rehearse-base.sh
