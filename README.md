## MaterialX USD Utilities

This is a Github <a href="https://github.com/kwokcb/materialxusd">repository</a> of utilities related to MaterialX and USD.

This can be hooked into the larger interoperability picture with glTF / MaterialX and USD as shown in the example below:

<img src="./documents/results/usd_gltf_mtlx_desk_web.png" width=100%>

> Figure: MaterialX material from <a href="https://matlib.gpuopen.com/main/materials/all?search=TH%20Cath&material=6e933741-eeb3-4956-b756-0b44f08aa6cf"> AMD GPUOpen library</a>. Converted to USD and displayed in `usdview` (top left), converted to glTF and display in ThreeJS editor (top right). Display in MaterialX Viewer (bottom left), and Web editor (bottom right)

Some initial utilities are provided with more coming on-line as the site / requirements progress.

### Available Components

- `mtlx2usd.py` : Utility which takes a MaterialX document and creates a corresponding USD document with scene geometry, lights, and camera. 

  The main intent is currently to be able to consume documents from the MaterialX render test suite but any MaterialX file can be used as input.

  Options Include:
  - Preprocess the MaterialX file to
  attempt to produce valid USD shading network (See Support Utilities)
  - Input geometry (USD file)
  - Input camera (USD file)
  - Skydome like (A latlong HDR file)
  - Perform USD validation
  - Export just the materials to a USD file.
  - Render the corresponding USD file. This uses `usdrecord` currently.
  - Misc options for output for test
    suite compatibility:
    - Use material name for file name
    - Create in subfolder with name being the input MaterialX name

- Preprocessing Utilities:
  - `preprocess_mtlx.py` : Tries to preprocess a MaterialX document so that it considered valid by USD. Currently this includes logic to:
    - Encapsulate **top level nodes** in a MaterialX document into a nodegraph but preserve connections. Only
    materials and shading model nodes are valid at the top level in USD. 
    - Resolve any **implicit geometry stream bindings** on `inputs` and make them explicit by adding geometric stream nodes and binding them to any inputs with implicit bindings. Note that this requires loading in the standard library to get node definitions.
    - Add a **material node per surface shader** which is not connected to any downstream material. USD only examines materials and not shaders so these shaders are skipped during conversion. 
    - Extract out any surface shaders inside a nodegraph to be outside the graph as this is considered invalid by USD.
    - If a surface shader input is connected to a nodegraph, add in an **explicit `output` qualifier**. Seems `out` is assumed to be the name of the output when there is no explicit qualifier which can be incorrect.
    - **"Flatten" (resolve) all image asset references** using the existing MaterialX utilities for path resolve. This is needed as the MaterialX  render tests have assumed search paths which are not explicitly defined -- thus requiring the paths to be passed in as part of preprocessing.
      - There is probably a better way to do this using USD asset resolvers, but have not tried. ( Input is welcome on this. )
    - Remove any `value` attributes on `input`s with connections to avoid ambiguity and MaterialX validation errors.

- Notes:
  - Color space and Real World Units:
    - Color space meta-data appears to work properly as do explicit color space conversion nodes.   
    - **Real world unit meta-data is lost during conversion**. Unknown if this is unsupportable or a known issue.
  - There appears to be no way to convert shading graphs which have a roots surface shaders which are not the current
  shading models: glTF, USDPreviewSurface, OpenPBR ? That is arbitrary PBR shaders. They may translate but are considered invalid root nodes. **It is unclear / undocumented as to what are "valid" root pbr nodes for USD.**
  -  **Nodes graphs with child nodes that are the same name as the parent graph**, and which are connected will be interpreted improperly by USD as it attempts to connect the incorrect upstream path and returns an error on conversion from MaterialX to USD. These tests have been manually modified for nowt to rename the interior node. This appears to be a USD logic error.
  - **Validation is inconsistent between USD and MaterialX for upstream output connections**. If the upstream node / nodegraph has 1 connection then a validation warning is issues if you explicit specify that output. If you do not
  specify the output then conversion to USD will skip this link. *It would be useful to remove this inconsistent  validation check in MaterialX.*
  - For rendering HDStorm and the default (GLSL/ OSL / MDL) MaterialX renderers use different sampling logic for environment lighting. e.g. Anisotropy differs.
  - For render results: The rendering setup for translucent / transparent shading does not show the environment when it is set to be hidden. There is probably a way to make this show up while hiding the background. **Input is welcome on this**.

