#! /bin/bash
mkdir ./output/bigearthnetcog
while IFS="," read -r s2name rec2
do
    wkt=$(jq -r '.projection' ./data/BigEarthNet/BigEarthNet-v1.0/$s2name/${s2name}_labels_metadata.json)

    gdalbuildvrt -separate ./data/BigEarthNet/BigEarthNet-v1.0/$s2name/stack.vrt \
        ./data/BigEarthNet/BigEarthNet-v1.0/$s2name/${s2name}_B04.tif \
        ./data/BigEarthNet/BigEarthNet-v1.0/$s2name/${s2name}_B03.tif \
        ./data/BigEarthNet/BigEarthNet-v1.0/$s2name/${s2name}_B02.tif

    gdal_translate -of COG \
        ./data/BigEarthNet/BigEarthNet-v1.0/$s2name/stack.vrt \
        ./output/bigearthnetcog/${s2name}_COG.tif

    gdalwarp -s_srs "$wkt" -t_srs "EPSG:4326" \
        "./output/bigearthnetcog/${s2name}_COG.tif" \
        "./output/bigearthnetcog/${s2name}_COG.tif"

done < <(cut -d "," -f1 ./data/BigEarthNet/bigearthnet-test.csv)