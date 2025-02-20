from pxr import Usd, UsdGeom, Gf, Sdf

# Create a new USD stage
stage = Usd.Stage.CreateNew("camera_stage.usda")

# Define the camera path
camera_path = Sdf.Path("/World/Camera")

# Create a camera at the specified path
camera = UsdGeom.Camera.Define(stage, camera_path)

# Set the camera position
camera.AddTranslateOp().Set(Gf.Vec3f(0, 0, 3))

# Set the camera direction (rotation)
camera.AddRotateXYZOp().Set(Gf.Vec3f(0, 0, 0))  # No rotation needed as direction is already along -Z

# Set the field of view
camera.GetFocalLengthAttr().Set(79.334)

# Set the horizontal aperture to ensure a square frustum
camera.GetHorizontalApertureAttr().Set(20.0)  # Adjust as needed
camera.GetVerticalApertureAttr().Set(20.0)  # Adjust as needed

# Set the clipping range (near and far)
camera.GetClippingRangeAttr().Set(Gf.Vec2f(0.1, 1000.0))

# Save the USD stage
stage.GetRootLayer().Save()

print("Camera added to USD stage and saved as 'camera_stage.usd'.")
