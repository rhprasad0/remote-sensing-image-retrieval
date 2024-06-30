#! /bin/bash
# Run this before inserting embeddings

while IFS="," read -r s2name
do

    ogr2ogr -append \
    /home/ryan/remote-sensing-image-retrieval/output/bigearthnetrgb/BEN_geoms.gpkg \
    ./output/bigearthnetrgb/vector/$s2name.geojson

done < <(cut -d "," -f 1 ./data/BigEarthNet/bigearthnet-test.csv)