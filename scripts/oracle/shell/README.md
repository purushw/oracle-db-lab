# DGDB shell helper

Source `dgdb-tools.sh` from `~/.zshrc` to make `dg-alert` available in new Zsh sessions:

```zsh
source "$HOME/projects/oracle-db-lab/scripts/oracle/shell/dgdb-tools.sh"
```

`dg-alert` reads the last 30 lines of the Oracle alert log through ADRCI in the configured Docker container. The default container name is `oracle-db`. If your container uses a different name, set `DGDB_CONTAINER_NAME` before sourcing the script:

```zsh
export DGDB_CONTAINER_NAME=my-oracle-container
source "$HOME/projects/oracle-db-lab/scripts/oracle/shell/dgdb-tools.sh"
dg-alert
```

The container must be running and accessible through `docker exec`. The helper is read-only and does not change database or Docker configuration.
