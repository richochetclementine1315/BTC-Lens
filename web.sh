#!/usr/bin/env bash
set -euo pipefail

# Always rebuild — Go caches unchanged packages so this is fast.
# Checking only cmd/web/main.go would miss changes in pkg/ subdirectories.
go build -o chain-lens-web ./cmd/web/

# Run web server
exec ./chain-lens-web