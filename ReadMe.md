Module 1 – Containerization with Docker & SQL 

Overview
This repository contains a focused, hands-on Module 1 for learning practical data engineering concepts using Docker and a local PostgreSQL instance. The exercises and code in this module show how to: build and run containerized services, persist and manage database data, ingest CSV datasets into Postgres, and run simple data pipelines from both host and container environments.

What's included
- `docker-compose.yml` and `Dockerfile`: service definitions and image build for the project.
- `nyc_taxi_postgres_data/`: a mounted Postgres data directory (used as a persistent volume).
- Ingestion and pipeline code: `ingest_data.py`, `pipeline.py`, and `upload_data.ipynb`.
- Example datasets: `yellow_tripdata_2021-01.csv`, `taxi_zone_lookup.csv`, `yello_head.csv`.
- Utility scripts: `test-docker.sh`, `pgadmin.sh` for quick testing and administration.

Architecture (conceptual)
The following ASCII diagram illustrates the main components and data flow in Module 1:

```
			 +----------------- Host -----------------+
			 |                                         |
  Local CSV  |  ingest_data.py / pipeline.py  Scripts  |
  files ---> |          (exploratory notebook)         |-->
			 |                                         |
			 +-----------------------------------------+
						   |
						   | mounted volume / file mounts
						   v
				+-------------------------------+
				|     Docker Compose Stack      |
				|  +-------------------------+  |
				|  |  Postgres Container     |  |
				|  |  (data persisted to      |  |
				|  |   nyc_taxi_postgres_data/)|  |
				|  +-------------------------+  |
				|  +-------------------------+  |
				|  |  pgAdmin  |  |
				|  +-------------------------+  |
				+-------------------------------+

Connections:
- Scripts connect to Postgres over the container network (host or container).
- Admin connects to Postgres with a web UI for inspection and debugging.
```

Key learning outcomes
- Containerization fundamentals: building images, running containers, and reproducible environments.
- Docker Compose: defining multi-service stacks and cross-container networking.
- Persistent storage: mounting host directories into containers and understanding Postgres data directories.
- Data ingestion: reading CSV files and loading into Postgres via Python (pandas/psycopg2 or SQLAlchemy).
- Local pipeline patterns: simple Python-based ETL orchestration (`pipeline.py`) and exploratory work in `upload_data.ipynb`.
- Admin and debugging: using `pgAdmin`, `psql`, and helpful scripts like `test-docker.sh` to validate setups.

Quick start (Module 1)
1. Build and start services:

```bash
docker-compose up --build -d
```

2. Confirm the Postgres container is running and the data volume is mounted.

3. Run the ingestion script (from host or inside a container, depending on your setup):

```bash
python3 ingest_data.py
# or
./test-docker.sh
```

4. Open the admin UI (if provided) or connect with `psql` to inspect tables and queries.

Where to find Module 2
Module 2 (workflow orchestration and more advanced pipeline examples) is maintained on a separate branch. See: [Module 2 branch](https://github.com/Edwin574/docker-sql-for-data-engineering/tree/wokflow_orchestration)
