# Lab 1 — Oracle RMAN Datafile Recovery

**Purpose:** Repeatable local runbook and record of the completed exercise
**Completed:** 9 November 2026, according to the ChatGPT lab-session record
**Scope:** Guided recovery of one disposable application datafile; not a production incident

## Scenario and objectives

Recover application datafile 16 (`dbre_lab01.dbf`) for tablespace `DBRE_LAB` after simulated file loss. The source backup predates the second committed application transaction. RMAN must restore the file and apply archived redo so that both the baseline and post-backup transactions are present after the tablespace is returned online.

The objectives are to:

1. Keep database, backup, and archived redo files on persistent Docker volumes/directories.
2. Demonstrate a readable baseline backup and then a later backup containing `DBRE_LAB`.
3. Restore and recover datafile 16 after it is made unavailable.
4. Verify `RECOVERY_PROBE` transaction IDs 1 and 2 after recovery and confirm the final datafile status.

This guided local lab does not establish continuous availability for unaffected workloads, RTO/RPO performance, or independent troubleshooting competence. No workload availability monitoring or timed performance measurements were made.

## Environment and prerequisites

| Item | Value |
|---|---|
| Database | Oracle AI Database 26ai Free, release `23.26.3.0.0` |
| Architecture/runtime | Docker on Apple Silicon |
| CDB / PDB | `FREE` / `FREEPDB1` |
| Schema / table | `DBRE_APP.RECOVERY_PROBE` |
| Tablespace | `DBRE_LAB` |
| Datafile | File 16, `/opt/oracle/oradata/FREE/FREEPDB1/dbre_lab01.dbf` |
| Database volume | `oracle-db-data` |
| Backup volume / RMAN disk channel | `oracle-rman-backups`, mounted at `/opt/oracle/backups` |
| Archived redo directory | `/opt/oracle/oradata/archivelogs` |
| Control file autobackup format | `/opt/oracle/backups/%F` |
| RMAN disk channel format | `/opt/oracle/backups/%U` |

Before starting, confirm the intended disposable database, container mounts, free space, CDB/PDB, datafile-to-tablespace mapping, and writable persistent archive/backup destinations. Use SYSDBA for database-level setup and RMAN recovery, and `DBRE_APP` for probe transactions. Have an existing backup and required archived redo available before simulating file loss. Do not use a production or shared database.

The command blocks below are an operational template reconstructed from the recorded exercise, not a verbatim terminal transcript. Confirm local paths, credentials, SQL syntax, and RMAN configuration before use. Do not put passwords in shell history or shared evidence.

## Repeatable procedure

### 1. Check database identity and archive logging

Connect to the CDB as SYSDBA and confirm identity and logging mode:

```sql
SHOW CON_NAME;
SELECT name, log_mode FROM v$database;
SHOW PARAMETER log_archive_dest_1;

SELECT dest_id, status, destination, error
FROM v$archive_dest
WHERE dest_id = 1;
```

The persistent archive destination for this lab is `/opt/oracle/oradata/archivelogs`. Confirm the directory exists and is writable by Oracle, `LOG_ARCHIVE_DEST_1` points there, and `V$ARCHIVE_DEST` reports `VALID`. Switch/archive redo and verify the new archived log physically in that directory before relying on it for recovery. Preserve existing archived logs.

If the database is not in `ARCHIVELOG` mode, stop and follow the release-appropriate Oracle procedure in a planned maintenance window; do not improvise a mode change in the middle of recovery. In this lab, persistent archive destination configuration and a fresh archived log were described in repository notes; the actual query output and directory listing are not committed in Git.

### 2. Configure RMAN disk channel and control file autobackup

Connect to the target database with RMAN. The completed lab used these paths:

```text
rman target /
RMAN> CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/opt/oracle/backups/%U';
RMAN> CONFIGURE CONTROLFILE AUTOBACKUP ON;
RMAN> CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/opt/oracle/backups/%F';
RMAN> SHOW ALL;
```

Confirm that `/opt/oracle/backups` is the mounted `oracle-rman-backups` volume, rather than container-local storage. Review `SHOW ALL` and available storage before taking backups.

