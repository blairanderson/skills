#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "== unit =="; bash "$DIR/unit.sh"
echo "== e2e =="; bash "$DIR/e2e.sh"
echo "== all suites green =="
