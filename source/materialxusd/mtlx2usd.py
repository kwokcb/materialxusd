# @brief: This script converts MaterialX file to usda file and adds inscene elements which
# use the material. Currently only the first material is bound to a single geometry
import argparse
import os
import sys
import zipfile
import logging

import MaterialX as mx
import materialxusd as mxusd
import materialxusd_utils as mxusd_utils

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('mltx2usd')
try:
    from pxr import Usd, Sdf, UsdShade, UsdGeom, Gf, UsdLux, UsdUtils
except ImportError:
    logger.info("Error: Python module 'pxr' not found. Please ensure that the USD Python bindings are installed.")
    exit(1)

### Utilities ####
def get_mtlx_files(input_path: str):
    mtlx_files = []

    if not os.path.exists(input_path):
        logger.info('Error: Input path does not exist.')
        return mtlx_files
    
    if os.path.isdir(input_path):
        for root, dirs, files in os.walk(input_path):
            for file in files:
                if file.endswith(".mtlx") and not file.endswith("_converted.mtlx"):
                    mtlx_files.append(os.path.join(root, file))

    else:
        if input_path.endswith(".mtlx") and not input_path.endswith("_converted.mtlx"):
            mtlx_files.append(input_path)
        elif input_path.endswith(".zip"):
            # Unzip the file and get all mtlx files
            # Get zip file name w/o extension
            output_path = input_path.replace('.zip', '')
            with zipfile.ZipFile(input_path, 'r') as zip_ref:
                zip_ref.extractall(output_path)
            logger.info('> Extracted zip file to: {output_path}')
            for root, dirs, files in os.walk(output_path):
                for file in files:
                    if file.endswith(".mtlx") and not file.endswith("_converted.mtlx"):
                        mtlx_files.append(os.path.join(root, file))
    return mtlx_files

def print_validation_results(output_path:str, errors:str, warnings:str, failed_checks:str):
    if errors or warnings or failed_checks:
        if errors:
            logger.info(f"> Errors: {errors}")
        if warnings:
            logger.info(f"> Warnings: {warnings}")
        if failed_checks:
            logger.info(f"> Failed checks: {failed_checks}")
    else:
        logger.info(f'> Document "{output_path}" is valid.')

