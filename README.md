# Oracle Database Free RMAN Recovery Lab

This repository contains the setup and exercises for a local Oracle Database Free recovery lab using RMAN.

## Prerequisites

- Docker Desktop installed and running
- Oracle Database Free image pulled from Oracle Container Registry
- Named Docker volume `oracle-db-data` created

## Start the database

Run this command to create and start the `oracle-db` container:

```sh
docker run -d \
  --name oracle-db \
  -p 1521:1521 \
  -v oracle-db-data:/opt/oracle/oradata \
  container-registry.oracle.com/database/free:latest
```

The `oracle-db-data` volume stores the database files outside the container, so they persist if the container is removed and recreated.

## Container controls

```sh
docker ps                         # Check whether the database container is running
docker logs -f oracle-db          # Follow database startup logs
docker stop oracle-db             # Stop the database
docker start oracle-db            # Start the existing container again
```

The database may take a few minutes to initialize on its first start. Follow the logs until Oracle reports that the database is ready before connecting or starting recovery exercises.
