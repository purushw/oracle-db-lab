#!/usr/bin/env bash
# Read-only cross-check of archived redo copies and logical sequences against
# RMAN backup-set records in the current database control file.
set -euo pipefail

container_name="${DGDB_CONTAINER_NAME:-oracle-db}"

if ! command -v docker >/dev/null 2>&1; then
  printf 'docker was not found in PATH\n' >&2
  exit 127
fi

exec docker exec -i "$container_name" sqlplus -s '/ as sysdba' <<'SQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET PAGESIZE 200
SET LINESIZE 240
SET TRIMSPOOL ON
SET TAB OFF
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
           MAX(completion_time) AS latest_copy_time
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
       TO_CHAR(a.latest_copy_time, 'YYYY-MM-DD HH24:MI:SS') AS latest_copy,
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

EXIT SUCCESS
SQL
