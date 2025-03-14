#!/bin/bash

folders=(
    "./resources/Materials/Examples"
    "./resources/Materials/TestSuite/stdlib/convolution"
    "./resources/Materials/TestSuite/stdlib/color_management"
    "./resources/Materials/TestSuite/stdlib/procedural"
    "./resources/Materials/TestSuite/pbrlib/surfaceshader"
    "./resources/Materials/TestSuite/nprlib"
)

for folder in "${folders[@]}"; do
    echo "Rendering $folder"
    python ../source/materialxusd/mtlx2usd.py -pp -mn -sf "$folder" $* -g ./data/sphere.usd -c ./data/camera_sphere.usda -e ./data/san_giuseppe_bridge.hdr > render_rts_log.txt 2>&1
done


