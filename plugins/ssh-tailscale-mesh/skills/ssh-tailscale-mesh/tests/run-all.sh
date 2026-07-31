#!/usr/bin/env bash
# Run the full suite: unit + integration + e2e + resolver-trigger.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in unit integration e2e resolver-trigger; do
  echo "############ $t ############"
  bash "$HERE/$t.sh" || rc=1
  echo
done
[ "$rc" -eq 0 ] && echo "ALL SUITES GREEN" || echo "SOME SUITES FAILED"
exit "$rc"
