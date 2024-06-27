#! /bin/bash
# Run this before inserting embeddings

table_name=
host=
username=
port=
dbname=
password=

psql --host=$host \
    --port=$port \
    --username=$username \
    --command="DROP TABLE IF EXISTS $table_name; CREATE TABLE $table_name ( id bigserial, embedding vector(32), url text, geom geometry(MultiPolygon, 4326) );"

i=0
while IFS="," read -r s2name
do

    ogr2ogr -lco GEOMETRY_NAME=geom -lco GEOM_TYPE=geometry -append \
    PG:"postgresql://$username:$password@$host/$dbname" \
    ./output/bigearthnetrgb/vector/$s2name.geojson \
    -nln $table_name 

    # password is located in home directory hidden file
    psql --host=$host \
        --port=$port \
        --username=$username \
        --command="UPDATE public.$table_name SET url ='https://ryans-website-thing-public.s3.us-west-2.amazonaws.com/bigearthnet/${s2name}_RGB.tif WHERE id=$id';"

    # this is sequential, can't do this in parallel
    ((i++))

done < <(cut -d "," -f 1 ./data/BigEarthNet/bigearthnet-test.csv)