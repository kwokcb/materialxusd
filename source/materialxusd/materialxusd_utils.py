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
        '''
        @brief Constructor.
        '''
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
    def add_materials_for_shaders(doc: mx.Document):
        '''
        @brief Add materials for shaders at the root level of a MaterialX document. Nodegraphs are not considered as this is not supported by USD. 
        @param doc The MaterialX document. 
        @return The number of materials added.
        '''  
        # If has materials skip
        materials = doc.getMaterialNodes()
        if len(materials):
            return 0
        
        material_count = 0
    
        surfaceshader_nodes = doc.getChildren()
        for surfaceshader_node in surfaceshader_nodes:
            if surfaceshader_node.getCategory() not in ['surfaceshader']:
                continue
            downstream_ports = surfaceshader_node.getDownstreamPorts()
            if not downstream_ports:
                # Add a material for the shader
                material_name = doc.createValidChildName('material_' + surfaceshader_node.getName())
                material_node = doc.addMaterialNode(material_name, surfaceshader_node)
                if material_node:
                    material_count += 1
        
        return material_count

    @staticmethod
    def add_downstream_materials(doc: mx.Document):
        '''
        @brief Add downstream materials to the MaterialX graph.
        @param doc The MaterialX document.
        @return The number of materials added.
        '''
        # If has materials skip
        material_count = len(doc.getMaterialNodes())
        if material_count > 0:
            return 0

        nodegraphs = doc.getNodeGraphs()
        if not nodegraphs:
            return 0
        
        # Only support these types of graph outputs
        supported_output_types = [ 'float', 'vector2', 'vector3', 'vector4', 'integer', 'boolean', 'color3', 'color4' ]

        for graph in nodegraphs:
            if graph.hasSourceUri():
                continue


            graph_outputs = graph.getOutputs()
            if not graph_outputs:
                continue

            print('    > Scan graph: ', graph.getName())

            # Use does not support these nodes so need to do it the hard way....
            usd_supports_convert_to_surface_shader = False

            downstream_ports = graph.getDownstreamPorts()
            for output in graph_outputs:
                # See if output name path is in downstream ports
                match = False
                for port in downstream_ports:
                    if port.getNamePath() == output.getNamePath():
                        match = True
                        break
                if match:
                    downstream_ports.remove(port)

            #downstream_port_count = 0
            #for port in downstream_ports:
            #    match = False
            #    for output in graph_outputs:
            #        if port.getName() == output.getName():
            #            match = True                       
            #            break
            #    if not match:
            #        downstream_port_count += 1

            if downstream_ports:                       
                print('        > Downstream port:', ",".join( [port.getNamePath() for port in downstream_ports]))
            if len(downstream_ports) == 0:
                # Add a material per output
                # 
                is_multi_output = len(graph_outputs) > 1    
                for output in graph_outputs:
                    #if downstream_ports:
                    #    for port in downstream_ports:
                    #        if port.getNamePath() == output.getNamePath():
                    #            print('---- SKIP OUTPUT :', output.getNamePath())
                    #            continue
                        
                    output_name = output.getName()
                    output_type = output.getType()

                    print('        > Scan output:', output_name, '. type:', output_type)

                    # Special case for surfaceshader outputs. Just add in a downstream material
                    if output_type == 'surfaceshader':
                        # Add a material for the shader
                        material_name = doc.createValidChildName(graph.getName() + '_' + output_name)
                        material_node = doc.addMaterialNode(material_name)
                        if material_node:
                            print(f"        > Added material node: {material_node.getName()}, for graph shader output: {output_name}")
                            material_node_input = material_node.addInput(output_type, output_type)
                            material_node_input.setNodeGraphString(graph.getName())
                            material_node_input.setOutputString(output_name)
                            material_count += 1

                    elif output_type in supported_output_types:

                        if usd_supports_convert_to_surface_shader:
                            # Create a new material node
                            shadernode_name = doc.createValidChildName('shader_' + graph.getName() + '_' + output_name)                
                            materialnode_name = doc.createValidChildName('material_' + graph.getName() + '_' + output_name)

                            convert_definition = 'ND_convert_' + output_type + '_color3'
                            convert_node = doc.getNodeDef(convert_definition)
                            if not convert_node:
                                print("        > Failed to find conversion definition: %s" % convert_definition)
                            else:
                                shadernode = doc.addNodeInstance(convert_node, shadernode_name)
                                shadernode.removeAttribute('nodedef')
                                new_input = shadernode.addInput('in', output_type)
                                new_input.setNodeGraphString(graph.getName())
                                new_input.removeAttribute('value')
                                #if is_multi_output:
                                # ISSUE: USD does not handle nodegraph without an explicit output propoerly
                                # so always added in the output string !
                                new_input.setOutputString(output_name)    
                                materialnode = doc.addMaterialNode(materialnode_name, shadernode)

                                if materialnode:
                                    material_count += 1

                        else:
                            print(f'Scan: {graph.getName()} output: {output_name} type: {output_type}')
                            
                            # If not color3 or float add a convert node and connect it to the current upstream node
                            # and then add in a new output which is of type color3
                            if output_type != 'color3' and output_type != 'float':

                                convert_definition = 'ND_convert_' + output_type + '_color3'
                                convert_nodedef = doc.getNodeDef(convert_definition)
                                if not convert_nodedef:
                                    print("        > Failed to find conversion definition: %s" % convert_definition)
                                    continue

                                # Find upstream node or interface input
                                convert_upstream = None
                                if len(output.getNodeName()) > 0:
                                    convert_upstream = output.getNodeName()
                                elif output.hasInterfaceName():
                                    convert_upstream = output.getInterfaceName()
                                if not convert_upstream:
                                    print("> Failed to find upstream node for output: %s" % output.getName())
                                    continue

                                # Insert convert node
                                convert_node = graph.addNodeInstance(convert_nodedef, graph.createValidChildName(f'convert_{convert_upstream}'))                                                               
                                convert_node.removeAttribute('nodedef')
                                convert_input = convert_node.addInput('in', output_type)
                                if len(output.getNodeName()) > 0:
                                    convert_input.setNodeName(output.getNodeName())
                                elif output.hasInterfaceName():
                                    convert_input.setInterfaceName(output.getInterfaceName())

                                # Overwrite the upstream connection on the output
                                # and change it's type
                                output.setNodeName(convert_node.getName())                                
                                output.setType('color3')
                                output_type = 'color3'
                            
                            # Create downstream (umlit) shader
                            shadernode_name = doc.createValidChildName('shader_' + graph.getName() + '_' + output_name)                
                            materialnode_name = doc.createValidChildName('material_' + graph.getName() + '_' + output_name)
                            unlitDefinition = 'ND_surface_unlit'
                            unlitNode = doc.getNodeDef(unlitDefinition)
                            shadernode = doc.addNodeInstance(unlitNode, shadernode_name)
                            shadernode.removeAttribute('nodedef')

                            # Connect upstream output to shader input (based on type)
                            new_input = None
                            if output_type == 'color3':
                                new_input = shadernode.addInput('emission_color', output_type)
                            else:
                                new_input = shadernode.addInput('emission', output_type)
                            new_input.setNodeGraphString(graph.getName())
                            new_input.removeAttribute('value')
                            #if is_multi_output:
                            # ISSUE: USD does not handle nodegraph without an explicit output propoerly
                            # so always added in the output string !
                            new_input.setOutputString(output_name)   

                            # Add downstream material node connected to shadernode 
                            materialnode = doc.addMaterialNode(materialnode_name, shadernode)

                            if materialnode:
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

                    #print(f'    > Added upstream node "{upstream_default_node.getNamePath()}" : {upstream_default_node}')
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
        @param doc The MaterialX document.
        @param nodegraph_name The name of the new nodegraph to encapsulate the top level nodes. Default is 'top_level_nodes'.
        @param remove_original If True, remove the original top level nodes from the document. Default is True.
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
    def encapsulate_top_level_nodes_file(input_path:str, new_input_path:str, nodegraph_name:str='top_level_nodes', remove_original_nodes:bool =True):
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

        
        