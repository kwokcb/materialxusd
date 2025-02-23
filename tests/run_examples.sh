echo Convert sample MaterialX files to USD and render
materialxusd m2u -pp -v -sf -mn ./examples/no_materials.mtlx 
materialxusd m2u -pp -v -f -sf -mn -r -m ./examples/standard_surface_carpaint.sphere.mtlx 
materialxusd m2u -pp -v -sf -mn -r -m ./examples/standard_surface_marble_solid.mtlx 
materialxusd m2u -pp -v -sf -mn -r -m ./examples/linepattern.mtlx 
echo Preprocess and convert sample MaterialX files to USD
materialxusd pmtlx ./examples/linepattern_orig.mtlx
materialxusd m2u -pp -v -sf -mn -r -m ./examples/linepattern_orig_converted.mtlx 


