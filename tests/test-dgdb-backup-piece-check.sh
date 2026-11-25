#!/usr/bin/env bash
# Non-destructive fixture checks; no Docker or database connection.
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/scripts/oracle/shell/dgdb-backup-piece-check.sh"
fixture=$(mktemp)
trap 'rm -f "$fixture"' EXIT

check() {
  local label=$1 expected_exit=$2 expected_text=$3 result output
  output=$($script --set-fixture "$fixture") && result=0 || result=$?
  if [[ $result != "$expected_exit" || $output != *"$expected_text"* ]]; then
    printf 'FAIL %s: exit=%s output=%s\n' "$label" "$result" "$output" >&2
    exit 1
  fi
  printf 'PASS %s: exit=%s\n' "$label" "$result"
}

printf '101 7 2 1 1 A\n101 7 2 2 1 A\n' > "$fixture"
check 'complete two-piece set' 0 'OK:'

printf '101 7 2 1 1 A\n' > "$fixture"
check 'missing piece 2' 3 'missing_piece_numbers=1'

printf '101 7 2 1 1 A\n101 7 2 3 1 A\n' > "$fixture"
check 'piece 1 and out-of-range piece 3' 3 'out_of_range_pieces=1'

printf '101 7 2 1 1 X\n101 7 2 1 2 A\n101 7 2 2 1 A\n' > "$fixture"
check 'expired copy with available alternative' 1 'WARNING:'

: > "$fixture"
check 'empty fixture' 3 'UNKNOWN:'

# Simulate SQL*Plus failing through Docker with the same ambiguous exit code 1
# as a legitimate WARNING. No database connection is made.
mockbin=$(mktemp -d)
trap 'rm -f "$fixture"; rm -rf "$mockbin"' EXIT
printf '#!/bin/sh\nprintf "ORA-00942: simulated SQL error\\n"\nexit 1\n' > "$mockbin/docker"
chmod +x "$mockbin/docker"
output=$(PATH="$mockbin:$PATH" "$script" 2>&1) && result=0 || result=$?
if [[ $result != 3 || $output != *'UNKNOWN:'* ]]; then
  printf 'FAIL SQL execution failure: exit=%s output=%s\n' "$result" "$output" >&2
  exit 1
fi
printf 'PASS SQL execution failure: exit=3\n'
