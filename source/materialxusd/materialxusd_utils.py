have_materialx = False
try:
    import MaterialX as mx
    have_materialx = True
except ImportError:
    print('MaterialX not available. Please install MaterialX to use this utility.')
    have_materialx = False
    
class MaterialXUsdUtilities:
    '''
    @brief A collection of support utilities for working with MaterialX and USD.
    '''
    @staticmethod
    def create_document(path: str):
        '''
        @brief Create a MaterialX document from a file path.
        @param path The path to the MaterialX document.
        @return The MaterialX document if successful, None otherwise.
        '''
        doc = mx.createDocument()
        mx.readFromXmlFile(doc, path)
        return doc
    
    @staticmethod
    def write_document(doc: mx.Document, path: str):
        '''
        @brief Write a MaterialX document to a file.
        @param doc The MaterialX document.
        @param path The path to write the MaterialX document.
        @return True if successful, False otherwise.
        '''
        return mx.writeToXmlFile(doc, path)

    @staticmethod
    def encapsulate_top_level_nodes(doc: mx.Document, nodegraph_name:str="top_level_nodes", remove_original:bool=True):
        """
        @brief Encapsulate top level nodes in a nodegraph. Remap any connections to the top level nodes
        to outputs on a new nodegraph.
        @param input_path The path to the MaterialX document.
        @param new_input_path The path to write the modified MaterialX document.
        @param nodegraph_name The name of the new nodegraph to encapsulate the top level nodes. Default is 'top_level_nodes'.
        @param remove_original_nodes If True, remove the original top level nodes from the document. Default is True.
        @return The number of top level nodes found
        """
        connections_made = 0
        top_level_nodes_found = 0

        # Find all children of document which are no material or shader nodes.
        top_level_nodes = []
        top_level_connections = []
        for elem in doc.getChildren():
            # skips elements that are part of the stdlib
            if elem.hasSourceUri():
                continue
            if (
                elem.getName()
                and (elem.getType() not in ["material", "surfaceshader"])
                and elem.getCategory() not in ["nodegraph"]
            ):
                #print("Finding top level nodes: ", elem.getName(), elem.getType())
                top_level_nodes.append(elem)
            elif elem.getType() in ["surfaceshader"]:
                for input_port in elem.getInputs():
                    upstream_node = input_port.getNodeName()
                    if len(upstream_node) > 0:
                        upstream_output_name = input_port.getOutputString()
                        #print("Store connection: ", upstream_node, "<--", input_port.getNamePath())
                        top_level_connections.append([upstream_node, input_port.getNamePath(), upstream_output_name])
        
        #print("Top level connections: ", top_level_connections)
        top_level_nodes_found = len(top_level_nodes)
        if top_level_nodes_found == 0:
            return top_level_nodes_found

        # create nodegraph
        ng_name = doc.createValidChildName(nodegraph_name)
        ng = doc.addNodeGraph(ng_name)
        for node in top_level_nodes:
            #print("Adding node: ", node.getName())
            new_node = ng.addNode(node.getCategory(), mx.createValidName(node.getName()), node.getType())
            new_node.copyContentFrom(node)
            for connect in top_level_connections:
                if connect[0] == node.getName():
                    the_input = doc.getDescendant(connect[1])
                    if not the_input:
                        continue

                    # Create a new output on the graph
                    new_output = ng.addOutput(ng.createValidChildName("out"), the_input.getType())
                    new_output.setNodeName(new_node.getName())
                    if len(connect[2]) > 0:
                        new_output.setOutputString(connect[2])
                    #print("Create new output: ", mx.prettyPrint(new_output))
                    the_input.setNodeGraphString(ng_name)
                    the_input.setOutputString(new_output.getName())
                    the_input.removeAttribute("nodename")
                    #print(f"Reconnecting {the_input.getNamePath()} {connect[1]} to {mx.prettyPrint(the_input)}")
                    connections_made += 1

        if remove_original:
            for node in top_level_nodes:
                doc.removeChild(node.getName())
        
        return top_level_nodes_found

    @staticmethod
    def encapsulate_top_level_nodes_file(input_path:str, new_input_path:str, nodegraph_name:str='top_level_nodes', 
                                        remove_original_nodes:bool =True):
        '''
        @brief Encapsulate top level nodes in a nodegraph. Remap any connections to the top level nodes 
        to outputs on a new nodegraph.
        @param input_path The path to the MaterialX document.
        @param new_input_path The path to write the modified MaterialX document.
        @param nodegraph_name The name of the new nodegraph to encapsulate the top level nodes. Default is 'top_level_nodes'.
        @param remove_original_nodes If True, remove the original top level nodes from the document. Default is True.
        @return The modified MaterialX document if top level connections were found, None otherwise.
        '''
        doc = MaterialXUsdUtilities.create_document(input_path)
        top_level_nodes_found = MaterialXUsdUtilities.encapsulate_top_level_nodes(doc, nodegraph_name, remove_original_nodes)        
        if top_level_nodes_found:            
            print(f'> Encapsulated {top_level_nodes_found} top level nodes in a new nodegraph.')
            if new_input_path:
                print(f'> Writing modified MaterialX document to: {new_input_path}')
                MaterialXUsdUtilities.write_document(doc, new_input_path)
            return doc 
        return None

        
        