# DGDB Oracle shell tools

Source the helper from `~/.zshrc` to make `dg-alert` and `dg-sh` available in new Zsh sessions:

```zsh
source "$HOME/projects/oracle-db-lab/scripts/oracle/shell/dgdb-tools.sh"
```

All tools use the Docker container named `oracle-db` by default. Set `DGDB_CONTAINER_NAME` to use another container name:

```zsh
export DGDB_CONTAINER_NAME=my-oracle-container
```

`dg-alert` reads the last 30 Oracle alert-log lines through ADRCI. `dg-sh` opens an interactive `sh` shell in the container; commands entered there can change database or container state.

## Backup health monitors

Run these from the repository root:

```sh
./scripts/oracle/shell/dgdb-archivelog-backup-check.sh
./scripts/oracle/shell/dgdb-backup-piece-check.sh
```

Both scripts currently connect inside the container as SYSDBA and run read-only SQL. A least-privilege `dbcheck` account is intended later. They do not run RMAN `CROSSCHECK`, `DELETE`, `CHANGE`, or validation operations.

The archive-log check lists logical archived-redo sequences without matching RMAN backup-set metadata and shows a separate copy-level cross-reference. It matches by resetlogs incarnation, thread, and sequence. A sequence can have multiple archive copies, each with its own `BACKUP_COUNT`. It returns **0 OK** if no unbacked sequence exceeds 30 minutes, **2 CRITICAL** if any does, and **3 UNKNOWN** for Docker, connection, or SQL errors.

The backup-piece check lists every recorded piece and copy, joins each to its backup set using `SET_STAMP` and `SET_COUNT`, and checks the expected piece numbers `1..PIECES`. It reports counts for available, expired, deleted, unavailable, and unexpected statuses. It returns **0 OK** when all inventoried pieces are marked available, **1 WARNING** when any piece has another status, and **3 UNKNOWN** when the inventory cannot be assessed or execution fails. Exit **2** is reserved for a separately verified critical recovery condition.

Test the backup-piece WARNING branch without connecting to Oracle by putting one piece status per line in a fixture:

```sh
printf 'A\nX\n' > /tmp/dgdb-piece-statuses.txt
./scripts/oracle/shell/dgdb-backup-piece-check.sh --fixture /tmp/dgdb-piece-statuses.txt
```

For piece-number and copy checks, `--set-fixture FILE` accepts rows of `SET_STAMP SET_COUNT PIECES PIECE# COPY# STATUS`; see `tests/test-dgdb-backup-piece-check.sh`.

These reports describe control-file metadata. An `A` backup-piece status does not prove the physical file exists or is readable. Physical validation requires a separately authorised RMAN operation. Neither monitor establishes which backup sets are required for recovery or whether the RPO is achievable.
