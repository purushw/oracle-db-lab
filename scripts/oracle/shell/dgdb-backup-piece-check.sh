#!/usr/bin/env bash
# Read-only RMAN backup-piece inventory check for the DGDB lab.
# Exit: 0 OK, 1 WARNING, 2 reserved for verified recovery risk, 3 UNKNOWN/ERROR.
set -euo pipefail

# A fixture is one V$BACKUP_PIECE status per line. It exercises the summary and
# WARNING exit without changing database or RMAN metadata.
if [[ ${1:-} == --set-fixture && $# == 2 ]]; then
  fixture_file=$2
  if [[ ! -r $fixture_file ]]; then printf 'UNKNOWN: unreadable fixture\n' >&2; exit 3; fi
  awk '
    NF == 0 { next }
    NF != 6 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ ||
      $3 !~ /^[1-9][0-9]*$/ || $4 !~ /^[1-9][0-9]*$/ ||
      $5 !~ /^[1-9][0-9]*$/ {
        print "UNKNOWN: invalid fixture row"; exit 3
      }
    {
      key = $1 ":" $2
      if (key in expected && expected[key] != $3) {
        print "UNKNOWN: conflicting expected piece counts"; exit 3
      }
      expected[key] = $3
      seen[key ":" $4] = 1
      total++
      if ($6 == "A") available++
      else if ($6 == "X") expired++
      else if ($6 == "D") deleted++
      else if ($6 == "U") unavailable++
      else unexpected++
    }
    END {
      if (total == 0) { print "UNKNOWN: empty inventory"; exit 3 }
      for (key in expected) {
        for (piece = 1; piece <= expected[key]; piece++)
          if (!((key ":" piece) in seen)) missing++
      }
      for (entry in seen) {
        split(entry, parts, ":")
        key = parts[1] ":" parts[2]
        if (parts[3] > expected[key]) extra++
      }
      printf "Fixture summary: total=%d available=%d expired=%d deleted=%d unavailable=%d unexpected=%d missing_piece_numbers=%d out_of_range_pieces=%d\n", total, available, expired, deleted, unavailable, unexpected, missing, extra
      if (missing || extra) { print "UNKNOWN: incomplete backup-set metadata"; exit 3 }
      if (available == total) { print "OK: all recorded pieces available"; exit 0 }
      printf "WARNING: %d recorded piece(s) require investigation\n", total-available
      exit 1
    }
  ' "$fixture_file"
  exit $?
elif [[ ${1:-} == --fixture && $# == 2 ]]; then
  fixture_file=$2
  if [[ ! -r $fixture_file ]]; then
    printf 'UNKNOWN: fixture cannot be read: %s\n' "$fixture_file" >&2
    exit 3
  fi
  total=0 available=0 expired=0 deleted=0 unavailable=0 unexpected=0
  while IFS= read -r status || [[ -n $status ]]; do
    [[ -z $status ]] && continue
    ((total+=1))
    case $status in
      A) ((available+=1)) ;;
      X) ((expired+=1)) ;;
      D) ((deleted+=1)) ;;
      U) ((unavailable+=1)) ;;
      *) ((unexpected+=1)) ;;
    esac
  done < "$fixture_file"
  printf 'Fixture summary: total=%d available=%d expired=%d deleted=%d unavailable=%d unexpected=%d\n' \
    "$total" "$available" "$expired" "$deleted" "$unavailable" "$unexpected"
  if (( total == 0 )); then printf 'UNKNOWN: empty inventory\n'; exit 3; fi
  if (( available == total )); then printf 'OK: all recorded pieces available\n'; exit 0; fi
  printf 'WARNING: %d recorded piece(s) require investigation\n' "$((total-available))"
  exit 1
