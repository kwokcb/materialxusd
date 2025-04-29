#!/bin/bash

folders=(
    "./resources_1_39_3/Materials/Examples"
    "./resources_1_39_3/Materials/TestSuite/stdlib/convolution"
    "./resources_1_39_3/Materials/TestSuite/stdlib/color_management"
    "./resources_1_39_3/Materials/TestSuite/stdlib/procedural"
    "./resources_1_39_3/Materials/TestSuite/pbrlib/surfaceshader"
    "./resources_1_39_3/Materials/TestSuite/nprlib"
)

for folder in "${folders[@]}"; do
    echo "Rendering $folder"
    python ../source/materialxusd/mtlx2usd.py -pp -mn -sf "$folder" $* -g ./data/sphere.usd -c ./data/camera_sphere.usda -e ./data/san_giuseppe_bridge.hdr > render_rts_log.txt 2>&1
done


