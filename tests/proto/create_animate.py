from pxr import Usd, UsdShade, Sdf, UsdGeom, UsdMtlx

# Create a new USD stage
stage = Usd.Stage.CreateNew("animated_example.usda")
stage.SetStartTimeCode(1)
stage.SetEndTimeCode(24)


# Define the root prim
world = stage.DefinePrim("/World", "Xform")

# Set validation parameters
UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
UsdGeom.SetStageMetersPerUnit(stage, 1.0)
stage.SetDefaultPrim(world)

# Create a sphere prim
sphere = UsdGeom.Sphere.Define(stage, "/World/Sphere")

#
# Apply MaterialBindingAPI to the sphere
material_binding_api = UsdShade.MaterialBindingAPI.Apply(sphere.GetPrim())

# Define the material
material = UsdShade.Material.Define(stage, "/World/Materials/ExampleMaterial")

# Create a MaterialX surface shader
shader = UsdShade.Shader.Define(stage, "/World/Materials/ExampleMaterial/ExampleSurface")
shader.CreateIdAttr("ND_standard_surface_surfaceshader")

# Define inputs with time samples
base_color = shader.CreateInput("base_color", Sdf.ValueTypeNames.Color3f)
base_color.Set((1, 0, 0), time=1)
base_color.Set((0, 1, 0), time=12)
base_color.Set((0, 0, 1), time=24)

roughness = shader.CreateInput("roughness", Sdf.ValueTypeNames.Float)
roughness.Set(0.5, time=1)
roughness.Set(0.2, time=12)
roughness.Set(0.8, time=24)

# Connect the shader to the material's surface output
material.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(), "out")

# Bind the material to the sphere
material_binding_api.Bind(material)

# Apply MaterialXConfigAPI to the material
materialx_config_api = UsdMtlx.MaterialXConfigAPI.Apply(material.GetPrim())

# Save the stage
stage.GetRootLayer().Save()