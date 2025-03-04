# brief Script to prepare a MaterialX document fo conversion to USD
# usage: python3 prepare_materialx_for_usd.py <input_materialx_file> <output_materialx_file>
try:
    import MaterialX as mx
except ImportError:
    print('MaterialX package not available. Please install MaterialX to use this utility.')
    sys.exit(1)
import sys
import os
import argparse
import logging
from materialxusd_utils import MaterialXUsdUtilities

def main():
    parser = argparse.ArgumentParser(description='Prepare a MaterialX document for conversion to USD')
    parser.add_argument('input', type=str, help='Input MaterialX document')
    parser.add_argument('-o', '--output', type=str, default='', help='Output MaterialX document. Default is input name with "_converted" appended.')
    parser.add_argument('-ng', '--nodegraph', type=str, default='root_graph', help='Name of the new nodegraph to encapsulate the top level nodes. Default is "top_level_nodes"')
    parser.add_argument('-k', '--keep', action='store_true', help='Keep the original top level nodes from the document. Default is True')
    parser.add_argument('-v', '--verbose', action='store_true', help='Print verbose output')
    parser.add_argument("-ip", "--imagepaths", default="", help="Comma separated list of search paths for image path resolving. ")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger('prep_mtlx')    

    input_path = args.input
    if not os.path.exists(input_path):
        logger.info(f"Input file {input_path} does not exist.")
        sys.exit(1)

    output_path = args.output
    if not output_path:
        output_path = input_path.replace('.mtlx', '_converted.mtlx')

    utils = MaterialXUsdUtilities()
    doc = utils.create_document(input_path)

    nodegraph_name = args.nodegraph
    remove_original_nodes = not args.keep
    try:
        top_level_nodes_found = utils.encapsulate_top_level_nodes(doc, nodegraph_name, remove_original_nodes)
        if top_level_nodes_found > 0:
            logger.info(f"> Encapsulated {top_level_nodes_found} top level nodes.")

        # Make implicit geometry streams explicit     
        doc.setDataLibrary(utils.get_standard_libraries())
        implicit_nodes_added = utils.add_explicit_geometry_stream(doc)
        if implicit_nodes_added > 0:
            logger.info(f"> Added {implicit_nodes_added} implicit geometry nodes.")

        materials_added = utils.add_downstream_materials(doc)
        if materials_added:
            logger.info(f'> Added {materials_added} downstream materials.')
        doc.setDataLibrary(None)

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

        if explicit_outputs_added or resolved_image_paths or materials_added> 0 or implicit_nodes_added > 0 or top_level_nodes_found > 0:
            utils.write_document(doc, output_path)
            logger.info(f"> Wrote modified document to {output_path}")
    except Exception as e:
        logger.error(f"> Failed to preprocess document. Error: {e}")

if __name__ == '__main__':
    main()



