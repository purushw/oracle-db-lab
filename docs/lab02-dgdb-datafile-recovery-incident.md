# Lab 2 — DGDB datafile recovery incident report

**Date:** 17 November 2026
**System:** Oracle AI Database 26ai Free, PDB `FREEPDB1`, `DGDB_DATA` datafile 17
**Scope:** I took the `DGDB_DATA` tablespace offline, renamed its datafile to simulate physical loss, then restored and recovered the datafile.

## Failure and observed error

I ran `ALTER TABLESPACE DGDB_DATA OFFLINE IMMEDIATE;`, which returned `Tablespace altered.` I then renamed `dgdb_data01.dbf` to `offline_dgdb_data01.dbf` in `/opt/oracle/oradata/FREE/FREEPDB1/` to simulate physical loss. `ls` confirmed the original file was preserved under the new name. A query across the eight `DGDB` tables failed with `ORA-00376: file 17 cannot be read at this time` and `ORA-01110`, which named the original datafile path. The local SQL*Plus log does not timestamp the rename relative to the failed query.

## RMAN restore and recovery

I ran:

```rman
RESTORE DATAFILE 17;
RECOVER DATAFILE 17;
```

This was a restore of the missing file followed by media recovery, not just a tablespace online operation. RMAN restored datafile 17 to its original path from `/opt/oracle/backups/dgdb_l2_0jn7237n_19_1_1` (tag `DGDB_L2_BASELINE`). The restore completed in 00:00:01. Recovery then reported `media recovery complete` in 00:00:01. RMAN found local archived logs for thread 1, sequences 14–26; its recovery progress named sequences 14–24. I have no evidence that it applied sequences 25–26, and the output does not give a final datafile checkpoint SCN.

## Return to service and application checks

I ran `ALTER TABLESPACE DGDB_DATA ONLINE;` successfully. `DBA_TABLESPACES` showed `DGDB_DATA` as `ONLINE`, and `DBA_DATA_FILES` showed file 17 as `AVAILABLE` and `ONLINE`.

After recovery, I counted 40 products, 50 customers, 40 inventory rows, 12 orders, 12 order items, 12 reservations, 9 payments, and 46 stock movements. All eight counts match my 17 November pre-incident check. The physical-stock and reserved-stock reconciliation queries both returned no rows. Order statuses were 6 `FULFILLED`, 2 `PAID`, 2 `PENDING`, 1 `CANCELLED`, and 1 `EXPIRED`; payments were 8 `SUCCEEDED` and 1 `FAILED`, also matching the earlier check. The post-recovery query recorded `17-NOV-26 12:19:18.317341 PM +00:00` and `CURRENT_SCN` 4219453. The pre-incident check recorded SCN 4216261 at `11:49:54.989107 AM +00:00`.

## Result and limits

I restored and recovered the missing datafile, then brought the tablespace online. The DGDB tables were readable again. My table counts and status counts matched the pre-incident check, and both stock reconciliations found no discrepancies. The renamed original file was preserved, but I have no later file listing confirming its state after recovery. I did not run a post-recovery order-total reconciliation, and no off-host backup has been verified. These checks do not prove every row value is identical or test the full application. I did not capture exact incident start and end times. The two SCNs are database-wide observations; they do not prove a particular row-level recovery point.

## Evidence reviewed

- [Pre-incident integrity](../evidence/lab2/pre-incident-integrity-2026-11-17.txt): table counts, stock reconciliations, order/payment states, SCN, and Docker mount output.
- [Post-recovery integrity](../evidence/lab2/dgdb-post-recovery-integrity.txt): SQL*Plus offline/error, online status, and post-recovery checks.
- [RMAN recovery transcript](../evidence/lab2/rman-recovery-transcript.txt): restore piece, archived-log listing, completed media recovery, and a separately labeled excerpt of my shell `mv` and confirming `ls` output.