## Usage

### Installation and Usage

Install from the root folder:

```
pip install .
```

Run using the `materialxusd` command.
Currently there are two commands for:
- MaterialX to USD conversion which can be run using

```
materialxusd m2u
```
and preprocessing MaterialX documents which can be run using

```
materialxusd pmtlx
```

The `tests` folder has a script with some command line calls to process an examples subfolder (`run_examples.sh`) 

```
echo Convert sample MaterialX files to USD and render
materialxusd m2u -pp -v -sf -mn ./examples/no_materials.mtlx 
materialxusd m2u -pp -v -f -sf -mn -r -m ./examples/standard_surface_carpaint.sphere.mtlx 
materialxusd m2u -pp -v -sf -mn -r -m ./examples/standard_surface_marble_solid.mtlx 
materialxusd m2u -pp -v -sf -mn -r -m ./examples/linepattern.mtlx 
echo Preprocess and convert sample MaterialX files to USD
materialxusd pmtlx ./examples/linepattern_orig.mtlx
materialxusd m2u -pp -v -sf -mn -r -m ./examples/linepattern_orig_converted.mtlx
echo Convert ZIP file 
materialxusd m2u -pp -v -sf -mn -r -m ./examples/TH_Cathedral_Floor_Tiles_1k_8b_JRHrQHt.zip
```

Some rendering of resulting USD files are shown below:

| | | | |
| :--: | :--: | :--: | :--: | 
| <img src="https://raw.githubusercontent.com/kwokcb/materialxusd/refs/heads/main/tests/examples/linepattern/test_crosshatch_glslfx.png" width="100%">Line Pattern</img> | <img src="https://raw.githubusercontent.com/kwokcb/materialxusd/refs/heads/main/tests/examples/standard_surface_marble_solid/Marble_3D_glslfx.png" width="100%">Marble</img> | <img width="100%" src="https://raw.githubusercontent.com/kwokcb/materialxusd/refs/heads/main/tests/examples/standard_surface_carpaint.sphere/Car_Paint_glslfx.png">Car Paint</img> | <img width="100%" src="https://raw.githubusercontent.com/kwokcb/materialxusd/refs/heads/main/tests/examples/TH_Cathedral_Floor_Tiles_1k_8b_JRHrQHt/TH_Cathedral_Floor_Tiles/TH_Cathedral_Floor_Tiles_glslfx.png"/>Wood (Zip) |


There is additionally a sample script that will traverse a local copy of the MaterialX test suite (`render_rts.sh`). The script calls the package's Python commands directly.

```bash
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
    python ../source/materialxusd/mtlx2usd.py -pp -mn -sf "$folder" -r -g ./data/sphere.usd -c ./data/camera_sphere.usda -e ./data/san_giuseppe_bridge.hdr
done
```

### Documentation

Python API documentation can be found <a href="https://kwokcb.github.io/materialxusd/documents/html/index.html">here</a>
## Acceptance

An initial acceptance criteria is to be able to run MaterialX to USD conversion against the MaterialX render test suite files. Preliminary results are show below:

### Gallery of Example Materials

glTF, Standard Surface, OpenUSD material renderings

<iframe width="100%" height="500px" src="./tests/usd_mtlx_image_gallery.html"></iframe>
<p></p>

### Comparison: GLSL vs GLSLFX

<iframe width="100%" height="500px" src="./tests/glsl_vs_glslfx.html"></iframe>
<p></p>

### Comparison: GLSL vs OSL vs GLSLFX

<iframe width="100%" height="500px" src="./tests/glsl_vs_osl_glslfx.html"></iframe>

## Design

An overview of the current package design is shown below. Boxes / lines which are dotted are optional logic which may be executed as desired.

<img src="./documents/images/design.png" width=100%>