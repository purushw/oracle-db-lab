# Source this file from Zsh; do not execute it as a standalone program.

dg-alert() {
  local container_name="${DGDB_CONTAINER_NAME:-oracle-db}"
  docker exec -i "$container_name" adrci \
    'exec=set homepath diag/rdbms/free/FREE; show alert -tail 30'
}

dg-sh() {
  local container_name="${DGDB_CONTAINER_NAME:-oracle-db}"
  docker exec -it "$container_name" sh
}
