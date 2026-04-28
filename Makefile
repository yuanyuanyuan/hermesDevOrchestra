.PHONY: test test-unit test-risk lint-json lint-shell upstream-status

TEST_RUNNER := docs/orchestra/scripts/tests/run-all.sh
RISK_TESTS := docs/orchestra/scripts/tests/test-risk-check.sh docs/orchestra/scripts/tests/test-risk-decisions.sh docs/orchestra/scripts/tests/test-decision-cli.sh
PIN_MANIFEST := .planning/upstream/hermes-agent-pin.json
HERMES_AGENT_DIR ?= $(HOME)/.hermes/hermes-agent

test: test-unit test-risk lint-json lint-shell upstream-status

test-unit:
	@bash $(TEST_RUNNER)

test-risk:
	@set -e; \
	for script in $(RISK_TESTS); do \
		bash "$$script"; \
	done

lint-json:
	@find . -path './.git' -prune -o -name '*.json' -type f -print0 | xargs -0 -r -n1 python3 -m json.tool >/dev/null

lint-shell:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck docs/orchestra/scripts/setup.sh docs/orchestra/scripts/lib/*.sh docs/orchestra/scripts/bin/orch-* docs/orchestra/scripts/tests/*.sh docs/orchestra/scripts/tests/lib/*.sh; \
	else \
		echo "shellcheck not found; skipping shell lint"; \
	fi

upstream-status:
	@repo_pin="$$(python3 -c 'import json; print(json.load(open("$(PIN_MANIFEST)", encoding="utf-8"))["pin"]["commit"])')"; \
	runtime_dir="$(HERMES_AGENT_DIR)"; \
	echo "repo pin: $$repo_pin"; \
	echo "runtime path: $$runtime_dir"; \
	if [ -e "$$runtime_dir/.git" ]; then \
		runtime_pin="$$(git -C "$$runtime_dir" rev-parse HEAD)"; \
		echo "runtime pin: $$runtime_pin"; \
		if [ "$$repo_pin" = "$$runtime_pin" ]; then \
			echo "status: match"; \
		else \
			echo "status: mismatch"; \
			exit 1; \
		fi; \
	else \
		echo "runtime pin: missing"; \
		echo "status: runtime checkout not found; repo pin only"; \
	fi
