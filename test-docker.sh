  
  #Running posgres using docker

  docker run -it \
    -e POSTGRES_USER="root"\
    -e POSTGRES_PASSWORD="admin"\
    -e POSTGRES_DB="nyc_taxi"\
    -v "$(pwd)/nyc_taxi_postgres_data:/var/lib/postgresql/data" \
    -p 5432:5432\
    postgres:13


#With network
docker network create pg-network
#Network: fe4ee8d09fb5f4f26d8487196a91d897f353d8ad21c1b13ea16d96e36de6209b


  docker run -it \
    -e POSTGRES_USER="root"\
    -e POSTGRES_PASSWORD="admin"\
    -e POSTGRES_DB="nyc_taxi"\
    -v "$(pwd)/nyc_taxi_postgres_data:/var/lib/postgresql/data" \
    -p 5432:5432\
    --network=pg-network \
    --name pg-database \
    postgres:13

  #bash command to run ingest_data.py

URL="https://github.com/DataTalksClub/nyc-tlc-data/releases/download/yellow/yellow_tripdata_2021-01.csv.gz"
  python ingest_data.py \
  --user=root \
  --password=admin \
  --host=localhost \
  --port=5432 \
  --db=nyc_taxi \
  --table_name=yellow_taxi_trips \
  --url ${URL}



# 1. Connecting to standalone Postgres (started via docker run on pg-network)
URL="https://github.com/DataTalksClub/nyc-tlc-data/releases/download/yellow/yellow_tripdata_2021-01.csv.gz"

docker run -it \
  --network=pg-network \
  taxi_ingest:v001 \
  --user=root \
  --password=admin \
  --host=pg-database \
  --port=5432 \
  --db=nyc_taxi \
  --table_name=yellow_taxi_trips \
  --url=${URL}


# 2. Connecting to Docker Compose Postgres (running on docker_sql_default network)
URL="https://github.com/DataTalksClub/nyc-tlc-data/releases/download/yellow/yellow_tripdata_2021-01.csv.gz"

docker run -it \
  --network=docker_sql_default \
  taxi_ingest:v001 \
  --user=root \
  --password=admin \
  --host=pgdatabase \
  --port=5432 \
  --db=nyc_taxi \
  --table_name=yellow_taxi_trips \
  --url=${URL}

# 3. Taxi Zones Ingestion

URL="https://github.com/DataTalksClub/nyc-tlc-data/releases/download/misc/taxi_zone_lookup.csv"

docker run -it \
  --network=docker_sql_default \
  taxi_ingest:v001 \
  --user=root \
  --password=admin \
  --host=pgdatabase \
  --port=5432 \
  --db=nyc_taxi \
  --table_name=zones \
  --url=${URL}