### 3. Create and validate the earlier baseline backup

The exercise first created an earlier full database backup, including archived redo, and ran:

```text
RMAN> BACKUP DATABASE PLUS ARCHIVELOG;
RMAN> RESTORE DATABASE VALIDATE;
```

**Important scope:** this `RESTORE DATABASE VALIDATE` was performed on the earlier baseline backup, before tablespace `DBRE_LAB` and its application datafile were created. It validated readability for that earlier backup; it did not validate the later backup containing datafile 16.

### 4. Create the lab tablespace and probe table

After the earlier baseline backup/validation, connect as SYSDBA and explicitly switch the session into the PDB before creating the application objects:

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
SHOW CON_NAME;

CREATE TABLESPACE DBRE_LAB
  DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/dbre_lab01.dbf'
  SIZE 100M
  AUTOEXTEND OFF
  LOGGING;

CREATE USER DBRE_APP
  IDENTIFIED BY "<set-a-lab-password-securely>"
  DEFAULT TABLESPACE DBRE_LAB
  QUOTA 20M ON DBRE_LAB;

GRANT CREATE SESSION, CREATE TABLE TO DBRE_APP;
```

Replace the password placeholder locally; do not save a real credential in this runbook, shell history, or shared evidence. Connect `DBRE_APP` to service `FREEPDB1`, then create the probe table:

```sql
CREATE TABLE recovery_probe (
  id NUMBER PRIMARY KEY,
  phase VARCHAR2(30) NOT NULL,
  notes VARCHAR2(100)
);
```

### 5. Commit the baseline transaction and take the recovery backup

As `DBRE_APP`, insert and commit the baseline transaction before the later backup:

```sql
INSERT INTO recovery_probe (id, phase, notes)
VALUES (1, 'BASELINE', 'Committed before recovery backup');
COMMIT;
```

Verify the baseline row, then take the later full backup that contains `DBRE_LAB` and archived redo:

```sql
SELECT id, phase
FROM recovery_probe
WHERE id = 1;
```

```text
RMAN> BACKUP DATABASE PLUS ARCHIVELOG;
```

After that backup completes, commit the post-backup transaction:

```sql
INSERT INTO recovery_probe (id, phase, notes)
VALUES (2, 'POST_BACKUP', 'Committed after recovery backup');
COMMIT;

SELECT id, phase
FROM recovery_probe
WHERE id IN (1, 2)
ORDER BY id;
```

Both rows must be present before proceeding. As SYSDBA in `FREEPDB1`, archive current redo and verify the relevant archived log exists physically in `/opt/oracle/oradata/archivelogs`:

```sql
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

Sequence 7 was reported as physically verified in the completed lab.

### 6. Confirm file mapping and simulate datafile loss

Before taking anything offline, confirm the file number, filename, tablespace, and database identity:

```sql
SELECT df.file#, df.name, ts.name AS tablespace_name, df.status, df.enabled
FROM v$datafile df
JOIN v$tablespace ts ON ts.ts# = df.ts#
WHERE df.file# = 16;
```

Make sure datafile 16 belongs to the disposable `DBRE_LAB` tablespace and that the backup, archived redo, and rollback copy are available. The simulation uses:

```sql
ALTER TABLESPACE DBRE_LAB OFFLINE IMMEDIATE;
```

Once the tablespace is offline, rename the original file inside the database container to preserve a rollback copy. Confirm the container name and both paths before running the command:

```sh
docker exec oracle-db mv \
  /opt/oracle/oradata/FREE/FREEPDB1/dbre_lab01.dbf \
  /opt/oracle/oradata/FREE/FREEPDB1/dbre_lab01.dbf.pre_failure
```

Do not delete or overwrite the `.pre_failure` copy. The completed exercise used this rename as a rollback precaution; its original command output is available in the ChatGPT session but was not independently saved in the Git repository.

An attempt to access the offline file produced ORA-00376 and ORA-01110 in the completed session; see the session-record section below. These errors are expected indicators of access to an unavailable file in this scenario, not proof of recovery success.

