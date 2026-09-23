#!/usr/bin/env bash
# Runs every model-policy test file. Run: bash plugins/model-policy/tests/run.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
status=0
for t in "$HERE"/*.test.sh; do
  echo "== $(basename "$t")"
  bash "$t" || status=1
done
if [ $status -eq 0 ]; then echo "ALL PASSED"; else echo "SOME FAILED"; exit 1; fi