def main():
    # Set up command-line argument parsing
    parser = argparse.ArgumentParser(description="Convert MaterialX file to usda file with references to scene elements.")
    parser.add_argument("input_file", help="Path to the input MaterialX file. If a folder is ")
    parser.add_argument("-o", "--output_file", default=None, help="Path to the output USDA file.")
    parser.add_argument("-c", "--camera", default="./data/camera.usda", help="Path to the camera USD file (default: ./data/camera.usda).")
    parser.add_argument("-g", "--geometry", default="./data/shaderball.usd", help="Path to the geometry USD file (default: ./data/shaderball.usda).")
    parser.add_argument("-e", "--environment", default="./data/san_giuseppe_bridge.hdr", help="Path to the environment USD file (default: ./data/san_giuseppe_bridge.hdr).")
    parser.add_argument("-f", "--flatten", action="store_true", help="Flatten the final USD file.")
    parser.add_argument("-m", "--material", action="store_true", help="Save USD file with just MaterialX content.")
    parser.add_argument("-z", "--zip", action="store_true", help="Create a USDZ final file.")
    parser.add_argument("-v", "--validate", action="store_true", help="Validate output documents.")
    parser.add_argument("-r", "--render", action="store_true", help="Render the final stage.")
    parser.add_argument("-sl", "--shadingLanguage", help="Shading language string.", default="glslfx")
    parser.add_argument("-mn", "--useMaterialName", action="store_true", help="Set output file to material name.")
    parser.add_argument("-sf", "--subfolder", action="store_true", help="Save output to subfolder named <input materialx file> w/o extension.")
    parser.add_argument("-pp", "--preprocess", action="store_true", help="Attempt to pre-process the MaterialX file.")
    parser.add_argument("-ip", "--imagepaths", default="", help="Comma separated list of search paths for image path resolving. ")
    parser.add_argument("-ra", "--renderargs", default="", help="Additional render arguments.")

    # Parse arguments
    args = parser.parse_args()

    # if input is a folder then get all .mtlx files under the folder recursively
    input_paths = get_mtlx_files(args.input_file)
    if len(input_paths) == 0:
        logger.info(f"Error: No MaterialX files found in {args.input_file}")
        return
    
    validate_output = args.validate
    
    separator = "-" * 80

    # Create usd file for each mtlx file
    for input_path in input_paths:

        logger.info(separator)

        # Cache this as we don't want to use the modified MaterialX document
        # for the subfolder path to render to
        subfolder_path = input_path
        if args.preprocess:
            logger.info(f"> Pre-processing MaterialX file: {input_path}")
            utils = mxusd_utils.MaterialXUsdUtilities()
            doc = utils.create_document(input_path)

            shader_materials_added = utils.add_materials_for_shaders(doc)
            if shader_materials_added:
                logger.info(f"> Added {shader_materials_added} shader materials to the document")

            doc.setDataLibrary(utils.get_standard_libraries())
            implicit_nodes_added = utils.add_explicit_geometry_stream(doc)
            if implicit_nodes_added:
                logger.info(f"> Added {implicit_nodes_added} explicit geometry nodes to the document")
            num_top_level_nodes = utils.encapsulate_top_level_nodes(doc, 'root_graph')
            if num_top_level_nodes:
                logger.info(f"> Encapsulated {num_top_level_nodes} top level nodes.")

            materials_added = utils.add_downstream_materials(doc)
            materials_added += utils.add_materials_for_shaders(doc)
            if materials_added:
                logger.info(f'> Added {materials_added} downstream materials.')

            # Add explicit outputs to nodegraph outputs for shader connections
            explicit_outputs_added = utils.add_nodegraph_output_qualifier_on_shaders(doc)
            if explicit_outputs_added:
                logger.info(f"> Added {explicit_outputs_added} explicit outputs to nodegraph outputs for shader connections")

            # Resolve image file paths
            # Include absolute path of the input file's folder
            resolved_image_paths = False
            image_paths = args.imagepaths.split(',') if args.imagepaths else []
            image_paths.append(os.path.dirname(os.path.abspath(input_path)))
            if image_paths:
                beforeDoc = mx.prettyPrint(doc)             
                mx_image_search_path = utils.create_FileSearchPath(image_paths)
                utils.resolve_image_file_paths(doc, mx_image_search_path)
                afterDoc = mx.prettyPrint(doc)
                if beforeDoc != afterDoc:
                    resolved_image_paths = True
                    logger.info(f"> Resolved image file paths using search paths: {mx_image_search_path}")
                resolved_image_paths = True            

            if explicit_outputs_added or resolved_image_paths or materials_added > 0 or num_top_level_nodes > 0 or implicit_nodes_added > 0:
                valid, errors = doc.validate()
                doc.setDataLibrary(None)     
                if not valid:
                    logger.warning(f"> Validation errors: {errors}")

                new_input_path = input_path.replace('.mtlx', '_converted.mtlx')
                utils.write_document(doc, new_input_path)
                logger.info(f"> Saved converted MaterialX document to: {new_input_path}")
                input_path = new_input_path

        material_file_path = ''
        if args.material:
            material_file_path = input_path.replace('.mtlx', '_material.usda')

        # Not required as done in Python
        #logger.info('> Converting MaterialX file to USDA file: ', input_path, material_file_path)
        #os.system(f"usdcat {input_path} -o {material_file_path}")
        #input_path = material_file_path

        # Translate MaterialX to USD document
        logger.info(f"> Build tests scene from material scene: {input_path}")
        abs_geometry_path = os.path.abspath(args.geometry)
        if not os.path.exists(abs_geometry_path):
            logger.info(f"> Error: Geometry file not found at {abs_geometry_path}")
            return
        abs_environment_path = os.path.abspath(args.environment)
        if not os.path.exists(abs_environment_path):
            logger.info(f"> Error: Environment file not found at {abs_environment_path}")
            return
        
        abs_camera_path = None
        if args.camera == "":
            logger.info(f"> Using computer camera from geometry.")
        else:
            abs_camera_path = os.path.abspath(args.camera)        
            if not os.path.exists(abs_camera_path):
                logger.info(f"> Camera file not found at {abs_camera_path}")
        
        converter = mxusd.MaterialxUSDConverter()
        stage, found_materials, test_geom_prim, dome_light, camera_prim = converter.mtlx_to_usd(input_path, 
                                                                                                abs_geometry_path, 
                                                                                                abs_environment_path, 
                                                                                                material_file_path, 
                                                                                                abs_camera_path)

        if stage:
            output_folder, input_file = os.path.split(input_path)
            output_file = input_file
            unused, subfolder_file = os.path.split(subfolder_path)

            if not found_materials:
                found_materials = []
            material_count = len(found_materials) 
            multiple_materials = material_count > 1
            if material_count == 0:
                # Append a dummy so that the stage will still be saved
                # and validated, even if no materials are found.
                found_materials.append(None)

            # Iterate through all materials replacing the bound
            # material in the test geometry. Note that we do not
            # create a new stage for each material, but rather
            # bind the material to the existing stage and save it
            # to new files.
            for found_material in found_materials:

                # Replace the bound material in the test geometry
                if test_geom_prim and found_material:
                    logger.info(f"> Bind material to geometry: {found_material.GetName()} to {test_geom_prim.GetPath()}")
                    material_binding_api = UsdShade.MaterialBindingAPI(test_geom_prim)
                    material_binding_api.Bind(UsdShade.Material(found_material))

                # Override: Use material name as output file name instead
                # Also use material name if multiple materials are found
                use_material_name = args.useMaterialName
                if multiple_materials:
                    use_material_name = True
                if use_material_name:
                    if found_material:
                        found_material_name = found_material.GetName()
                        # Split output_path into folder and file names
                        output_file = found_material_name + ".usda"

                # Append input file name (w/o extension) to output folder
                sub_folder = output_folder
                if args.render and args.subfolder:
                    subfolder_name = os.path.join(output_folder, subfolder_file.replace('.mtlx', ''))
                    if not os.path.exists(subfolder_name):
                        os.makedirs(subfolder_name)
                    sub_folder = subfolder_name
                    logger.info(f"> Override output folder: {subfolder_name}")

                output_file = output_file.replace('.mtlx', '.usda')
                output_path = os.path.join(output_folder, output_file)

                # Save the modified stage to the output USDA file
                stage.GetRootLayer().documentation = f"Combined content from: {input_path}, {abs_geometry_path}, {abs_environment_path}."
                stage.GetRootLayer().Export(output_path)
                logger.info(f"> Save USD file to: {output_path}.")

                if validate_output:
                    #logger.info(f"> Validating document: {output_path}")
                    errors, warnings, failed_checks = converter.validate_stage(output_path)
                    print_validation_results(output_path, errors, warnings, failed_checks)

                #if not found_material:
                #    logger.info("> Warning: No materials found in the MaterialX document. Continuing to next file.")
                #    continue

                if args.render and found_material:

                    render_path = ''
                    if sub_folder:
                        sub_folder_path = os.path.join(sub_folder, output_file)
                        render_path = sub_folder_path.replace('.usda', f'_{args.shadingLanguage}.png')
                    else:
                        render_path = output_path.replace('.usda', f'_{args.shadingLanguage}.png')
                    render_command = f'usdrecord "{output_path}" "{render_path}" --disableCameraLight --imageWidth 512'
                    if camera_prim:
                        render_command += f' --camera "{camera_prim.GetName()}"'
                    logger.info(f"> Rendering using command: {render_command}")
                    if args.renderargs:
                        render_command += f' {args.renderargs}'
                        print('>'*20, render_command)
                    sys.stdout.flush() 
                    os.system(f"{render_command} > nul 2>&1" if os.name == "nt" else f"{render_command} > /dev/null 2>&1")
                    #os.system(render_command)
                    logger.info("> Rendering complete.")

                # TODO: Currently USDZ conversion is not working propertly yet
                usdz_working = False
                if not usdz_working:
                    args.zip = False

                flattened_layer = None
                need_flattening = args.zip or args.flatten
                if need_flattening:
                    logger.info("> Flattening the stage.")
                    flattened_layer = converter.get_flattend_layer(stage)

                    if flattened_layer:
                        if args.zip:
                            # Save the flattened stage to a new USDZ package
                            usdz_file_path = input_path.replace('.mtlx', '.usdz')
                            usdz_created, error = converter.create_usdz_package(usdz_file_path, flattened_layer)
                            if not usdz_created:
                                logger.info(f"> Error: {error}")

                        if args.flatten:
                            # Save the flattened stage to a new USD file
                            flattend_path = converter.save_flattened_layer(flattened_layer, output_path)
                            logger.info(f"> Flattened USD file saved to: {flattend_path}.")

    done_message = "-" * 80 + "\n> Done."
    logger.info(done_message)

if __name__ == "__main__":
    main()