elif (( $# != 0 )); then
  printf 'Usage: %s [--fixture status-file | --set-fixture set-file]\n' "$0" >&2
  exit 3
fi

container_name="${DGDB_CONTAINER_NAME:-oracle-db}"
if ! command -v docker >/dev/null 2>&1; then
  printf 'UNKNOWN: docker was not found in PATH\n' >&2
  exit 3
fi

report_file=$(mktemp) || { printf 'UNKNOWN: cannot create report file\n' >&2; exit 3; }
trap 'rm -f "$report_file"' EXIT
if docker exec -i "$container_name" sqlplus -s '/ as sysdba' >"$report_file" 2>&1 <<'SQL'; then
WHENEVER SQLERROR EXIT 3 ROLLBACK
WHENEVER OSERROR EXIT 3 ROLLBACK
SET PAGESIZE 200
SET LINESIZE 240
SET TRIMSPOOL ON
SET TAB OFF
SET SERVEROUTPUT ON
COLUMN completed_at FORMAT A19
COLUMN handle FORMAT A100
COLUMN piece_status FORMAT A12

PROMPT RMAN backup-piece inventory (one row per piece and copy)
SELECT b.recid AS backup_set_key,
       TO_CHAR(b.completion_time, 'YYYY-MM-DD HH24:MI:SS') AS completed_at,
       p.set_stamp,
       p.set_count,
       p.piece# AS piece_number,
       p.copy# AS copy_number,
       p.status AS piece_status,
       p.handle
FROM v$backup_piece p
LEFT JOIN v$backup_set b
  ON b.set_stamp = p.set_stamp
 AND b.set_count = p.set_count
ORDER BY p.set_stamp, p.set_count, p.piece#, p.copy#, p.recid;

-- A missing set row means the inventory cannot be assessed reliably. An
-- available piece is a metadata state, not a physical readability check.
VARIABLE monitor_exit NUMBER
DECLARE
    l_total NUMBER;
    l_available NUMBER;
    l_expired NUMBER;
    l_deleted NUMBER;
    l_unavailable NUMBER;
    l_unexpected NUMBER;
    l_missing_sets NUMBER;
    l_incomplete_sets NUMBER;
BEGIN
    SELECT COUNT(*),
           COUNT(CASE WHEN status = 'A' THEN 1 END),
           COUNT(CASE WHEN status = 'X' THEN 1 END),
           COUNT(CASE WHEN status = 'D' THEN 1 END),
           COUNT(CASE WHEN status = 'U' THEN 1 END),
           COUNT(CASE WHEN status IS NULL OR status NOT IN ('A','X','D','U') THEN 1 END)
      INTO l_total, l_available, l_expired, l_deleted, l_unavailable, l_unexpected
      FROM v$backup_piece;

    SELECT COUNT(*) INTO l_missing_sets
      FROM v$backup_piece p
     WHERE NOT EXISTS (
         SELECT 1 FROM v$backup_set b
          WHERE b.set_stamp = p.set_stamp AND b.set_count = p.set_count
     );

    -- For positive PIECES=N, N distinct numbers with MIN=1 and MAX=N are
    -- exactly 1..N. Multiple copies do not replace a missing number; a
    -- numbered piece outside 1..N also makes the inventory incomplete.
    SELECT COUNT(*) INTO l_incomplete_sets FROM (
        SELECT b.set_stamp, b.set_count
        FROM v$backup_set b
        LEFT JOIN v$backup_piece p
          ON p.set_stamp = b.set_stamp AND p.set_count = b.set_count
        GROUP BY b.set_stamp, b.set_count, b.pieces
        HAVING b.pieces IS NULL OR b.pieces < 1
            OR COUNT(DISTINCT p.piece#) <> b.pieces
            OR MIN(p.piece#) <> 1 OR MAX(p.piece#) <> b.pieces
    );

    DBMS_OUTPUT.PUT_LINE('SUMMARY total=' || l_total ||
        ' available=' || l_available || ' expired=' || l_expired ||
        ' deleted=' || l_deleted || ' unavailable=' || l_unavailable ||
        ' unexpected=' || l_unexpected || ' missing_sets=' || l_missing_sets ||
        ' incomplete_sets=' || l_incomplete_sets);

    IF l_total = 0 OR l_missing_sets > 0 OR l_incomplete_sets > 0 THEN
        :monitor_exit := 3;
        DBMS_OUTPUT.PUT_LINE('UNKNOWN: empty inventory or incomplete backup-set metadata');
    ELSIF l_available = l_total THEN
        :monitor_exit := 0;
        DBMS_OUTPUT.PUT_LINE('OK: all recorded backup pieces are marked available');
    ELSE
        :monitor_exit := 1;
        DBMS_OUTPUT.PUT_LINE('WARNING: ' || (l_total - l_available) ||
                             ' recorded backup piece(s) need investigation');
    END IF;
    -- Only a completed assessment emits this machine-readable marker.
    DBMS_OUTPUT.PUT_LINE('DGDB_BACKUP_PIECE_RESULT=' || :monitor_exit);
END;
/
EXIT :monitor_exit
SQL
  docker_exit=0
else
  docker_exit=$?
fi
cat "$report_file"
marker=$(awk '/^DGDB_BACKUP_PIECE_RESULT=[013]$/ { split($0, parts, "="); result=parts[2]; count++ } END { if (count == 1) print result }' "$report_file")
if [[ -z $marker || $docker_exit != "$marker" ]]; then
  printf 'UNKNOWN: Docker or SQL*Plus did not complete a valid health assessment (exit %d)\n' "$docker_exit" >&2
  exit 3
fi
exit "$marker"
