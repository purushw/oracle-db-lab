# DGDB Lab 2 — RMAN backup baseline

**Completed:** 13 November 2026. This records the supplied RMAN results; no recovery exercise is recorded here.

## Environment

- Oracle AI Database 26ai Free: CDB `FREE`, PDB `FREEPDB1`.
- DGDB tablespace `DGDB_DATA`: datafile **17**, `/opt/oracle/oradata/FREE/FREEPDB1/dgdb_data01.dbf`.
- Backup directory `/opt/oracle/backups` is on persistent Docker volume `oracle-rman-backups`, separate from the `oracle-db-data` volume.

## Backup Strategy

The earlier backups did not contain DGDB datafile 17. This full CDB backup established its first registered datafile backup and included archived redo. `CONFIGURE CONTROLFILE AUTOBACKUP ON;` was enabled, and the retention policy was `REDUNDANCY 1`. Redundancy 1 determines what RMAN regards as obsolete; it does not itself remove backup pieces.

The backup volume is separate from the database volume, but no independent off-host or off-machine copy has been verified.

## RMAN Commands

| Command | Purpose or recorded result |
|---|---|
| `CONFIGURE CONTROLFILE AUTOBACKUP ON;` | Existing setting observed: control file and SPFILE autobackup enabled; not executed during this session. |
| `CONFIGURE RETENTION POLICY TO REDUNDANCY 1;` | Existing setting observed: one backup generation as the retention threshold; not executed during this session. |
| `BACKUP FORMAT '/opt/oracle/backups/dgdb_l2_%U' TAG 'DGDB_L2_BASELINE' DATABASE PLUS ARCHIVELOG;` | Create the recorded CDB and archived redo backup. |
| `LIST BACKUP TAG 'DGDB_L2_BASELINE';` | Investigate the tagged baseline backup sets and pieces. |
| `LIST BACKUP OF DATAFILE 17;` | Investigate which backup contains DGDB datafile 17. |
| `RESTORE DATABASE VALIDATE;` | Read the three selected database backup sets without restoring datafiles. |
| `RESTORE ARCHIVELOG ALL VALIDATE;` | Scan the local archived logs selected by this validation; completed without errors. |
| `VALIDATE BACKUPSET 17,21;` | Read both archived redo backup pieces; completed successfully. |

## Backup Inventory

Backup **set** numbers identify RMAN backup sets; datafile **17** identifies a database file. Backup set 17 contains archived redo and is not the backup of datafile 17. Datafile 17 is in backup set 19.

| Set | Contents | Reported size | Piece |
|---:|---|---:|---|
| 17 | Archived redo sequences 1–13 | 1.15 GB | `/opt/oracle/backups/dgdb_l2_0hh7237h_17_1_1` |
| 18 | CDB root datafiles | 1.54 GB | `/opt/oracle/backups/dgdb_l2_0ik7237k_18_1_1` |
| 19 | `FREEPDB1` datafiles, including DGDB datafile 17 | 704.88 MB | `/opt/oracle/backups/dgdb_l2_0jn7237n_19_1_1` |
| 20 | `PDB$SEED` datafiles | 561.46 MB | `/opt/oracle/backups/dgdb_l2_0ko7237o_20_1_1` |
| 21 | Archived redo sequence 14 | 19.50 KB | `/opt/oracle/backups/dgdb_l2_0lp7237p_21_1_1` |

Control file and SPFILE autobackup: `/opt/oracle/backups/c-1510161217-20261113-00`.

## SCN and Redo Coverage

`PLUS ARCHIVELOG` backed up archived redo before and after the database datafiles: set 17 contains sequences 1–13, and set 21 contains sequence 14. These are backup-set identifiers, independent of the redo sequence numbers.

Datafile 17 has checkpoint SCN **3381958**. Archived redo sequence 14 covers SCNs **3381912** through **3381965 exclusive**. The checkpoint lies inside that recorded range. SCNs order database changes and help identify potential redo coverage; this metadata alone does not prove that every required change can be applied in a real recovery.

## Validation Evidence

- `RESTORE DATABASE VALIDATE` completed successfully and read all three database backup sets: 18, 19 and 20. This establishes RMAN readability of the selected datafile backup pieces, including the piece containing datafile 17.
- `RESTORE ARCHIVELOG ALL VALIDATE` completed without errors while scanning local archived logs. This result alone is not evidence that archived redo backup pieces were read.
- `VALIDATE BACKUPSET 17,21` completed successfully and read both archived redo backup pieces.

## Recovery Limitations

These checks establish backup-piece readability for the selected database and archived redo sets. They do **not** demonstrate a complete restore and recovery. No datafile restore, redo application, or database open test is recorded for this Lab 2 baseline. Actual recovery testing remains pending. Backup pieces have not been verified independently off-host or off-machine.

## Next Recovery Exercise

Plan a controlled restore and recovery test for DGDB datafile 17, confirm the recovered data and database open state, and record the actual backup pieces, redo applied, recovery point, and result. Keep that exercise separate from this baseline record.
