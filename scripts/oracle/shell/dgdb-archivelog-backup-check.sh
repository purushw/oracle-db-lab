#!/usr/bin/env bash
# Read-only cross-check of archived redo copies and logical sequences against
# RMAN backup-set records in the current database control file.
# Exit 0 = OK; 2 = CRITICAL (unbacked for over 30 minutes); 3 = UNKNOWN/ERROR.
set -euo pipefail

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
COLUMN backup_state FORMAT A24
COLUMN archived_status FORMAT A6
COLUMN deleted FORMAT A7
COLUMN file_name FORMAT A95
COLUMN latest_rman_backup FORMAT A19

-- A logical archived log is identified by resetlogs incarnation, redo thread,
-- and sequence. Multiple V$ARCHIVED_LOG rows can be physical copies of it.
-- Include archived-log control-file records even when NAME is NULL or a copy
-- is marked deleted. RMAN DELETE INPUT can clear/remove those copies after a
-- successful backup; the RMAN metadata join below decides backup coverage.
PROMPT Logical archived logs with no RMAN backup-set record
WITH archived_logs AS (
    SELECT resetlogs_change#,
           thread#,
           sequence#,
           MIN(first_change#) AS first_change#,
           MAX(next_change#) AS next_change#,
           MIN(completion_time) AS first_archived_at
    FROM v$archived_log
    WHERE archived = 'YES'
    GROUP BY resetlogs_change#, thread#, sequence#
), rman AS (
    SELECT r.resetlogs_change#,
           r.thread#,
           r.sequence#,
           COUNT(*) AS backup_set_records,
           MAX(b.completion_time) AS latest_rman_backup
    FROM v$backup_redolog r
    JOIN v$backup_set b
      ON b.set_stamp = r.set_stamp
     AND b.set_count = r.set_count
    GROUP BY r.resetlogs_change#, r.thread#, r.sequence#
)
SELECT a.resetlogs_change#,
       a.thread#,
       a.sequence#,
       a.first_change#,
       a.next_change#,
       TO_CHAR(a.first_archived_at, 'YYYY-MM-DD HH24:MI:SS') AS first_archived_at,
       NVL(r.backup_set_records, 0) AS rman_backup_records,
       TO_CHAR(r.latest_rman_backup, 'YYYY-MM-DD HH24:MI:SS') AS latest_rman_backup
FROM archived_logs a
LEFT JOIN rman r
  ON r.resetlogs_change# = a.resetlogs_change#
 AND r.thread# = a.thread#
 AND r.sequence# = a.sequence#
WHERE r.backup_set_records IS NULL
ORDER BY a.resetlogs_change#, a.thread#, a.sequence#;

-- This report is copy-level: it keeps separate archive destinations/files
-- visible, since BACKUP_COUNT belongs to the archived-log copy record.
-- RMAN matches are sequence-level metadata, so the same match can appear for
-- multiple copies of the same logical log.
PROMPT Archived-log copies with RMAN metadata cross-reference
WITH rman AS (
    SELECT r.resetlogs_change#,
           r.thread#,
           r.sequence#,
           COUNT(*) AS backup_set_records,
           MAX(b.completion_time) AS latest_rman_backup
    FROM v$backup_redolog r
    JOIN v$backup_set b
      ON b.set_stamp = r.set_stamp
     AND b.set_count = r.set_count
    GROUP BY r.resetlogs_change#, r.thread#, r.sequence#
)
SELECT a.resetlogs_change#,
       a.thread#,
       a.sequence#,
       a.first_change#,
       a.next_change#,
       a.status AS copy_status,
       a.deleted,
       a.backup_count AS copy_backup_count,
       NVL(r.backup_set_records, 0) AS rman_backup_records,
       CASE WHEN r.backup_set_records IS NULL THEN 'NO RMAN RECORD'
            ELSE 'RMAN RECORD FOUND' END AS backup_state,
       TO_CHAR(r.latest_rman_backup, 'YYYY-MM-DD HH24:MI:SS') AS latest_rman_backup,
       a.name AS file_name
FROM v$archived_log a
LEFT JOIN rman r
  ON r.resetlogs_change# = a.resetlogs_change#
 AND r.thread# = a.thread#
 AND r.sequence# = a.sequence#
WHERE a.name IS NOT NULL
ORDER BY a.resetlogs_change#, a.thread#, a.sequence#, a.recid;

-- Age is measured from the first archived copy of each logical log. Duplicate
-- copies and deleted/NULL-NAME records remain in scope. Backup-piece access
-- is outside this metadata-only check and requires separate validation.
VARIABLE monitor_exit NUMBER
DECLARE
    l_overdue_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO l_overdue_count
    FROM (
        SELECT resetlogs_change#, thread#, sequence#,
               MIN(completion_time) AS first_archived_at
        FROM v$archived_log
        WHERE archived = 'YES'
        GROUP BY resetlogs_change#, thread#, sequence#
    ) a
    WHERE a.first_archived_at < SYSDATE - (30 / 1440)
      AND NOT EXISTS (
          SELECT 1
          FROM v$backup_redolog r
          JOIN v$backup_set b
            ON b.set_stamp = r.set_stamp
           AND b.set_count = r.set_count
          WHERE r.resetlogs_change# = a.resetlogs_change#
            AND r.thread# = a.thread#
            AND r.sequence# = a.sequence#
      );

    IF l_overdue_count > 0 THEN
        :monitor_exit := 2;
        DBMS_OUTPUT.PUT_LINE('CRITICAL: ' || l_overdue_count ||
                             ' archived redo sequence(s) lack RMAN backup evidence for over 30 minutes');
    ELSE
        :monitor_exit := 0;
        DBMS_OUTPUT.PUT_LINE('OK: no archived redo sequence exceeds the 30-minute backup window');
    END IF;
    DBMS_OUTPUT.PUT_LINE('DGDB_ARCHIVELOG_RESULT=' || :monitor_exit);
END;
/
EXIT :monitor_exit
SQL
  docker_exit=0
else
  docker_exit=$?
fi
cat "$report_file"
marker=$(awk '/^DGDB_ARCHIVELOG_RESULT=[02]$/ { split($0, parts, "="); result=parts[2]; count++ } END { if (count == 1) print result }' "$report_file")
if [[ -z $marker || $docker_exit != "$marker" ]]; then
  printf 'UNKNOWN: Docker or SQL*Plus did not complete a valid health assessment (exit %d)\n' "$docker_exit" >&2
  exit 3
fi
exit "$marker"
