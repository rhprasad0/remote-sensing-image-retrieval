#! /bin/bash
# You will need to install GNU Parallel to use this script!

export bigearthnet_path=./data/BigEarthNet
export output_path=./output/bigearthnetrgb

mkdir $output_path
mkdir $output_path/raster
mkdir $output_path/vector

function create_rgb_composite() {    
    gdalbuildvrt -separate $bigearthnet_path/BigEarthNet-v1.0/$1/stack.vrt \
        $bigearthnet_path/BigEarthNet-v1.0/$1/${1}_B04.tif \
        $bigearthnet_path/BigEarthNet-v1.0/$1/${1}_B03.tif \
        $bigearthnet_path/BigEarthNet-v1.0/$1/${1}_B02.tif

    gdal_translate -of COG \
        $bigearthnet_path/BigEarthNet-v1.0/$1/stack.vrt \
        $output_path/raster/${1}.tif

    gdalwarp -t_srs EPSG:4326 \
        $output_path/raster/${1}.tif \
        $output_path/raster/${1}_RGB.tif

    gdal_footprint $output_path/raster/${1}_RGB.tif $output_path/vector/${1}.geojson

    rm $output_path/raster/${1}.tif

}
export -f create_rgb_composite

while IFS="," read -r s2name 
do
    # The -j flag is the number of cores you want to use
    parallel -j 12 create_rgb_composite ::: $s2name

done < <(cut -d "," -f 1 ./data/BigEarthNet/bigearthnet-test.csv)