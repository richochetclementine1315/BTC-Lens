#!/usr/bin/env bash
set -euo pipefail

echo "Installing Go dependencies..."
go mod download
go mod tidy

echo "Decompressing block fixtures..."
for gz in fixtures/blocks/*.dat.gz; do
  dat="${gz%.gz}"
  if [[ ! -f "$dat" ]]; then
    echo "Decompressing $(basename "$gz")..."
    gunzip -k "$gz"
  fi
done

echo "Setup complete!"