import os
import pandas as pd
from time import time
import argparse

from sqlalchemy import create_engine


def main(params):
    
    user = params.user
    password = params.password
    host = params.host
    port = params.port
    db = params.db
    table_name = params.table_name
    url = params.url

    csv_name = url.split("/")[-1]

    os.system(f"wget {url} -O {csv_name}")

    compression = "gzip" if csv_name.endswith(".gz") else None

    engine = create_engine(f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{db}")

    df_iter = pd.read_csv(csv_name, compression=compression, iterator=True, chunksize=100000)

    df = next(df_iter)

    if "tpep_dropoff_datetime" in df.columns:
        df["tpep_dropoff_datetime"] = pd.to_datetime(df["tpep_dropoff_datetime"])
    if "tpep_pickup_datetime" in df.columns:
        df["tpep_pickup_datetime"] = pd.to_datetime(df["tpep_pickup_datetime"])

    df.head(0).to_sql(name=table_name, con=engine, if_exists='replace')

    df.to_sql(name=table_name, con=engine, if_exists='append')

    while True:
        try:
            t_start = time()
            df = next(df_iter)

            if "tpep_dropoff_datetime" in df.columns:
                df["tpep_dropoff_datetime"] = pd.to_datetime(df["tpep_dropoff_datetime"])
            if "tpep_pickup_datetime" in df.columns:
                df["tpep_pickup_datetime"] = pd.to_datetime(df["tpep_pickup_datetime"])

            df.to_sql(name=table_name, con=engine, if_exists='append')
            t_end = time()
            print(f"Inserted another chunk..., took {t_end - t_start:.3f} seconds")

        except StopIteration:
            print("Finished ingesting data into the postgres database")
            break


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest CSV data to Postgres")

    parser.add_argument('--user', help='user name for postgres')
    parser.add_argument('--password', help='password for postgres')
    parser.add_argument('--host', help='host for postgres')
    parser.add_argument('--port', help='port for postgres')
    parser.add_argument('--db', help='database name for postgres')
    parser.add_argument('--table_name', help='table name where we will write the data')
    parser.add_argument('--url', help='csv file url to be ingested')

    args = parser.parse_args()
    main(args)
