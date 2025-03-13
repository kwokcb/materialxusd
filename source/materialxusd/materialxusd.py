import logging
try:
    from pxr import Usd, Sdf, UsdShade, UsdGeom, Gf, UsdLux, UsdUtils
except ImportError:
    self.logger.info("Error: Python module 'pxr' not found. Please ensure that the USD Python bindings are installed.")
    exit(1)

import mxusd_custom as mxcust

class MaterialxUSDConverter:
    '''
    @brief Class that converts a MaterialX file to a USD file with an appropriate scene.
    '''
    def __init__(self):
        '''
        @brief Constructor for the MaterialxUSDConverter class.
        '''
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger('MX2USD')


    def validate_stage(self, file:str, verboseOutput:bool=False):
        '''
        @brief This function validates a USD file using the ComplianceChecker.
        @param file: The path to the USD file to validate.
        @param verboseOutput: If True, the compliance check will output verbose information. Default is False.
        @return: A tuple containing the errors, warnings, and failed checks.
        '''
        # Set up a ComplianceChecker
        compliance_checker = UsdUtils.ComplianceChecker(
            rootPackageOnly=False,
            skipVariants=False,
            verbose=verboseOutput  
        )

        # Run the compliance check
        compliance_checker.CheckCompliance(file)

        # Get the results of the compliance check
        errors = compliance_checker.GetErrors()
        warnings = compliance_checker.GetWarnings()
        failed_checks = compliance_checker.GetFailedChecks()
        return errors, warnings, failed_checks

    def find_first_valid_prim(self, stage):
        '''
        @brief This function finds the first valid prim in root layer of a stage.
        @param stage: The stage to search for the first valid prim.
        @return: The first valid prim found in the stage. If no valid prim is found, None is returned.
        '''
        # Get the root layer of the stage
        root_layer = stage.GetRootLayer()

        # Find first valid prim 
        first_prim = None
        for prim in stage.Traverse():
            if prim.IsValid():
                first_prim = prim
                break
            
        return first_prim

    def set_required_validation_attributes(self, stage):
        '''
        @brief This function sets the required validation attributes for the stage.
        For now this function sets the upAxis and metersPerUnit. to Y and 1.0 respectively.
        @param stage: The stage to set the required validation attributes.
        '''
        # Set the upAxis and metersPerUnit for validation
        UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
        UsdGeom.SetStageMetersPerUnit(stage, 1.0)

    def find_materials(self, stage, find_first:bool=True):
        '''
        @brief This function finds the first material in the stage. Assumes MaterialX
        materials are stored under the "/MaterialX/Materials" scope.
        @param stage: The stage to search for the first material.
        @param find_first: If True, only the first material found is returned. Default is True.
        @return: The first material found in the stage. If no material is found, None is returned.
        '''
        found_materials = []

        # Find the first material under the "MaterialX/Materials" scope
        materialx_prim = stage.GetPrimAtPath("/MaterialX")
        if not materialx_prim:
            self.logger.info("> Warning: Could not find /MaterialX scope in the USDA file.")
            return found_materials

        materials_prim = materialx_prim.GetPrimAtPath("Materials")
        if not materials_prim:
            self.logger.info("> Warning: Could not find /MaterialX/Materials scope in the USDA file.")
            return found_materials

        for child_prim in materials_prim.GetAllChildren():
            if child_prim.GetTypeName() == "Material":
                found_materials.append(child_prim)
                if find_first:
                    break

        return found_materials
    
    def add_skydome_light(self, stage: Usd.Stage, environment_path:str, root_path:str = "/TestScene/Lights", light_name:str = "EnvironmentLight", xform_scale=Gf.Vec3f(1.3, 1.3, 1.3), xform_rotate=Gf.Vec3f(0, 0, 0)):
        '''
        @brief This function adds a skydome light to the stage.
        @param stage: The stage to add the skydome light.
        @param environment_path: The path to the environment light file.
        @param root_path: The root path to add the skydome light.
        @param light_name: The name of the skydome light.
        @param xform_scale: The scale of the skydome light.
        @param xform_rotate: The rotation of the skydome light.
        @return: The skydome light added to the stage.
        '''
        skydome_prim = stage.DefinePrim(root_path, "Xform")
        # Make the skydome prim Xformable
        xformable = UsdGeom.Xformable(skydome_prim)

        # Scale drawing of skydome
        scale_op = xformable.GetScaleOp()
        if not scale_op:
            scale_op = xformable.AddScaleOp(UsdGeom.XformOp.PrecisionFloat)
        scale_value = xform_scale 
        scale_op.Set(scale_value)

        dome_light = UsdLux.DomeLight.Define(stage, f"{root_path}/{light_name}")

        # Set the attributes for the DomeLight
        dome_light.CreateIntensityAttr().Set(1.0)
        dome_light.CreateTextureFileAttr().Set(environment_path)

        # Set guideRadius
        dome_light.CreateGuideRadiusAttr().Set(1.0)

        # Rotate the light as needed.
        xformable = UsdGeom.Xformable(dome_light)
        xform_op = xformable.GetXformOp(UsdGeom.XformOp.TypeRotateXYZ)
        if not xform_op:
            xform_op = xformable.AddXformOp(UsdGeom.XformOp.TypeRotateXYZ, UsdGeom.XformOp.PrecisionFloat)
        xform_op.Set(xform_rotate)

        # Set the xformOpOrder
        xformable.SetXformOpOrder([xform_op])

        return dome_light
    
    def add_geometry_reference(self, stage: Usd.Stage, geometry_path : str, root_path : str="/TestScene/Geometry"):
        '''
        @brief This function adds a geometry reference to the stage.
        @param stage: The stage to add the geometry reference.
        @param geometry_path: The path to the geometry file.
        @param root_path: The root path to add the geometry reference.
        '''
        geom_prim = stage.DefinePrim(root_path, "Xform")        
        geom_prim.GetReferences().AddReference(geometry_path)
        return geom_prim
    
    def find_first_camera(self, stage : Usd.Stage):
        '''
        @brief This function finds the first camera in the stage.
        @param stage: The stage to search for the first camera.
        @return: The first camera found in the stage. If no camera is found, None is returned.
        '''
        # Traverse the stage's prims
        for prim in stage.Traverse():
            # Check if the prim is a UsdGeomCamera
            if prim.IsA(UsdGeom.Camera):
                return prim
        return None
    
    def add_camera(self, stage : Usd.Stage, camera_path : str, root_path : str="/TestScene/Camera", geometry_path : str="/TestScene/Geometry"):
        '''
        @brief This function adds a camera to the stage.
        @param stage: The stage to add the camera.
        @param camera_path: The path to the camera file.
        @param root_path: The root path to add the camera.
        @param geometry_path: The path to the geometry file.
        '''
        if camera_path:
            camera = stage.DefinePrim(root_path, "Xform")
            camera.GetReferences().AddReference(camera_path) 
            return camera
        
        # Define the geometry path (e.g., a cube or any other geometry)
        geometry_path = Sdf.Path(geometry_path)

        # Get the UsdPrim for the geometry
        geometry_prim = stage.GetPrimAtPath(geometry_path)

        camera_path = Sdf.Path(root_path)
        camera = UsdGeom.Camera.Define(stage, camera_path)

        # Compute the world space bounding box of the geometry
        bbox_cache = UsdGeom.BBoxCache(Usd.TimeCode.Default(), [UsdGeom.Tokens.default_])
        bbox = bbox_cache.ComputeWorldBound(geometry_prim)
        bbox_range = bbox.ComputeAlignedRange()

        # Get the center and size of the bounding box
        bbox_center = bbox_range.GetMidpoint()  # This is a Gf.Vec3d
        bbox_size = bbox_range.GetSize()  # This is a Gf.Vec3d

        # Position the camera to frame the bounding box
        # Move the camera back along the Z-axis to fit the bounding box
        distance = max(bbox_size) * 1.5  # Adjust the multiplier as needed

        # Convert bbox_center to Gf.Vec3f for compatibility with Gf.Vec3f(0, 0, distance)
        camera_position = Gf.Vec3f(bbox_center) + Gf.Vec3f(0, 0, distance)
        camera.AddTranslateOp().Set(camera_position)

        # Orient the camera to look at the center of the bounding box
        camera.AddRotateYOp().Set(0)  # Rotate to look along the -Z axis
        look_at = UsdGeom.XformCommonAPI(camera)
        look_at.SetRotate((0, 0, 0))  # Ensure the camera is aligned

        # Adjust the camera's field of view to fit the bounding box
        focal_length = 35.0  # Default focal length
        camera.GetFocalLengthAttr().Set(focal_length)

        # Set the horizontal and vertical aperture to ensure proper framing
        horizontal_aperture = bbox_size[0] / bbox_size[1] * 20.0  # Adjust based on aspect ratio
        vertical_aperture = horizontal_aperture
        camera.GetHorizontalApertureAttr().Set(horizontal_aperture)
        camera.GetVerticalApertureAttr().Set(vertical_aperture)

        # Set the clipping range to include the bounding box
        near_clip = distance - max(bbox_size) * 0.5
        far_clip = distance + max(bbox_size) * 0.5
        camera.GetClippingRangeAttr().Set(Gf.Vec2f(near_clip, far_clip))

        #camera.SetActive(True)

        # Save the USD stage        
        return camera
    
    def mtlx_to_usd(self, input_usd_path : str, shaderball_path : str, environment_path : str, material_file_path : str, camera_path : str,
                    use_custom=False):
        '''
        @brief This function reads the input usd file and adds the shaderball geometry and environment light
        to the scene. It also binds the first material to the shaderball geometry. The final stage is returned.
        @param input_usd_path: Path to the input usd file
        @param shaderball_path: Path to the shaderball geometry file
        @param environment_path: Path to the environment light file
        @param material_file_path: Path to the material file. If specified will save the material file.
        @param camera_path: Path to the camera file
        @return: The final stage with all the elements added
        '''
        # Open the input USDA file
        stage = None 

        if use_custom:
            mtlx_to_usd = mxcust.MtlxToUsd()
            stage = mtlx_to_usd.emit(input_usd_path, False)
            stage.Export('blah.usda', False)
        else:
            try:
                stage = Usd.Stage.Open(input_usd_path)
            except Exception as e:
                self.logger.info(f"> Error: Could not open file at {input_usd_path}. Error: {e}")
                return stage, None, None, None, None
        
        if not stage:
            self.logger.info(f"> Error: Could not open file at {input_usd_path}")
            return stage, None, None, None, None
        
        # Set the required validation attributes
        self.set_required_validation_attributes(stage)

        if material_file_path:
            # Save the material file
            self.logger.info(f"> Saving MaterialX content to: {material_file_path}")
            stage.GetRootLayer().documentation = f"MaterialX content from {input_usd_path}"
            stage.GetRootLayer().Export(material_file_path)

        found_materials = self.find_materials(stage, False)
        #if not found_materials:
        #    self.logger.info("Warning: No materials found under /MaterialX/Materials.")
            #return stage, found_materials, None, None, None
        first_material = found_materials[0] if found_materials else None

        # TODO: Make this a user option...
        SCENE_ROOT = "/TestScene"
        GEOM_ROOT = "/TestScene/Geometry"
        LIGHTS_ROOT = "/TestScene/Lights"
        SKYDOME_LIGHT_NAME = "EnvironmentLight"

        # Define the scene prim
        test_scene_prim = stage.DefinePrim(SCENE_ROOT, "Xform")
        # - Specify a default prim for validation
        stage.SetDefaultPrim(stage.GetPrimAtPath(SCENE_ROOT))

        # - Add geometry reference
        test_geom_prim = None
        if shaderball_path:
            test_geom_prim = self.add_geometry_reference(stage, shaderball_path, GEOM_ROOT)
            if test_geom_prim and first_material:
                material_binding_api = UsdShade.MaterialBindingAPI.Apply(test_geom_prim)
                material_binding_api.Bind(UsdShade.Material(first_material))
                self.logger.info(f"> Geometry reference '{shaderball_path} added under: {test_scene_prim.GetPath()}.")

        # Add lighting with reference to light environment file
        # -----------------------------------------
        dome_light = None
        if environment_path:
            dome_light = self.add_skydome_light(stage, environment_path, LIGHTS_ROOT, SKYDOME_LIGHT_NAME)
            if dome_light:
                self.logger.info(f"> Light '{environment_path}' added at path: {dome_light.GetPath()}.")

        # Add camera reference
        # -----------------------------------------
        camera_prim = self.add_camera(stage, camera_path)
        if camera_prim:
            if camera_path:
                self.logger.info(f"> Camera '{camera_path}' added at path: {camera_prim.GetPath()}.")
            else:
                self.logger.info(f"> Camera added at path: {camera_prim.GetPath()}.")

        return stage, found_materials, test_geom_prim, dome_light, camera_prim
    
    def get_flattend_layer(self, stage):
        '''
        @brief This function flattens the stage and returns the flattened layer.
        @param stage: The stage to flatten.
        @return: The flattened layer.
        '''
        return stage.Flatten()
    
    def save_flattened_layer(self, flattened_layer, output_path:str):
        '''
        @brief This function saves the flattened stage to a new USD file.
        @param flattened_layer: The flattened layer to save.
        @param output_path: The path to save the flattened stage.
        '''
        flatten_path = output_path.replace(".usda", "_flattened.usda")
        flattened_layer.documentation = f"Flattened USD file for {output_path}"
        flattened_layer.Export(flatten_path)
        return flatten_path
    
    def create_usdz_package(self, usdz_file_path:str, flattened_layer):
        '''
        @brief This function creates a new USDZ package from a flattened layer.
        @param usdz_file_path: The path to the USDZ package to create.
        @param flattened_layer: The flattened layer to save to the USDZ package.
        @return: True if the USDZ package was successfully created, False otherwise.
        '''
        success = False
        error = ""
        try:
            success = UsdUtils.CreateNewUsdzPackage(flattened_layer.identifier, usdz_file_path)
            if not success:
                error = ("Failed to create USDZ package.")
        except Exception as e:
            error = (f"An exception occurred while creating the USDZ file: {e}")

        return success, error    

