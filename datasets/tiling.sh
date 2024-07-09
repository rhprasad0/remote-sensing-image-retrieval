#!/bin/bash

TIF_PATH=/home/ryan/remote-sensing-image-retrieval/output/tiff
PNG_PATH=/home/ryan/remote-sensing-image-retrieval/output/png

scene_name=$(aws sqs receive-message --queue-url https://sqs.us-east-1.amazonaws.com/748757098892/Sentinel2 | jq -r '.Messages[0].Body' | jq -r '.Message' | jq -r '.name')
receipt_handle=$(aws sqs receive-message --queue-url https://sqs.us-east-1.amazonaws.com/748757098892/Sentinel2 | jq -r '.Messages[0].ReceiptHandle')
aws sqs delete-message --queue-url https://sqs.us-east-1.amazonaws.com/748757098892/Sentinel2 --receipt-handle $receipt_handle
echo "Grabbed S2 scene name from queue"

tile=${scene_name: -22}

aws s3 cp --request-payer requester s3://sentinel-s2-l1c-zips/$scene_name.zip ./data/$scene_name.zip
echo "Downloaded S2 zip"

cd ./data
unzip ./$scene_name.zip
rm ./$scene_name.zip
echo "Unzipped scene"

cd ./$scene_name.SAFE/GRANULE/L1C_*/IMG_DATA

mkdir -p $PNG_PATH
mkdir -p $TIF_PATH

for row in {1..10}; do
    for col in {1..10}; do       
        mkdir -p $TIF_PATH/${tile}_${row}_${col}
        
        # 10m bands
        row_offset=$(($row * 120))
        col_offset=$(($col * 120))

        gdal_translate -srcwin $row_offset $col_offset 120 120 \
            ./*_B02.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B02.tif

        gdal_translate -srcwin $row_offset $col_offset 120 120 \
            ./*_B03.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B03.tif

        gdal_translate -srcwin $row_offset $col_offset 120 120 \
            ./*_B04.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B04.tif

        gdal_translate -srcwin $row_offset $col_offset 120 120 \
            ./*_B08.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B08.tif

        # 20m bands
        row_offset=$(($row * 60))
        col_offset=$(($col * 60))

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
            ./*_B05.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B05.tif        

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
            ./*_B06.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B06.tif         

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
            ./*_B07.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B07.tif        

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
            ./*_B8A.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B8A.tif    

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
            ./*_B11.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B11.tif        

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
            ./*_B12.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B12.tif

        # 60m bands
        row_offset=$(($row * 20))
        col_offset=$(($col * 20))

        gdal_translate -srcwin $row_offset $col_offset 20 20 \
            ./*_B01.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B01.tif        

        gdal_translate -srcwin $row_offset $col_offset 20 20 \
            ./*_B09.jp2 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B09.tif

        # Create png
        gdal_merge.py -separate $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B04.tif \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B03.tif \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B02.tif \
            -o $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_rgb.tif

        gdal_translate -of PNG \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_rgb.tif \
            $PNG_PATH/${tile}_${row}_${col}.png

        rm $PNG_PATH/${tile}_${row}_${col}.png.aux.xml

        # Get extent    
        gdal_footprint -t_srs EPSG:4326 \
            $TIF_PATH/${tile}_${row}_${col}/${tile}_${row}_${col}_B01.tif \
            $PNG_PATH/${tile}_${row}_${col}.geojson

    done
done

echo "Finished processing tile"

cd ~/remote-sensing-image-retrieval
rm -r ./data/$scene_name.SAFE