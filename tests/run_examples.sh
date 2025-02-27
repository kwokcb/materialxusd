echo Convert sample MaterialX files to USD and render
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn ./examples/no_materials.mtlx 
python ../source/materialxusd/mtlx2usd.py -pp -v -f -sf -mn -r -m ./examples/standard_surface_carpaint.sphere.mtlx 
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn -r -m ./examples/standard_surface_marble_solid.mtlx 
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn -r -m ./examples/linepattern.mtlx 
echo Preprocess and convert sample MaterialX files to USD
materialxusd pmtlx ./examples/linepattern_orig.mtlx
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn -r -m ./examples/linepattern_orig_converted.mtlx
echo Convert ZIP file 
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn -r -m ./examples/TH_Cathedral_Floor_Tiles_1k_8b_JRHrQHt.zip
echo Handle documents without materials
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn -m ./examples/starfield.mtlx -r 

