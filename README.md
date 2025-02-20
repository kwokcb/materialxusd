## MaterialX USD Utilities

This is a Github <a href="https://github.com/kwokcb/materialxusd">repository</a> of utilities related to MaterialX and USD.

This can be hooked into the larger interoperability picture with glTF / MaterialX and USD as shown in the example below:

<img src="./documents/results/usd_gltf_mtlx_desk_web.png">
<sub>Figure: MaterialX material downloaded from AMD GPU library. Converted to USD and displayed in `usdview` (top left), converted to glTF and display in ThreeJS editor (top right). Display in MaterialX Viewer (bottom left), and Web editor (bottom right)</sub>

Some initial utilities are provided with more coming on-line as the site / requirements progress.

### Available Components

- `mtlxusd.py` : Utility which takes a MaterialX document and creates a corresponding USD document with scene geometry, lights, and camera. 

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

- Support Utilities:
  - Utility to encapsulate top level nodes in a MaterialX document into a nodegraph. Connections are preserved.

## Usage

### Installation and Usage

Install from the root folder:
```
pip install .
```

Run using the `materialxusd` command.
Currently there is only one command from MaterialX to USD conversion which can be run using
```
materialxusd m2u
```
The tests folder has a script with some command line calls to build examples (`run_examples.sh`) 

```
materialxusd m2u -pp -v -f -sf -mn -r -m ./examples/standard_surface_carpaint.sphere.mtlx
materialxusd m2u -pp -v -sf -mn -r -m ./examples/standard_surface_marble_solid.mtlx
materialxusd m2u -pp -v -sf -mn -r -m ./examples/linepattern.mtlx

```

Some of the example rendering of resulting USD files is shown below:
| | | |
| :--: | :--: | :--: |
| <img src="https://raw.githubusercontent.com/kwokcb/materialxusd/refs/heads/main/tests/examples/linepattern/test_crosshatch_glslfx.png?token=GHSAT0AAAAAAC2DA34K7BXSZCU33SWDQN5UZ5XUXPA">Line Pattern</img> | <img src="https://raw.githubusercontent.com/kwokcb/materialxusd/refs/heads/main/tests/examples/standard_surface_marble_solid/Marble_3D_glslfx.png?token=GHSAT0AAAAAAC2DA34KJJZPZLDRUYARA74EZ5XUY7A">Marble</img> | <img src="https://raw.githubusercontent.com/kwokcb/materialxusd/refs/heads/main/tests/examples/standard_surface_carpaint/Car_Paint_glslfx.png?token=GHSAT0AAAAAAC2DA34KPPHYBV6S5ZC4XPNYZ5XU57Q">Car Paint</img> |


and also to run against a snapshot of the MaterialX test suite  (`render_rts.sh`). The latter
runs the commands without the need to install.

```sh
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

## Tests

An initial test is to run MaterialX to USD conversion against the MaterialX render test suite files. Results are show below:

### GLSL vs GLSLFX
<iframe width="100%" height="500px" src="./tests/glsl_vs_glslfx.html"></iframe>
<p>

### GLSL vs OSL vs GLSLFX
<iframe width="100%" height="500px" src="./tests/glsl_vs_osl_glslfx.html"></iframe>

