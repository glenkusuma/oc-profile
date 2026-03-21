#!/usr/bin/env bash
# Run BATS tests for oc-profile
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BATS="${SCRIPT_DIR}/bats/bin/bats"

# Check if BATS is installed
if [[ ! -x "$BATS" ]]; then
  echo "Error: BATS not found at $BATS"
  echo "Run: git submodule update --init --recursive"
  exit 1
fi

# Run all tests
echo "Running oc-profile BATS test suite..."
echo ""

"$BATS" "${SCRIPT_DIR}/"*.bats "$@"
