import sys
import os
from pxr import Usd, UsdShade, Sdf, UsdGeom
#import MaterialX
import argparse

def create_material_reference(materialx_file, usda_file, geometry, flatten=False):
    # Check if MaterialX file exists
    if not os.path.exists(materialx_file):
        print(f"Error: The MaterialX file '{materialx_file}' does not exist.")
        sys.exit(1)
    
    # Create a new USD stage (scene)
    stage = Usd.Stage.CreateInMemory()
    
    # Define a material in the USD stage (root location)
    material_path = '/World/MaterialX'
    if not flatten:
        material_path += '/Materials'
    #material_prim = UsdShade.Material.Define(stage, Sdf.Path(material_path))
    material_prim = stage.DefinePrim(Sdf.Path(material_path))
    
    # Reference the MaterialX file as the source for this material
    # Create an SdfReference object to use in AddReference()
    materialx_reference = Sdf.Reference(materialx_file, "/MaterialX")
    material_prim.GetPrim().GetReferences().AddReference(materialx_reference)

    stage.documentation = f"Stage referencing: {materialx_file}"
    temp_stage = None
    if flatten or geometry:        
        flattened_layer = stage.Flatten()
        flattened_layer.documentation = f"Flattened stage referencing: {materialx_file}"
        temp_stage = Usd.Stage.Open(flattened_layer)

    # Set up a scene with a default sphere
    scene_path = '/World/Scene'
    SPHERE_PATH = '/World/Scene/Sphere'
    if geometry:    
        scene_prim = stage.DefinePrim(Sdf.Path(scene_path), 'Xform')
        sphere = UsdGeom.Sphere.Define(stage, SPHERE_PATH)
        material_binding = UsdShade.MaterialBindingAPI.Apply(sphere.GetPrim())

        # Iterate and find the first prim of type "Material" under the root
        material = None
        for child_prim in temp_stage.Traverse():
            if child_prim.GetTypeName() == "Material":
                material = UsdShade.Material(child_prim)
                break
        if material:
            if usda_file:
                print(f'# Bind material {material.GetPath()} to {sphere.GetPath()}')
            # Bind in main stage
            #print('>>>>>>>>>>>>> BIND main sphere...', sphere)
            material_binding.Bind(material)
            # Bind in temp stage
            if temp_stage:
                scene_prim = temp_stage.DefinePrim(Sdf.Path(scene_path), 'Xform')
                sphere = UsdGeom.Sphere.Define(temp_stage, SPHERE_PATH)
                #print('>>>>>>>>>>>>> BIND temp sphere...', sphere)
                material_binding = UsdShade.MaterialBindingAPI.Apply(sphere.GetPrim())
                material_binding.Bind(material)

    if flatten:
        usd_string = temp_stage.ExportToString()
    else:
        usd_string = stage.GetRootLayer().ExportToString()

    # Save the stage as a USDA file
    if usda_file:
        # Save string to file
        with open(usda_file, 'w') as f:
            f.write(usd_string)
    else:
        print(usd_string)


def main():
    parser = argparse.ArgumentParser(description="Create a MaterialX reference in a USD file.")
    parser.add_argument("input_materialx_file", type=str, help="The MaterialX file to reference.")
    parser.add_argument("-o", "--output_usda_file", type=str, default=None, help="The output USD file to create.")
    parser.add_argument("-g", "--geometry", type=str, default="_default_sphere_", help="The geometry to apply the material to.")
    parser.add_argument("-f", "--flatten", action="store_true", help="Flatten the stage before saving.")
    args = parser.parse_args()

    materialx_file = args.input_materialx_file
    usda_file = args.output_usda_file
    flatten = args.flatten
    # TODO Add geometry reference support ....
    geometry = args.geometry
    if geometry != "_default_sphere_":
        geometry = ""
    create_material_reference(materialx_file, usda_file, geometry, flatten)

if __name__ == "__main__":
    main()