### 7. Restore and recover datafile 16

In RMAN, restore the offline datafile from the backup and perform media recovery, applying the required redo:

```text
RMAN> RESTORE DATAFILE 16;
RMAN> RECOVER DATAFILE 16;
```

The completed session identified backup piece `0apv56vp_10_1_1` as the source. RMAN reported successful completion of the restore and `media recovery complete` for recovery. Media recovery applies required redo; the record does not establish that only archived redo was used. The original command output exists in the ChatGPT session but was not independently saved in the Git repository.

After successful recovery, bring the tablespace online:

```sql
ALTER TABLESPACE DBRE_LAB ONLINE;
```

If restore/recovery fails, leave the tablespace offline and follow the rollback precautions below. Do not proceed by guessing at file names or moving files that Oracle may still have open.

### 8. Verify the recovered state

As a privileged account, verify tablespace and file state:

```sql
SELECT tablespace_name, status
FROM dba_tablespaces
WHERE tablespace_name = 'DBRE_LAB';

SELECT file_id, file_name, status, online_status
FROM dba_data_files
WHERE file_id = 16
  AND tablespace_name = 'DBRE_LAB';
```

As `DBRE_APP` in `FREEPDB1`, verify the two rows:

```sql
SELECT id, phase
FROM recovery_probe
WHERE id IN (1, 2)
ORDER BY id;
```

Acceptance requires both `(1, BASELINE)` and `(2, POST_BACKUP)` after recovery, the tablespace online, and datafile 16 reporting `AVAILABLE` / `ONLINE_STATUS` `ONLINE`. Save the actual SQL and RMAN output when repeating the lab; redact credentials and other secrets.

## Completed lab record — 9 November 2026

This section records results supplied from the ChatGPT lab session. It is distinct from evidence independently stored in Git.

### Reported session results

- Environment: Oracle AI Database 26ai Free release `23.26.3.0.0`, running in Docker on Apple Silicon; CDB `FREE`, PDB `FREEPDB1`.
- RMAN disk channel format: `/opt/oracle/backups/%U`.
- Control file autobackup format: `/opt/oracle/backups/%F`.
- Application object: `DBRE_APP.RECOVERY_PROBE` in `DBRE_LAB`; datafile 16, `dbre_lab01.dbf`.
- Transactions ID 1 / `BASELINE` and ID 2 / `POST_BACKUP` were both committed and verified before failure.
- Archived redo sequence 7 was verified physically.
- Datafile 16 was restored from backup piece `0apv56vp_10_1_1`; `RESTORE DATAFILE 16` completed successfully.
- `RECOVER DATAFILE 16` reported `media recovery complete`.
- `ALTER TABLESPACE DBRE_LAB ONLINE` succeeded.
- Both transactions were verified after recovery. Final datafile status was `AVAILABLE / ONLINE`.
- ORA-00376 and ORA-01110 were observed during the simulated unavailable-file phase.
- `RESTORE DATABASE VALIDATE` applied to the earlier baseline backup taken before `DBRE_LAB` was created. The later backup's readability was demonstrated by the actual restore of datafile 16 from piece `0apv56vp_10_1_1`.

Original command output exists in the ChatGPT lab session, but it was not independently saved in this Git repository. This document does not reproduce fabricated output. No RMAN job identifier, redo thread, SCN, or event timestamps are stated here; no timestamps beyond the session date are inferred.

### Evidence provenance and limits

| Evidence source | What it supports | Limits |
|---|---|---|
| Original ChatGPT lab session | Original command output and results for environment, RMAN configuration, transaction checks, sequence 7 physical verification, backup piece, restore/recovery, online operation, final state, and observed error codes | Output exists in the session but was not independently saved in Git. This documentation task did not independently query the database or verify the stored files. |
| Git repository `notes.md` | Intended persistent archive path, stated archive destination checks, and the two-transaction recovery objective | Notes contain no RMAN output, SQL query results, archived-log listing, backup manifest, or captured failure output. |
| Git repository `README.md` | Local Docker setup and Oracle reference links; names Oracle AI Database 26ai Free release `23.26.3.0.0` | README is setup documentation, not an execution log. |
| Independently stored execution artifacts in Git | None found | No independently saved RMAN transcript/log, SQL spool, screenshot, backup catalog export, or archived-redo listing is present in Git. |

