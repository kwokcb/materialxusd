echo Convert sample MaterialX files to USD and render
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn ./examples/no_materials.mtlx 
python ../source/materialxusd/mtlx2usd.py -pp -v -f -sf -mn $* -m ./examples/standard_surface_carpaint.sphere.mtlx 
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn $* -m ./examples/standard_surface_marble_solid.mtlx 
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn $* -m ./examples/linepattern.mtlx 

echo Preprocess and convert sample MaterialX files to USD
materialxusd pmtlx ./examples/linepattern_orig.mtlx
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn $* -m ./examples/linepattern_orig_converted.mtlx
python ../source/materialxusd/preprocess_mtlx.py ./examples/usd_preview_surface_brass_tiled.mtlx -ip "./resources/Materials/Examples/UsdPreviewSurface/"
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn -m ./examples/usd_preview_surface_brass_tiled_converted.mtlx $*

echo Convert ZIP files. Nested and unnested 
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn $* -m ./examples/TH_Cathedral_Floor_Tiles_1k_8b_JRHrQHt.zip
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn $* -m ./examples/parquet_clothes.zip

echo Handle documents without materials
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn -m ./examples/starfield.mtlx $* 
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn -m ./examples/nodegraph_surfaceshader.mtlx $*
python ../source/materialxusd/mtlx2usd.py -pp -v -sf -mn -m ./examples/no_materials.mtlx $* 

