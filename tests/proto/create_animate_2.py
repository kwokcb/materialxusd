from pxr import Usd, UsdShade, Sdf, Gf, UsdGeom, UsdMtlx
import os, sys

# Create a new USD stage
stage = Usd.Stage.CreateInMemory()
UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
UsdGeom.SetStageMetersPerUnit(stage, 1.0)
stage.SetStartTimeCode(1)
stage.SetEndTimeCode(24)

# Define the root prim
world = stage.DefinePrim("/World", "Xform")
stage.SetDefaultPrim(world)

material_path = '/World/MaterialX'
material_prim = stage.DefinePrim(Sdf.Path(material_path))

# Reference the MaterialX file as an asset
materialx_file_path = "./animate.mtlx"  # Path to your MaterialX file
if not os.path.exists(materialx_file_path):
    print('MaterialX file not found:', materialx_file_path)
    sys.exit(1)
materialx_reference = Sdf.Reference(materialx_file_path, Sdf.Path("/MaterialX"))
result = material_prim.GetReferences().AddReference(materialx_reference)
if not result:
    print('Failed to add reference:', materialx_reference)
    sys.exit(1)

flattened_layer = stage.Flatten()
flattened_layer.documentation = f"Animation on referenced MaterialX"
temp_stage = Usd.Stage.Open(flattened_layer)

# Create a sphere prim with high precision for display
sphere = UsdGeom.Sphere.Define(temp_stage, "/World/Sphere")

# Apply MaterialBindingAPI to the sphere
material_binding_api = UsdShade.MaterialBindingAPI.Apply(sphere.GetPrim())

material = None
for child_prim in temp_stage.Traverse():
    #print('Scan:', child_prim.GetPath())
    if child_prim.GetTypeName() == "Material":
        material = UsdShade.Material(child_prim)

        if material:
            #print('Found material:', material.GetPath())
    
            blah = False
            base_color = material.GetInput("base_color") #, Sdf.ValueTypeNames.Color3f)
            if base_color:
                #print('Animate material base_color')
                base_color.Set((1, 0, 0), time=1)
                base_color.Set((0, 1, 0), time=12)
                base_color.Set((0, 0, 1), time=24)

            roughness = material.GetInput("diffuse_roughness") #, Sdf.ValueTypeNames.Float)
            if roughness:
                #print('Animate material diffuse_color')
                roughness.Set(0.5, time=1)
                roughness.Set(0.2, time=12)
                roughness.Set(0.8, time=24)    

            #print('************ Bind material {material.GetPath()} to {sphere.GetPath()}')
            materialx_config_api = UsdMtlx.MaterialXConfigAPI.Apply(material.GetPrim())
            material_binding_api.Bind(material)
            break

            if blah:
                # Get shader connected to material
                surface_output = material.GetOutputs()[0] 
                sources, invalidSources = surface_output.GetConnectedSources()
                print('SOURCES: ', sources, invalidSources) 
                if sources and sources[0]:
                    source = sources
                    sourcePrim = source[0].source.GetPrim()            
                    print('Connected shader:', sourcePrim.GetPath())
                    if sourcePrim:
                        print('Animate shader:', sourcePrim.GetPath())
                        shader = UsdShade.Shader(sourcePrim)

                        base_color = shader.GetInput("base_color") #, Sdf.ValueTypeNames.Color3f)
                        base_color.Set((1, 0, 0), time=1)
                        base_color.Set((0, 1, 0), time=12)
                        base_color.Set((0, 0, 1), time=24)

                        roughness = shader.GetInput("diffuse_roughness") #, Sdf.ValueTypeNames.Float)
                        roughness.Set(0.5, time=1)
                        roughness.Set(0.2, time=12)
                        roughness.Set(0.8, time=24)        
            

# Save the stage
result = temp_stage.GetRootLayer().ExportToString()
print(result)