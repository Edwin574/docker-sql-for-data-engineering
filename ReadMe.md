# Data Engineering Learning Project

This repository serves as a learning sandbox for fundamental data engineering concepts, split into different modules.

---

## Module 1 – Containerization with Docker & SQL

This module is designed for learning data engineering fundamentals focusing on:
- **Containerization with Docker**: Running services in isolated, reproducible containers.
- **SQL basics**: Interacting with a relational database from within containers.

*For Terraform infrastructure setup, please check this repository:* [terraform-for-data-engineering](https://github.com/Edwin574/terraform-for-data-engineering)

---

## Module 2 – Workflow Orchestration with Kestra

This module focuses on **Workflow Orchestration**, which allows us to automate, schedule, schedule backfills, and monitor ETL/ELT pipelines. We use **Kestra**, an event-driven, language-agnostic orchestrator that defines pipelines as code using YAML files.

### 1. Infrastructure Architecture (`docker-compose.yml`)

The infrastructure for orchestration, database administration, and target data storage is defined in [docker-compose.yml](./docker-compose.yml). It manages four distinct containers to coordinate the ingestion process:

| Service Name | Docker Image | Host Port | Purpose & Rationale |
| :--- | :--- | :--- | :--- |
| **`pgdatabase`** | `postgres:15` | `5432` | The **Target Data Warehouse**. This database stores the production NYC Taxi trip records (`green_tripdata` and `yellow_tripdata`) and taxi zone lookups. |
| **`pgadmin`** | `dpage/pgadmin4` | `8082` | Web-based interface used to inspect tables, write queries, and monitor `pgdatabase` database state. |
| **`kestra_postgres`** | `postgres:17` | *Internal only* | The **Kestra Metadata Repository**. It persists flow definitions, execution state history, schedules, logs, and job queues. |
| **`kestra`** | `kestra/kestra:v1.1` | `8080`, `8081` | The **Kestra Orchestration Server**. It runs in `standalone` mode, serving the UI on port `8080` and coordinate schedulers and execution workers. |

#### Architectural Key Points
1. **Database Separation**: Isolating `kestra_postgres` from `pgdatabase` ensures Kestra's metadata/log traffic does not compete for database resources (CPU, I/O, disk writes) with actual data processing/analytical queries.
2. **Volume Mappings**:
   - `nyc_taxi_postgres_data` mapping guarantees that the taxi dataset in Postgres persists across container restarts.
   - `kestra_postgres_data` guarantees that orchestrator execution logs and configs are not lost.
   - `kestra_data` (mapped to `/app/storage`) provides Kestra with local file storage to store intermediate data downloaded during task executions.
3. **Docker socket mounting (`/var/run/docker.sock:/var/run/docker.sock`)**: By mounting the host's Docker socket into the Kestra container, Kestra can spin up sibling Docker containers. This enables containerized script execution (e.g., executing a python script inside a `python:slim` container).

```text
            +-------------------------------------------------------+
            |                     Host Machine                      |
            |                                                       |
            |     [Web Browser]              [/var/run/docker.sock] |
            +-----------+------------------------------+------------+
                        |                              ^
                        | (Port 8080)                  | (Mounts socket to
                        v                              |  spawn containers)
            +-----------+------------------------------+------------+
            |             Docker Compose Default Network            |
            |                                                       |
            |   +-------------+                  +---------------+  |
            |   |   kestra    +=================>|kestra_postgres|  |
            |   |(Orchestrator)                  | (Metadata DB) |  |
            |   +------+------+                  +---------------+  |
            |          |                                            |
            |          | (Loads data)                               |
            |          v                                            |
            |   +-------------+                  +---------------+  |
            |   | pgdatabase  |<-----------------+    pgadmin    |  |
            |   | (Warehouse) |   (Port 5432)    |(DB Client UI) |  |
            |   +-------------+                  +-------+-------+  |
            |                                            ^          |
            +--------------------------------------------|----------+
                                                         | (Port 8082)
                                                         |
                                                   [Web Browser]
```

---

### 2. Kestra Flow Breakdown

The pipeline definitions are located in the [kestra_flows/](./kestra_flows) folder. Here is the purpose of each flow:

#### A. Foundations & Script Execution
- **[`hello.yaml`](./kestra_flows/hello.yaml) (`01_hello_world`)**:
  - *Purpose*: Sanity check flow demonstrating inputs, variables, logging tasks (`Log`), execution pauses (`Sleep`), and sharing outputs across tasks (`{{outputs.generate_output.value}}`).
- **[`python_flow.yaml`](./kestra_flows/python_flow.yaml) (`02_python`)**:
  - *Purpose*: Illustrates running custom Python scripts in Docker containers using Kestra's Docker task runner. It utilizes the `requests` package to fetch container metrics and uses the Kestra Python SDK (`Kestra.outputs(outputs)`) to return output values to Kestra's execution context.
- **[`data_pipeline.yaml`](./kestra_flows/data_pipeline.yaml) (`03_getting_started_data_pipeline`)**:
  - *Purpose*: Demonstrates a structured multi-engine pipeline:
    1. **Extract**: Downloads raw JSON product files via HTTP (`Download` plugin).
    2. **Transform**: Runs Python inside an alpine container to filter columns.
    3. **Query**: Loads result JSON directly into an in-memory **DuckDB** instance to perform SQL analytics.

#### B. Local PostgreSQL Ingestion
- **[`postgres_taxi_data.yml`](./kestra_flows/postgres_taxi_data.yml) (`kestra_postgres_taxi_data`)**:
  - *Purpose*: Manual workflow to ingest historical NYC Green/Yellow taxi CSV data. It downloads files, parses inputs (`taxi`, `year`, `month`), copies records into staging tables, hashes properties for deduplication, and merges them into the final dataset.
- **[`taxi_data_scheduling.yaml`](./kestra_flows/taxi_data_scheduling.yaml) (`05_postgres_taxi_scheduled`)**:
  - *Purpose*: Scheduled version of the local PostgreSQL ingestion pipeline. Runs automatically every month (`0 9 1 * *` for Green, `0 10 1 * *` for Yellow) and uses `trigger.date` instead of manual inputs to process current files automatically. Uses a concurrency limit of `1` to avoid resource competition during backfills.

#### C. Google Cloud Platform (GCP) Ingestion
- **[`gcp_setting_up.yml`](./kestra_flows/gcp_setting_up.yml) (`gcp_setting_up`)**:
  - *Purpose*: A configuration flow that sets up variables (project ID, location, bucket name, dataset) and uploads Google Service Account JSON keys to Kestra's secure internal Key-Value (KV) store, avoiding plain-text credentials in code.
- **[`bigquery_loading.yml`](./kestra_flows/bigquery_loading.yml) (`08_gcp_taxi`)**:
  - *Purpose*: Manually triggered pipeline to load data into Google Cloud. Downloads taxi CSV files, uploads them to Google Cloud Storage (GCS), creates a BigQuery external table mapping, and builds partitioned destination tables in BigQuery.
- **[`bigquery_gcp_loading.yml`](./kestra_flows/bigquery_gcp_loading.yml) (`bigquery_gcp_taxi_scheduled`)**:
  - *Purpose*: Scheduled pipeline that automates the monthly ingestion into Google Cloud (GCS + BigQuery) using Kestra KV-stored service credentials.

---

### 3. Core Data Engineering Practices Implemented

#### A. Idempotency via Staging Tables and Merges
To ensure that re-running a pipeline does not corrupt or duplicate data (making it idempotent), we implemented a **Staging and Merge pattern** in both PostgreSQL and BigQuery:

1. **Extract**: Download raw `.csv.gz` from GitHub releases and gunzip it.
2. **Bulk Load**: Bulk copy the CSV into a temporary staging table (e.g. `yellow_tripdata_staging`) using the fast `CopyIn` / GCS External Table configuration.
3. **Deterministic ID Hashing**:
   Since the raw dataset does not include a unique primary key, we create a composite hash ID (`unique_row_id`) by applying the `MD5` hashing function to the combination of key transaction columns:
   ```sql
   UPDATE staging_table
   SET unique_row_id = md5(
     COALESCE(CAST(VendorID AS text), '') ||
     COALESCE(CAST(tpep_pickup_datetime AS text), '') || 
     COALESCE(CAST(tpep_dropoff_datetime AS text), '') || 
     COALESCE(PULocationID, '') || 
     COALESCE(DOLocationID, '') || 
     COALESCE(CAST(fare_amount AS text), '') || 
     COALESCE(CAST(trip_distance AS text), '')
   );
   ```
4. **Idempotent Merge**:
   We merge the staging data into our production tables. If a row with a matching `unique_row_id` already exists, it is ignored, preventing duplicated reports:
   ```sql
   MERGE INTO public.yellow_tripdata AS T
   USING public.yellow_tripdata_staging AS S
   ON T.unique_row_id = S.unique_row_id
   WHEN NOT MATCHED THEN
     INSERT (unique_row_id, filename, VendorID, ...)
     VALUES (S.unique_row_id, S.filename, S.VendorID, ...);
   ```

```text
 +-------------+         +-----------+         +---------------+
 |   GitHub    | Extract |  Raw CSV  | CopyIn  | Staging Table |
 |   Release   +========>|   File    +========>| (Temp Schema) |
 |  (.csv.gz)  |         +-----------+         +-------+-------+
 +-------------+                                       |
                                                       | Generate MD5
                                                       v unique_row_id
 +-------------+         +-----------+         +-------+-------+
 |   Target    |  Merge  | Production|         |   Enriched    |
 |  Database   |<========+   Table   |<========+ Staging Table |
 | (Warehouse) | (No Dups| (Filtered)|  Merge  | (With hashes) |
 +-------------+  inserts)           |         +---------------+
```

#### B. Scheduled Triggers and Historical Backfills
In automated pipelines, we use **Schedule Triggers** (`io.kestra.plugin.core.trigger.Schedule`). 
- Instead of using manually input dates, the pipeline dynamically extracts the year and month using:
  - `{{trigger.date | date('yyyy-MM')}}`
- When initiating a **Backfill** in the Kestra UI, the system runs this trigger retroactively for every month in the specified historical window, creating execution states, downloading the files, and performing idempotent merges without manual intervention.

#### C. BigQuery Partitioning
In the BigQuery pipelines, our destination tables are set up with partitioning:
```sql
CREATE TABLE IF NOT EXISTS `yellow_tripdata` (
    unique_row_id BYTES,
    filename STRING,
    ...
)
PARTITION BY DATE(tpep_pickup_datetime);
```
Partitioning by the pickup datetime ensures that queries filtering taxi runs on specific dates scan only the relevant shards of data, optimizing query speed and minimizing Google Cloud compute costs.
