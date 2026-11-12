# Oracle Database Free RMAN Recovery Lab

This repository contains the setup and exercises for a local Oracle Database Free recovery lab using RMAN.

The pulled image is **Oracle AI Database 26ai Free Release 23.26.3.0.0** ("Develop, Learn, and Run for Free").

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

## Connect with SQL*Plus

SQL*Plus is included in the Oracle database container, so no separate host installation is required for basic lab use. After the database is ready, open a SQL*Plus session as SYSDBA with:

```sh
docker exec -it oracle-db sqlplus / as sysdba
```

Exit SQL*Plus with `EXIT` or `QUIT`.

## Oracle documentation

- [Oracle Database Free image on Oracle Container Registry](https://container-registry.oracle.com/ords/ocr/ba/database/free) — available image tags and image-specific instructions.
- [Oracle Database container image README](https://github.com/oracle/docker-images/blob/main/OracleDatabase/SingleInstance/README.md) — Oracle's container usage examples, configuration, volumes, and startup scripts.
- [Oracle Database container FAQ](https://github.com/oracle/docker-images/blob/main/OracleDatabase/SingleInstance/FAQ.md) — common questions about Oracle's container images.
- [Oracle AI Database 26ai Backup and Recovery User's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/bradv/index.html) — RMAN concepts, backup, restore, and recovery procedures.
- [Getting Started with RMAN](https://docs.oracle.com/en/database/oracle/oracle-database/26/bradv/getting-started-rman.html) — introductory RMAN workflow and quick-start examples.
- [Oracle AI Database 26ai Backup and Recovery Reference](https://docs.oracle.com/en/database/oracle/oracle-database/26/rcmrf/index.html) — RMAN command syntax and reference.
