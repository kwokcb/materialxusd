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

    def __init__(self):
        self._stdlib, self._libFiles = self.load_standard_libraries()

    def load_standard_libraries(self):
        '''Load standard MaierialX libraries.
        @return: The standard library and the list of library files.
        '''
        stdlib = mx.createDocument()
        libFiles = mx.loadLibraries(mx.getDefaultDataLibraryFolders(), mx.getDefaultDataSearchPath(), stdlib)
        return stdlib, libFiles
    
    def get_standard_libraries(self):
        '''
        @brief Get standard MaierialX libraries.
        @return: The standard library and the list of library files.
        '''
        return self._stdlib

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
        mx.readFromXmlFile(doc, mx.FilePath(path))
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
    def add_downstream_materials(doc: mx.Document):
        '''
        @brief Add downstream materials to the MaterialX graph.
        '''
        # if the document has a material skip        
        material_count = len(doc.getMaterialNodes())
        if material_count:
            return 0
        
        nodegraphs = doc.getNodeGraphs()
        if not nodegraphs:
            return 0
        
        for graph in nodegraphs:
            if graph.hasSourceUri():
                continue

            graph_outputs = graph.getOutputs()
            if not graph_outputs:
                continue

            # Use does not support these nodes so need to do it the hard way....
            usd_supports_convert_to_surface_shader = False

            downstream_ports = graph.getDownstreamPorts()
            if not downstream_ports:
                # Add a material per output
                # 
                is_multi_output = len(graph_outputs) > 1    
                for output in graph_outputs:
                    outputName = output.getName()
                    outputType = output.getType()
                    print(f'Scan: {graph.getName()} output: {outputName} type: {outputType}')

                    if outputType in [ 'float', 'vector2', 'vector3', 'vector4', 'integer', 'boolean', 'color3', 'color4' ]:

                        if usd_supports_convert_to_surface_shader:
                            # Create a new material node
                            shaderNodeName = doc.createValidChildName('shader_' + graph.getName() + '_' + outputName)                
                            materialNodeName = doc.createValidChildName('material_' + graph.getName() + '_' + outputName)

                            convertDefinition = 'ND_convert_' + outputType + '_color3'
                            convertNode = doc.getNodeDef(convertDefinition)
                            if not convertNode:
                                print("> Failed to find conversion definition: %s" % convertDefinition)
                            else:
                                shaderNode = doc.addNodeInstance(convertNode, shaderNodeName)
                                shaderNode.removeAttribute('nodedef')
                                newInput = shaderNode.addInput('in', outputType)
                                newInput.setNodeGraphString(graph.getName())
                                newInput.removeAttribute('value')
                                #if is_multi_output:
                                # ISSUE: USD does not handle nodegraph without an explicit output propoerly
                                # so always added in the output string !
                                newInput.setOutputString(outputName)    
                                materialNode = doc.addMaterialNode(materialNodeName, shaderNode)

                                if materialNode:
                                    material_count += 1

                        else:
                            # For now only handle color3 output
                            if outputType != 'color3':
                                print(f'> Skipping unsupported output type: {outputType}')
                                continue
                            # Otherwise add a convert node and connect it to the current upstream node
                            # and then add in a new output whhich is of type color3

                            shaderNodeName = doc.createValidChildName('shader_' + graph.getName() + '_' + outputName)                
                            materialNodeName = doc.createValidChildName('material_' + graph.getName() + '_' + outputName)

                            unlitDefinition = 'ND_surface_unlit'
                            unlitNode = doc.getNodeDef(unlitDefinition)
                            shaderNode = doc.addNodeInstance(unlitNode, shaderNodeName)
                            shaderNode.removeAttribute('nodedef')
                            newInput = shaderNode.addInput('emission_color', outputType)
                            newInput.setNodeGraphString(graph.getName())
                            newInput.removeAttribute('value')
                            #if is_multi_output:
                            # ISSUE: USD does not handle nodegraph without an explicit output propoerly
                            # so always added in the output string !
                            newInput.setOutputString(outputName)    
                            materialNode = doc.addMaterialNode(materialNodeName, shaderNode)

                            if materialNode:
                                material_count += 1
            
        return material_count            

    @staticmethod
    def add_explicit_geometry_stream(graph: mx.GraphElement):
        '''
        @brief Add explicit geometry stream nodes for inputs with defaultgeomprop specified
        in nodes definition. Do this for unconnected inputs only.
        @param graph The MaterialX graph element.
        @return The number of implicit nodes added.
        '''
        
        graph_default_nodes = {}

        for node in graph.getNodes():
            if node.hasSourceUri() or (node.getCategory() in ["nodedef"]):
                continue

            nodedef = node.getNodeDef(node.getType())
            #print('Node:', node.getName(), 'NodeDef:', nodedef.getName() if nodedef else "None")
            if not nodedef:
                continue

            for nodedef_input in nodedef.getInputs():
                node_input = node.getInput(nodedef_input.getName())
                # Skip if is a connected input
                if node_input:
                    if node_input.getInterfaceName() or node_input.getNodeName() or node_input.getNodeGraphString():
                        continue

                # Skip if no defaultgeomprop
                defaultgeomprop = nodedef_input.getDefaultGeomProp()
                if not defaultgeomprop:
                    continue

                # Firewall. USD does not appear to handle bitangent properly so
                # skip it for now.
                if defaultgeomprop.getGeomProp() == "bitangent":
                    print(f'  > WARNING: Skipping adding explicit bitangent node for "{node.getNamePath()}"')
                    continue

                # Fix this up to get information from the defaultgromprop e.g.
                # - texcoord <geompropdef name="UV0" type="vector2" geomprop="texcoord" index="0">
                defaultgeomprop_name = defaultgeomprop.getName()
                defaultgeomprop_prop = defaultgeomprop.getGeomProp()
                defaultgeomprop_type = defaultgeomprop.getType()
                defaultgeomprop_index = defaultgeomprop.getIndex()
                defaultgeomprop_space = defaultgeomprop.getSpace()

                if not node_input:
                    node_input = node.addInput(nodedef_input.getName(), nodedef_input.getType())
                if defaultgeomprop_name not in graph_default_nodes:
                    upstream_default_node = graph.addNode(defaultgeomprop_prop, 
                                                            graph.createValidChildName(defaultgeomprop_name), 
                                                            defaultgeomprop_type)
                    upstream_default_node.addInputsFromNodeDef()

                    # Set space and set index
                    index_input = upstream_default_node.getInput("index")
                    if index_input:
                        index_input.setValue(defaultgeomprop_index, 'integer')
                    space_input = upstream_default_node.getInput("space")  
                    if space_input:
                        space_input.setValue(defaultgeomprop_space, 'string')

                    print(f'  > Added upstream node "{upstream_default_node.getNamePath()}" : {upstream_default_node}')
                    graph_default_nodes[defaultgeomprop_name] = upstream_default_node
                else:
                    upstream_default_node = graph_default_nodes[defaultgeomprop_name]
                    #print('Use upstream node for defaultgromprop:', nodedef_input.getName(), defaultgeomprop)
                node_input.setNodeName(upstream_default_node.getName())

        implicit_nodes_added = len(graph_default_nodes)
        if  graph.getCategory() not in "nodegraph":
            for child_graph in graph.getNodeGraphs():
                if child_graph.hasSourceUri():
                    continue
                implicit_nodes_added += MaterialXUsdUtilities.add_explicit_geometry_stream(child_graph)                        

        return implicit_nodes_added

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
        for elem in doc.getNodes():
            # skips elements that are part of the stdlib
            if elem.hasSourceUri():
                continue
            if (
                elem.getName()
                and (elem.getType() not in ["material", "surfaceshader"])
                and elem.getCategory() not in ["nodegraph", "nodedef"]
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

        
        