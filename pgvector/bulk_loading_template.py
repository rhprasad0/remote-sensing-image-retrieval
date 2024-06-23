from pgvector.psycopg import register_vector
import psycopg
import torch

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
conn.execute('CREATE EXTENSION IF NOT EXISTS vector')
register_vector(conn)

# create table
conn.execute('DROP TABLE IF EXISTS test')
conn.execute(f'CREATE TABLE test (id bigserial, embedding vector({dimensions}))')

# load data
vectors = torch.load("/home/ryan/remote-sensing-image-retrieval/output/embeddings/PrithviViT/ForestNet/val/embeddings.pt").numpy()[:, :32]

print(f'Loading {len(vectors)} rows')
cur = conn.cursor()
with cur.copy('COPY test (embedding) FROM STDIN WITH (FORMAT BINARY)') as copy:
    copy.set_types(['vector'])

    for i, embedding in enumerate(vectors):
        # show progress
        if i % 10000 == 0:
            print('.', end='', flush=True)

        copy.write_row([embedding])

        # flush data
        while conn.pgconn.flush() == 1:
            pass

print('\nSuccess!')
