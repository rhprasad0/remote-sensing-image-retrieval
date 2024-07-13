#!/bin/bash

TIF_PATH=/home/ryan/remote-sensing-image-retrieval/output/tiff
PNG_PATH=/home/ryan/remote-sensing-image-retrieval/output/png
CFG_PATH=/home/ryan/remote-sensing-image-retrieval/configs/prithvi_vit.yaml
INFERENCE_SCRIPT_PATH=/home/ryan/remote-sensing-image-retrieval/inference_tampanet.py
LOCAL_METADATA_PATH=/home/ryan/remote-sensing-image-retrieval/data/metadata.xml

# Grab S2 scene name from AWS. SQS_URL is set in .env file (not in repo)
scene_name=$(aws sqs receive-message --queue-url $SQS_URL | jq -r '.Messages[0].Body' | jq -r '.Message' | jq -r '.name')
echo "Grabbed S2 scene name from queue"
echo "Scene name: ${scene_name}"

# Grab the scene metadata
scene_path_raw=$(aws sqs receive-message --queue-url $SQS_URL | jq -r '.Messages[0].Body' | jq -r '.Message' | jq -r .tiles[0].datastrip.path)
trimmed_path=${scene_path_raw%/*/*}
metadata_path="s3://sentinel-s2-l1c/${trimmed_path}/metadata.xml"
aws s3 cp --request-payer requester $metadata_path $LOCAL_METADATA_PATH

# Parse out the cloud coverage metric
cloud_coverage_decimal=$(xmllint --xpath '//Cloud_Coverage_Assessment/text()' $LOCAL_METADATA_PATH)
snow_coverage_decimal=$(xmllint --xpath '//Snow_Coverage_Assessment/text()' $LOCAL_METADATA_PATH)
cloud_coverage_integer=$(echo "$cloud_coverage_decimal / 1" | bc)
snow_coverage_integer=$(echo "$snow_coverage_decimal / 1" | bc)
echo "Cloud Coverage: ${cloud_coverage_integer}"
echo "Snow Coverage: ${snow_coverage_integer}"

rm $LOCAL_METADATA_PATH
receipt_handle=$(aws sqs receive-message --queue-url $SQS_URL | jq -r '.Messages[0].ReceiptHandle')
aws sqs delete-message --queue-url $SQS_URL --receipt-handle $receipt_handle
echo "Removed scene from queue"

if [[ $cloud_coverage_integer -gt 20 ]] || [[ $snow_coverage_integer -gt 20 ]]; then
    echo "Scene too cloudy or snowy"
else
    echo "Scene not too cloudy or snowy"
fi

# tile=${scene_name: -22}

# aws s3 cp --request-payer requester s3://sentinel-s2-l1c-zips/$scene_name.zip ./data/$scene_name.zip
# echo "Downloaded S2 zip"

# cd ./data
# unzip ./$scene_name.zip
# rm ./$scene_name.zip
# echo "Unzipped scene"

# cd ./$scene_name.SAFE/GRANULE/L1C_*/IMG_DATA

# # Old stuff must be nuked prior to inference
# rm -r $PNG_PATH
# rm -r $TIF_PATH
# mkdir -p $PNG_PATH
# mkdir -p $TIF_PATH
# echo "Removed outputs from previous run"

# echo "Splitting scene into tiles..."
# for row in {1..10}; do
#     for col in {1..10}; do       
#         mkdir -p $TIF_PATH/${tile}_${row}_${col}
        
#         # 10m bands
#         row_offset=$(($row * 120))
#         col_offset=$(($col * 120))

#         gdal_translate -srcwin $row_offset $col_offset 120 120 \
#             ./*_B02.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B02.tif

#             # Check to see if there is data. If not, skip this tile. 
#             if [ $(gdalinfo -stats -json $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B02.tif | jq -r .bands[0].minimum) = 0 ]; then
#                 rm -r $TIF_PATH/${tile}_${row}_${col}
#                 echo "*** SKIPPED NODATA TILE ***"
#                 continue
#             fi

#         gdal_translate -srcwin $row_offset $col_offset 120 120 \
#             ./*_B03.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B03.tif

#         gdal_translate -srcwin $row_offset $col_offset 120 120 \
#             ./*_B04.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B04.tif

#         gdal_translate -srcwin $row_offset $col_offset 120 120 \
#             ./*_B08.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B08.tif

#         # 20m bands
#         row_offset=$(($row * 60))
#         col_offset=$(($col * 60))

#         gdal_translate -srcwin $row_offset $col_offset 60 60 \
#             ./*_B05.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B05.tif        

#         gdal_translate -srcwin $row_offset $col_offset 60 60 \
#             ./*_B06.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B06.tif         

#         gdal_translate -srcwin $row_offset $col_offset 60 60 \
#             ./*_B07.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B07.tif        

#         gdal_translate -srcwin $row_offset $col_offset 60 60 \
#             ./*_B8A.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B8A.tif    

#         gdal_translate -srcwin $row_offset $col_offset 60 60 \
#             ./*_B11.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B11.tif        

#         gdal_translate -srcwin $row_offset $col_offset 60 60 \
#             ./*_B12.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B12.tif

#         # 60m bands
#         row_offset=$(($row * 20))
#         col_offset=$(($col * 20))

#         gdal_translate -srcwin $row_offset $col_offset 20 20 \
#             ./*_B01.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B01.tif        

#         gdal_translate -srcwin $row_offset $col_offset 20 20 \
#             ./*_B09.jp2 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B09.tif

#         # Create png
#         gdal_merge.py -separate $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B04.tif \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B03.tif \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B02.tif \
#             -o $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_rgb.tif

#         gdal_translate -of PNG \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_rgb.tif \
#             $PNG_PATH/${tile}_${row}_${col}.png

#         rm $PNG_PATH/${tile}_${row}_${col}.png.aux.xml

#         # Get extent    
#         gdal_footprint -t_srs EPSG:4326 \
#             $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B01.tif \
#             $PNG_PATH/${tile}_${row}_${col}.geojson

#     done
# done
# echo "Finished tiling scene"
# echo

# echo "Generating statistics for normalization"
# echo
# B02_mean=$(gdalinfo -stats -json ./*_B02.jp2 | jq -r .bands[0].mean)
# B02_std=$(gdalinfo -stats -json ./*_B02.jp2 | jq -r .bands[0].stdDev)
# B03_mean=$(gdalinfo -stats -json ./*_B03.jp2 | jq -r .bands[0].mean)
# B03_std=$(gdalinfo -stats -json ./*_B03.jp2 | jq -r .bands[0].stdDev)
# B04_mean=$(gdalinfo -stats -json ./*_B04.jp2 | jq -r .bands[0].mean)
# B04_std=$(gdalinfo -stats -json ./*_B04.jp2 | jq -r .bands[0].stdDev)
# B8A_mean=$(gdalinfo -stats -json ./*_B8A.jp2 | jq -r .bands[0].mean)
# B8A_std=$(gdalinfo -stats -json ./*_B8A.jp2 | jq -r .bands[0].stdDev)
# B11_mean=$(gdalinfo -stats -json ./*_B11.jp2 | jq -r .bands[0].mean)
# B11_std=$(gdalinfo -stats -json ./*_B11.jp2 | jq -r .bands[0].stdDev)
# B12_mean=$(gdalinfo -stats -json ./*_B12.jp2 | jq -r .bands[0].mean)
# B12_std=$(gdalinfo -stats -json ./*_B12.jp2 | jq -r .bands[0].stdDev)

# echo "Means:"
# echo $B02_mean
# echo $B03_mean
# echo $B04_mean
# echo $B8A_mean
# echo $B11_mean
# echo $B12_mean
# echo
# echo "Standard Devations:"
# echo $B02_std
# echo $B03_std
# echo $B04_std
# echo $B8A_std
# echo $B11_std
# echo $B12_std

# echo
# echo "Finished generating statistics for normalization"

# # Insert means into config file
# sed -i "13s/.*/    - $B02_mean/" $CFG_PATH
# sed -i "14s/.*/    - $B03_mean/" $CFG_PATH
# sed -i "15s/.*/    - $B04_mean/" $CFG_PATH
# sed -i "16s/.*/    - $B8A_mean/" $CFG_PATH
# sed -i "17s/.*/    - $B11_mean/" $CFG_PATH
# sed -i "18s/.*/    - $B12_mean/" $CFG_PATH

# # Insert standard deviations into config file
# sed -i "20s/.*/    - $B02_std/" $CFG_PATH
# sed -i "21s/.*/    - $B03_std/" $CFG_PATH
# sed -i "22s/.*/    - $B04_std/" $CFG_PATH
# sed -i "23s/.*/    - $B8A_std/" $CFG_PATH
# sed -i "24s/.*/    - $B11_std/" $CFG_PATH
# sed -i "25s/.*/    - $B12_std/" $CFG_PATH
# echo
# echo "Updated config file with statistics"
# echo

# # Check to see if there is data. If not, do not run inference
# if [ $(ls $TIF_PATH | wc -l) = 0 ]; 
#     then
#         echo "*** NO DATA: SKIPPING INFERENCE ***"
#     else
#         # Gimme embeddings plz >8-D
#         echo "Generating embeddings"
#         python $INFERENCE_SCRIPT_PATH -c $CFG_PATH
#         echo "Finished generating embeddings"
# fi

# echo
# echo "*** SCENE PROCESSING COMPLETE ***"

# cd ~/remote-sensing-image-retrieval
# rm -r ./data/$scene_name.SAFE