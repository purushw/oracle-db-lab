# Oracle RMAN — DBA Cheat Sheet

**Environment:** Oracle AI Database 26ai Free
**Lab:** Daily Grind Skate Co. (DGDB)
**Last updated:** 13 November 2026

## 1. Connect to RMAN

From inside the Oracle Docker container:

`rman target /`

Connects RMAN to the local Oracle database using operating-system authentication.

For our multitenant environment, the RMAN session targets the CDB, `FREE`, including its PDB `FREEPDB1`.

## 2. Inspect RMAN configuration

| Command | What it does |
|---|---|
| `SHOW ALL;` | Displays RMAN configuration, including retention, channels, autobackups and backup formats |
| `REPORT SCHEMA;` | Shows the database datafiles, file numbers, tablespaces and locations |
| `LIST BACKUP SUMMARY;` | Provides a condensed list of registered backups |
| `LIST BACKUP;` | Displays detailed backup information |
| `LIST BACKUP OF DATAFILE 17;` | Checks whether a backup of DGDB datafile 17 exists |
| `LIST BACKUP OF ARCHIVELOG ALL;` | Lists archived redo logs included in registered backups |

These are read-only investigation commands.

### Important configuration settings

`CONFIGURE CONTROLFILE AUTOBACKUP ON;`

Automatically backs up the control file and SPFILE after qualifying backup operations and structural changes.

`CONFIGURE RETENTION POLICY TO REDUNDANCY 1;`

Keeps at least one backup generation under the configured redundancy policy. **This does not automatically delete old backups.** It determines which backups RMAN considers obsolete.

## 3. Create backups

### Full database and archived redo

`BACKUP DATABASE PLUS ARCHIVELOG;`

- Backs up database datafiles.
- Backs up archived redo logs.
- Forces redo log switches around the database backup to capture required redo.
- Supports recovery of an online database backup.

This is the core command we selected for DGDB.

### Full backup with explicit destination and tag

```text
BACKUP FORMAT '/opt/oracle/backups/dgdb_l2_%U'
TAG 'DGDB_L2_BASELINE'
DATABASE PLUS ARCHIVELOG;
```

- `FORMAT` specifies where backup pieces are written.
- `%U` generates unique backup-piece filenames.
- `TAG` gives the backup a recognisable name.
- `PLUS ARCHIVELOG` includes archived redo backups.

**DGDB backup location:** `/opt/oracle/backups` — persistent Docker volume `oracle-rman-backups`.

### Archived redo only

`BACKUP ARCHIVELOG ALL;`

Backs up available archived redo logs without creating a new database datafile backup.

Useful between full database backups, subject to the recovery and retention strategy.

## 4. Validate backups

These commands test restore feasibility without overwriting live database datafiles.

| Command | What it verifies |
|---|---|
| `RESTORE DATABASE VALIDATE;` | RMAN can read and validate database backup pieces selected for restoration |
| `RESTORE ARCHIVELOG ALL VALIDATE;` | Validates the archived logs RMAN selects; inspect output to determine whether it read local logs or backup pieces |
| `VALIDATE BACKUPSET 17,21;` | Reads the DGDB baseline archived redo backup pieces |
| `VALIDATE DATABASE;` | Checks live database files for corruption; does not validate backup pieces |
| `BACKUP VALIDATE CHECK LOGICAL DATABASE;` | Reads database files and checks physical and logical block integrity without creating a backup |
| `RESTORE DATABASE PREVIEW;` | Shows which backups RMAN plans to use without reading all backup contents |

**Critical distinction:**

- `BACKUP` = Create a backup.
- `RESTORE ... VALIDATE` = Check whether backup files can be restored.
- `VALIDATE DATABASE` = Check the current database files.
- `RESTORE` = Copy database files back from backup.
- `RECOVER` = Apply redo to bring restored files forward to a consistent recovery point.

A successful validation does **not** guarantee a complete recovery. It doesn't prove that every required redo log is available or that the database will open successfully.

## 5. DGDB — Verified backup baseline

**Date:** 13 November 2026
**Tag:** `DGDB_L2_BASELINE`

| Component | Result |
|---|---|
| Full CDB backup | Successful |
| DGDB datafile 17 | Included |
| Archived redo sequences 1–14 | Backed up |
| Control file autobackup | Successful |
| SPFILE autobackup | Successful |
| `RESTORE DATABASE VALIDATE` | Successful |
| `RESTORE ARCHIVELOG ALL VALIDATE` | Completed without errors; scanned local archived logs |
| `VALIDATE BACKUPSET 17,21` | Successful; read both archived redo backup pieces |
| Actual restore and recovery test | Pending |

**DGDB datafile:**

`/opt/oracle/oradata/FREE/FREEPDB1/dgdb_data01.dbf`

**Backup control file and SPFILE:**

`/opt/oracle/backups/c-1510161217-20261113-00`

### What we learned

On 13 November, RMAN reported:

`specification does not match any backup in the repository`

when querying the previous backup coverage for datafile 17.

This established that DGDB had no registered datafile backup at that stage.

We then created a full CDB backup with archived redo, explicitly including datafile 17.

`RESTORE DATABASE VALIDATE` successfully read the three database backup pieces.

`RESTORE ARCHIVELOG ALL VALIDATE` scanned local archived logs without errors. `VALIDATE BACKUPSET 17,21` separately read the two archived redo backup pieces.

See [DGDB RMAN baseline](dgdb-rman-baseline.md) for the backup inventory, SCNs, and recovery limits.

This verifies the selected database backups are readable by RMAN, but we have not yet tested redo application or actual recovery.

## 6. Common RMAN terminology

| Term | Meaning |
|---|---|
| SCN | System Change Number — Oracle's logical ordering of database changes |
| ARCHIVELOG | Mode that archives filled redo logs, supporting media recovery |
| Backup set | RMAN's logical collection of backed-up files |
| Backup piece | Physical file containing RMAN backup data |
| Control file | Records database structure and RMAN repository information |
| SPFILE | Binary server parameter file used to initialise Oracle |
| Redundancy | Number of backup generations the retention policy preserves |
| Obsolete backup | Backup no longer required under RMAN's retention policy |
| Recover | Apply redo to restored datafiles |
| PITR | Point-in-time recovery, recovering to a chosen time or SCN |

## 7. Production DBA safety reminders

- Verify the target CDB/PDB before running operations.
- Confirm available backup storage before creating large backups.
- Do not equate successful backup completion with successful recovery.
- Validate both database backups and required archived redo.
- Check that control file and SPFILE recovery is possible.
- Never run `DELETE OBSOLETE` without reviewing the retention policy and recovery requirements.
- Keep an independent copy of backups outside the database's failure domain.
- Conduct periodic real restore/recovery tests.
- Document observed recovery time and achieved recovery point.

**Golden rule:** A backup is only useful when you can demonstrate that it supports the recovery you need.
