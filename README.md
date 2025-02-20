## MaterialX USD Utilities

Repository of utilities related to MaterialX and USD.

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

## Tests

An initial test is to run MaterialX to USD conversion against the MaterialX render test suite files. Results are show below:

### GLSL vs GLSLFX
<iframe width="100%" height="500px" src="./tests/glsl_vs_glslfx.html"></iframe>
<p>

### GLSL vs OSL vs GLSLFX
<iframe width="100%" height="500px" src="./tests/glsl_vs_osl_glslfx.html"></iframe>

