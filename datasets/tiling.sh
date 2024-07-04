# Splits an unzipped Sentinel 2 scene into 120x120, 60x60, or 20x20 GeoTIFFs
# similar to that of the BigEarthNet format. 

input_path=/home/ryan/remote-sensing-image-retrieval/tiling_test/S2A_MSIL1C_20240323T155921_N0510_R097_T17RLL_20240323T212825.SAFE/GRANULE/L1C_T17RLL_A045711_20240323T161228/IMG_DATA
output_path=/home/ryan/remote-sensing-image-retrieval/output/img

for row in {1..90}; do
    for col in {1..90}; do       
        mkdir -p $output_path/T17RLL_20240323T155921_${row}_${col}
        
        # 10m bands
        row_offset=$(($row * 120))
        col_offset=$(($col * 120))

        gdal_translate -srcwin $row_offset $col_offset 120 120 \
        $input_path/T17RLL_20240323T155921_B02.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B02.tif

        gdal_translate -srcwin $row_offset $col_offset 120 120 \
        $input_path/T17RLL_20240323T155921_B03.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B03.tif

        gdal_translate -srcwin $row_offset $col_offset 120 120 \
        $input_path/T17RLL_20240323T155921_B04.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B04.tif

        gdal_translate -srcwin $row_offset $col_offset 120 120 \
        $input_path/T17RLL_20240323T155921_B08.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B08.tif

        # 20m bands
        row_offset=$(($row * 60))
        col_offset=$(($col * 60))

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
        $input_path/T17RLL_20240323T155921_B05.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B05.tif        

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
        $input_path/T17RLL_20240323T155921_B06.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B06.tif         

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
        $input_path/T17RLL_20240323T155921_B07.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B07.tif        

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
        $input_path/T17RLL_20240323T155921_B8A.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B8A.tif    

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
        $input_path/T17RLL_20240323T155921_B11.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B11.tif        

        gdal_translate -srcwin $row_offset $col_offset 60 60 \
        $input_path/T17RLL_20240323T155921_B12.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B12.tif

        # 60m bands
        row_offset=$(($row * 20))
        col_offset=$(($col * 20))

        gdal_translate -srcwin $row_offset $col_offset 20 20 \
        $input_path/T17RLL_20240323T155921_B01.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B01.tif        

        gdal_translate -srcwin $row_offset $col_offset 20 20 \
        $input_path/T17RLL_20240323T155921_B09.jp2 \
        $output_path/T17RLL_20240323T155921_${row}_${col}/T17RLL_20240323T155921_${row}_${col}_B09.tif
    done
done