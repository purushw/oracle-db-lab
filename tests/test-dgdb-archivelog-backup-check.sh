#!/usr/bin/env bash
# Non-destructive wrapper regression tests; Docker and SQL*Plus are mocked.
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/scripts/oracle/shell/dgdb-archivelog-backup-check.sh"
mockbin=$(mktemp -d)
trap 'rm -rf "$mockbin"' EXIT
cat > "$mockbin/docker" <<'SH'
#!/bin/sh
if [ "$3" = nonexistent-dgdb-test ]; then
  echo 'Error response from daemon: No such container' >&2
  exit 1
fi
case "$DGDB_MOCK_MODE" in
  critical) echo 'CRITICAL: 1 archived redo sequence lacks RMAN backup evidence'; echo 'DGDB_ARCHIVELOG_RESULT=2'; exit 2 ;;
  ok) echo 'OK: no archived redo sequence exceeds the backup window'; echo 'DGDB_ARCHIVELOG_RESULT=0'; exit 0 ;;
  sqlfail) echo 'ORA-00942: simulated SQL failure' >&2; exit 3 ;;
esac
exit 3
SH
chmod +x "$mockbin/docker"

check() {
  local label=$1 expected=$2 phrase=$3 actual output
  output=$(PATH="$mockbin:$PATH" "$script" 2>&1) && actual=0 || actual=$?
  if [[ $actual != "$expected" || $output != *"$phrase"* ]]; then
    printf 'FAIL %s: exit=%s output=%s\n' "$label" "$actual" "$output" >&2
    exit 1
  fi
  printf 'PASS %s: exit=%s\n' "$label" "$actual"
}
export DGDB_MOCK_MODE=critical
check 'policy breach detected' 2 'CRITICAL:'
export DGDB_MOCK_MODE=ok
check 'healthy assessment' 0 'OK:'
DGDB_CONTAINER_NAME=nonexistent-dgdb-test check 'nonexistent container' 3 'UNKNOWN:'
export DGDB_MOCK_MODE=sqlfail
check 'SQL execution failure' 3 'UNKNOWN:'
