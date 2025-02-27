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
    argparser = argparse.ArgumentParser(description='Prepare a MaterialX document for conversion to USD')
    argparser.add_argument('input', type=str, help='Input MaterialX document')
    argparser.add_argument('-o', '--output', type=str, default='', help='Output MaterialX document. Default is input name with "_converted" appended.')
    argparser.add_argument('-ng', '--nodegraph', type=str, default='root_graph', help='Name of the new nodegraph to encapsulate the top level nodes. Default is "top_level_nodes"')
    argparser.add_argument('-k', '--keep', action='store_true', help='Keep the original top level nodes from the document. Default is True')
    args = argparser.parse_args()

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)

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
        top_level_nodes_found = MaterialXUsdUtilities.encapsulate_top_level_nodes(doc, nodegraph_name, remove_original_nodes)
        if top_level_nodes_found > 0:
            logger.info(f"> Encapsulated {top_level_nodes_found} top level nodes.")

        # Make implicit geometry streams explicit     
        doc.setDataLibrary(utils.get_standard_libraries())
        implicit_nodes_added = utils.add_explicit_geometry_stream(doc)
        if implicit_nodes_added > 0:
            logger.info(f"> Added {implicit_nodes_added} implicit geometry nodes.")

        materials_added = utils.add_downstream_materials(doc)
        print(f'  > Added {materials_added} downstream materials.')
        doc.setDataLibrary(None)

        if materials_added> 0 or implicit_nodes_added > 0 or top_level_nodes_found > 0:
            utils.write_document(doc, output_path)
            logger.info(f"> Wrote modified document to {output_path}")
    except Exception as e:
        logger.error(f"> Failed to preprocess document. Error: {e}")

if __name__ == '__main__':
    main()



