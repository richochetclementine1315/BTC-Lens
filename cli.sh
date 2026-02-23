#!/usr/bin/env bash
set -euo pipefail

# Always rebuild — Go caches unchanged packages so this is fast.
# Checking only cmd/cli/main.go would miss changes in pkg/ subdirectories.
go build -o chain-lens-cli ./cmd/cli/

# Run CLI with all arguments
./chain-lens-cli "$@"