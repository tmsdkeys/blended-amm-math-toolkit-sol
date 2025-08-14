# Mathematical AMM Toolkit - Makefile
# Convenience commands using gblend/forge

include .env
export

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo "Mathematical AMM Toolkit - Available Commands"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

.PHONY: setup
setup: ## Initialize and update submodules
	@echo "$(BLUE)Setting up submodules...$(NC)"
	git submodule update --init --recursive

.PHONY: test
test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	forge test -vv

.PHONY: test-gas
test-gas: ## Run gas benchmark tests
	@echo "$(BLUE)Running gas benchmarks...$(NC)"
	forge test --match-contract GasBenchmark --gas-report -vvv

.PHONY: snapshot
snapshot: ## Create gas snapshot
	@echo "$(BLUE)Creating gas snapshot...$(NC)"
	forge snapshot --match-contract GasBenchmark
	@echo "$(GREEN)✓ Snapshot saved to .gas-snapshot$(NC)"

.PHONY: anvil
anvil: ## Start local Anvil testnet
	@echo "$(BLUE)Starting Anvil...$(NC)"
	anvil --host 0.0.0.0 --port 8545

.PHONY: benchmark
benchmark: deploy test-gas snapshot ## Run complete benchmark suite
	@echo "$(GREEN)✓ Benchmark complete!$(NC)"
	@echo "Check the gas report above for detailed analysis"

.PHONY: console
console: ## Open Forge console
	forge console

# Convenience aliases
.PHONY: b
b: build

.PHONY: d
d: deploy

.PHONY: t
t: test