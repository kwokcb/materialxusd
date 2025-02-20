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
    def encapsulate_top_level_nodes(input_path, new_input_path, nodegraph_name='top_level_nodes', remove_original_nodes=True):
        '''
        @brief Encapsulate top level nodes in a nodegraph. Remap any connections to the top level nodes 
        to outputs on a new nodegraph.
        @param input_path The path to the MaterialX document.
        @param new_input_path The path to write the modified MaterialX document.
        @param nodegraph_name The name of the new nodegraph to encapsulate the top level nodes. Default is 'top_level_nodes'.
        @param remove_original_nodes If True, remove the original top level nodes from the document. Default is True.
        @return The modified MaterialX document if top level connections were found, None otherwise.
        '''
        connections_made = 0

        doc = mx.createDocument()
        mx.readFromXmlFile(doc, input_path)
        # Find all children of document which are no material or shader nodes.
        top_level_nodes = []
        top_level_connections = []
        for elem in doc.getChildren():
            if elem.getName() and (elem.getType() not in ["material", "surfaceshader"]) and elem.getCategory() not in ["nodegraph"]:
                #print('Finding top level nodes: ', elem.getName(), elem.getType())
                top_level_nodes.append(elem)
            elif elem.getType() in ["surfaceshader"]:
                for input in elem.getInputs():
                    upstreamNode = input.getNodeName()
                    if len(upstreamNode) > 0:
                        upstreamOutputName = input.getOutputString()
                        #print('Store connection: ', upstreamNode, "<--", input.getNamePath())
                        top_level_connections.append([upstreamNode, input.getNamePath(), upstreamOutputName])
        
        #print('Top level connections: ', top_level_connections)
        if len(top_level_connections) > 0:
            converted_document = True

            ng_name = doc.createValidChildName(nodegraph_name)
            ng = doc.addNodeGraph(ng_name)
            for node in top_level_nodes:
                #print("Adding node: ", node.getName())
                new_node = ng.addNode(node.getCategory(), mx.createValidName(node.getName()), node.getType())
                new_node.copyContentFrom(node)
                for connect in top_level_connections:
                    if connect[0] == node.getName():
                        the_input = doc.getDescendant(connect[1])
                        if the_input:
                            # Create a new output on the graph
                            new_output = ng.addOutput(ng.createValidChildName("out"), the_input.getType())
                            new_output.setNodeName(new_node.getName())
                            if len(connect[2]) > 0:
                                new_output.setOutputString(connect[2])
                            #print('Create new output: ', mx.prettyPrint(new_output))
                            the_input.setNodeGraphString(ng_name)
                            the_input.setOutputString(new_output.getName())
                            the_input.removeAttribute('nodename')
                            #print('Reconnecting: ', the_input.getNamePath(), ": ", connect[1], " to ", mx.prettyPrint(the_input))
                            
                            connections_made += 1

            if remove_original_nodes:
                for node in top_level_nodes:
                    doc.removeChild(node.getName())

        if connections_made:            
            print(f'> Encapsulated {connections_made} top level connections in a new nodegraph.')
            if new_input_path:
                print(f'> Writing modified MaterialX document to: {new_input_path}')
                mx.writeToXmlFile(doc, new_input_path)
            return doc 
        return None

        
        