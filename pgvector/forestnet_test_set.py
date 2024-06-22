from pgvector.psycopg import register_vector
import psycopg
import torch
import pickle
import struct

table_name = "forestnet_testset"
embeddings_path = "/home/ryan/remote-sensing-image-retrieval/output/embeddings/PrithviViT/ForestNet/test/embeddings.pt"
latitudes_path = "/home/ryan/remote-sensing-image-retrieval/output/embeddings/PrithviViT/ForestNet/test/latitudes.pt"
longitudes_path = "/home/ryan/remote-sensing-image-retrieval/output/embeddings/PrithviViT/ForestNet/test/longitudes.pt"
urls_path = "/home/ryan/remote-sensing-image-retrieval/output/embeddings/PrithviViT/ForestNet/test/urls.pkl" # points to a pickled python list
dimensions = 32 # this is just what we get from RSIS

# enable extension
conn = psycopg.connect(
    host="",
    user="",
    password="",
    dbname="",
    port=5432,
    autocommit=True,
)
register_vector(conn)


with conn.cursor() as cursor:
    cursor.execute('CREATE EXTENSION IF NOT EXISTS vector')
    cursor.execute('CREATE EXTENSION IF NOT EXISTS postgis')
    
    # create table
    cursor.execute(f'DROP TABLE IF EXISTS {table_name}')
    cursor.execute(
        f"""
            CREATE TABLE {table_name} (
            id bigserial, 
            embedding vector(32),
            latitude real,
            longitude real,
            url text,
            geom geometry(Point, 4326)
            );
        """
    )

    # load data
    embeddings = torch.load(embeddings_path).numpy()[:, :32]
    latitudes = torch.load(latitudes_path).tolist()
    longitudes = torch.load(longitudes_path).tolist()

    with open(urls_path, "rb") as f:
        urls = pickle.load(f)

    rows = range(len(embeddings))

    print(f'Loading {len(embeddings)} rows')

    # insert into table
    for row in rows:
        cursor.execute(f"INSERT INTO {table_name} (embedding, latitude, longitude, url) VALUES (%s, %s, %s, %s);",
            (embeddings[row],
            latitudes[row],
            longitudes[row],
            urls[row])
        )

    # create geom
    cursor.execute(f"UPDATE {table_name} SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);")

print('\nSuccess!')