Accordingly, the completed run results above are attributed to the ChatGPT session and original session output. They are not represented as independently verified from artifacts stored or committed in Git.

## Acceptance criteria for a repeat run

- Confirmed CDB/PDB identity, correct disposable tablespace and file mapping, persistent backup/archive destinations, and sufficient free space.
- `ARCHIVELOG` operation and persistent archive destination verified; the redo required for the test confirmed present.
- Baseline backup including archived redo completed; `RESTORE DATABASE VALIDATE` recorded with its scope stated accurately.
- `DBRE_LAB` and `RECOVERY_PROBE` created; ID 1 / `BASELINE` committed before the recovery backup; ID 2 / `POST_BACKUP` committed after it; both verified before failure.
- Later backup containing datafile 16 completed. For this runbook's workflow, successful actual restoration of datafile 16 is the evidence of later-backup readability; the earlier baseline `RESTORE DATABASE VALIDATE` does not cover it.
- Original file preserved for rollback; failure simulation limited to datafile 16 in `DBRE_LAB`.
- RMAN restore and media recovery succeed; tablespace is brought online; both probe rows and final datafile state are verified.
- On repeat runs, retain exact command/output, file path, RMAN piece/job and redo identifiers, and timestamps with secrets redacted.
- Claims about unaffected workloads, recovery time, recovery point, and operator independence are limited to directly measured evidence. This completed exercise did not establish these outcomes.

## Rollback and safety precautions

- Use only a disposable lab database and dedicated application tablespace/datafile. Verify database identity, file number, actual path, tablespace ownership, and Docker mounts before taking the file offline.
- Preserve the renamed original datafile until recovery and validation are complete. Record its original and temporary paths. Do not overwrite or delete it while the recovery result is uncertain.
- Never run this simulation against production or a shared database. A wrong file number, tablespace, or path can cause data loss or an outage.
- If restore or recovery fails, keep the tablespace offline and stop. Check database identity, file mapping, backup availability, archive destination, and RMAN diagnostics before another attempt. Avoid moving files while Oracle may still have them open.
- Do not remove or recreate `oracle-db-data` or `oracle-rman-backups` as cleanup. They hold persistent database state and recovery material.
- Return a manually renamed file only after identifying the authoritative copy and confirming Oracle file metadata. Do not bring the tablespace online with a missing or mismatched datafile.
- Do not change Docker, Oracle, or backup volumes/files as part of document review. The procedure itself writes backup/data files and changes database state, so repeat only when explicitly intended in the disposable lab.

## Operational risks and lessons

- Archived redo stored only in the container writable layer may be lost when the container is replaced. Verify the persistent destination with a fresh archive operation and preserve existing logs.
- A baseline `RESTORE ... VALIDATE` proves readability only for the backup and scope on which it ran. Here, it preceded creation of `DBRE_LAB`; the later datafile backup was exercised through an actual restore of file 16.
- Restore writes a datafile; recovery applies redo. Validate database identity, PDB, datafile mapping, backup piece, and required archived redo before either operation.
- `OFFLINE IMMEDIATE` interrupts access to the target tablespace. ORA-00376/ORA-01110 identify the unavailable-file condition in this lab but do not prove the cause is correct or that recovery succeeded.
- This lab covered one datafile recovery only. It did not test control-file or SPFILE loss, database-volume loss, missing archived redo, point-in-time recovery, corruption detection, or workload continuity.
- AI guidance was used. The completed guided exercise is not evidence of independent troubleshooting competence. Operators should understand and validate each command and outcome before applying the procedure elsewhere.
- No continuous availability monitoring, elapsed-time measurement, or recovery-point/performance study was performed. RTO/RPO performance and production recovery readiness therefore remain unestablished.
