#! /bin/bash
# You will need to install GNU Parallel to use this script!
# My CPU has 16 cores, and I hear n+1 is the sweet spot

rm -r ./output/bigearthnetcog
mkdir ./output/bigearthnetcog

function create_rgb_composite() {    
    gdalbuildvrt -separate ./data/BigEarthNet/BigEarthNet-v1.0/$1/stack.vrt \
        ./data/BigEarthNet/BigEarthNet-v1.0/$1/${1}_B04.tif \
        ./data/BigEarthNet/BigEarthNet-v1.0/$1/${1}_B03.tif \
        ./data/BigEarthNet/BigEarthNet-v1.0/$1/${1}_B02.tif

    gdal_translate -of COG \
        ./data/BigEarthNet/BigEarthNet-v1.0/$1/stack.vrt \
        ./output/bigearthnetcog/${1}.tif

    gdalwarp -t_srs EPSG:4326 \
        "./output/bigearthnetcog/${1}.tif" \
        "./output/bigearthnetcog/${1}_RGB.tif"
}
export -f create_rgb_composite

while IFS="," read -r s2name s1name
do
    parallel -j 17 create_rgb_composite ::: $s2name
done < <(cut -d "," -f1 ./data/BigEarthNet/bigearthnet-test.csv)