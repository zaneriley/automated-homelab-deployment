SHELL := /bin/bash
.DEFAULT_GOAL := help

PLAYBOOK := site.yml

.PHONY: help lint syntax check apply smoke rehearse rehearse-workstation rehearse-base rehearse-nuc-bake check-rehearse apply-rehearse rehearse-clean changelog changelog-check release

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

rehearse-workstation: ## Rehearse workstation_tools agent_surface tag in a Tart VM
	@command -v /opt/homebrew/bin/tart >/dev/null || { echo "tart not installed — brew bundle"; exit 1; }
	@/opt/homebrew/bin/tart list 2>/dev/null | awk 'NR>1 {print $$2}' | grep -qx tahoe-clt-base || { echo "tahoe-clt-base image missing — run 'make rehearse-base' (one-time, ~10 min)"; exit 1; }
	scripts/rehearse-workstation.sh

rehearse-base: ## One-time setup: pull vanilla Tart image, bake CLT into tahoe-clt-base
	@command -v /opt/homebrew/bin/tart >/dev/null || { echo "tart not installed — brew bundle"; exit 1; }
	@command -v /opt/homebrew/bin/sshpass >/dev/null || { echo "sshpass not installed — brew bundle"; exit 1; }
	scripts/bake-rehearse-base.sh

rehearse-nuc-bake: ## One-time setup: bake the Ubuntu 22.04 Lima base VM (nuc-rehearse-base)
	@command -v /opt/homebrew/bin/limactl >/dev/null || { echo "limactl not installed — brew install lima"; exit 1; }
	scripts/bake-rehearse-nuc-base.sh

check-rehearse: ## Rehearse PLAY against a fresh Lima VM in --check mode (PLAY=playbooks/x.yml)
	@command -v /opt/homebrew/bin/limactl >/dev/null || { echo "limactl not installed — brew install lima"; exit 1; }
	@/opt/homebrew/bin/limactl list -q 2>/dev/null | grep -qx nuc-rehearse-base || { echo "nuc-rehearse-base missing — run 'make rehearse-nuc-bake'"; exit 1; }
	@if [ -z "$(PLAY)" ]; then echo "Usage: make check-rehearse PLAY=playbooks/x.yml"; exit 1; fi
	scripts/rehearse-nuc.sh "$(PLAY)"

apply-rehearse: ## Apply PLAY against a fresh Lima VM, then prove idempotency via second --check (PLAY=playbooks/x.yml)
	@command -v /opt/homebrew/bin/limactl >/dev/null || { echo "limactl not installed — brew install lima"; exit 1; }
	@/opt/homebrew/bin/limactl list -q 2>/dev/null | grep -qx nuc-rehearse-base || { echo "nuc-rehearse-base missing — run 'make rehearse-nuc-bake'"; exit 1; }
	@if [ -z "$(PLAY)" ]; then echo "Usage: make apply-rehearse PLAY=playbooks/x.yml"; exit 1; fi
	scripts/rehearse-nuc.sh --apply "$(PLAY)"

rehearse-clean: ## Destroy all transient nuc-rehearse-* Lima VMs (leaves nuc-rehearse-base intact)
	@command -v /opt/homebrew/bin/limactl >/dev/null || { echo "limactl not installed — brew install lima"; exit 1; }
	@for vm in $$(/opt/homebrew/bin/limactl list -q 2>/dev/null | grep -E '^nuc-rehearse-' | grep -v '^nuc-rehearse-base$$'); do \
		echo "Destroying $$vm"; \
		/opt/homebrew/bin/limactl stop "$$vm" 2>/dev/null || true; \
		/opt/homebrew/bin/limactl delete --force "$$vm" 2>/dev/null || true; \
	done

changelog: ## Regenerate CHANGELOG.md from git history (deterministic; ADR-0012)
	@command -v git-cliff >/dev/null || { echo "git-cliff not installed — run ./bootstrap.sh or brew install git-cliff"; exit 1; }
	git-cliff -o CHANGELOG.md

changelog-check: ## Verify CHANGELOG.md matches git-cliff output (fails on drift; CI gate)
	@command -v git-cliff >/dev/null || { echo "git-cliff not installed — run ./bootstrap.sh or brew install git-cliff"; exit 1; }
	@git-cliff -o /tmp/CHANGELOG.expected.md
	@diff -q CHANGELOG.md /tmp/CHANGELOG.expected.md >/dev/null || { echo "CHANGELOG.md is stale — run 'make changelog'"; exit 1; }
	@echo "CHANGELOG.md is up-to-date."

release: ## Tag + regenerate CHANGELOG.md. Usage: make release TAG=v0.1.0
	@command -v git-cliff >/dev/null || { echo "git-cliff not installed — run ./bootstrap.sh or brew install git-cliff"; exit 1; }
	@if [ -z "$(TAG)" ]; then echo "Usage: make release TAG=vX.Y.Z"; exit 1; fi
	git tag -a $(TAG) -m "Release $(TAG)"
	git-cliff --tag $(TAG) -o CHANGELOG.md
	@echo ""
	@echo "Tag $(TAG) created locally. CHANGELOG.md regenerated."
	@echo "Next: review 'git diff HEAD -- CHANGELOG.md', commit, then 'git push --follow-tags'."
