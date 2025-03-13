#!/usr/bin/env python
'''
Conversion utilities to convert from USD to MaterialX and MaterialX to USD.
'''
from pxr import Usd, UsdShade, Sdf, Gf
import MaterialX as mx


class MtlxToUsd:
    '''
    Sample converter from MaterialX to USD.
    '''
    def __init__(self, logger=None):
        '''
        Constructor.
        @param logger: Logger object.
        '''
        self.logger = logger

    def log(self, msg, level=0):
        '''
        Log a message.
        @param msg: Message to log.
        @param level: Log level.
        '''
        if self.logger:
            if level == 1:
                self.logger.warning(msg)
            elif level == 2:
                self.logger.error(msg)
            elif level == -1:
                self.logger.debug(msg)
            else:                
                self.logger.info(msg)
        else:
            self.log(msg)

    def get_usd_types(self):
        '''
        Retrieve a list of USD Sdf value type names.
        @return: List of USD Sdf value type names.
        '''
        types = []
        for t in dir(Sdf.ValueTypeNames):
            if not t.startswith("__"):
                types.append(str(t))
        return types

    def map_mtlx_to_usd_type(self, mtlx_type : str):
        '''
        Map a MaterialX type to a USD Sdf type.The mapping is easier from MaterialX as
        the number of type variations is much less. Note that one USD type is chosen
        with no options for choosing things like precision.
        @param mtlx_type: MaterialX type.
        @return: Corresponding USD Sdf type.
        '''
        mtlx_usd_map = {
            "filename": Sdf.ValueTypeNames.Asset,
            "string": Sdf.ValueTypeNames.String,
            "boolean": Sdf.ValueTypeNames.Bool,
            "integer": Sdf.ValueTypeNames.Int,
            "float": Sdf.ValueTypeNames.Float,
            "color3": Sdf.ValueTypeNames.Color3f,
            "color4": Sdf.ValueTypeNames.Color4f,
            "vector2": Sdf.ValueTypeNames.Float2,
            "vector3": Sdf.ValueTypeNames.Float3,
            "vector4": Sdf.ValueTypeNames.Float4,
            "surfaceshader": Sdf.ValueTypeNames.Token,
            "volumeshader": Sdf.ValueTypeNames.Token,
            "displacementshader": Sdf.ValueTypeNames.Token,
        }
        return mtlx_usd_map.get(mtlx_type, Sdf.ValueTypeNames.Token)

    def map_mtlx_to_usd_value(self, mtlx_type, mtlx_value):
        '''
        Map a MaterialX value of a given type to a USD value.
        TODO: Add all types here...
        @param mtlx_type: MaterialX type.
        @param mtlx_value: MaterialX value.
        @return: Corresponding USD value.
        '''
        if mtlx_type == "float":
            return float(mtlx_value)
        elif mtlx_type == "integer":
            return int(mtlx_value)
        elif mtlx_type == "boolean":
            return bool(mtlx_value)
        elif mtlx_type in ("string", "filename"):
            return str(mtlx_value)
        elif mtlx_type == "vector2":
            return Gf.Vec2f(mtlx_value[0], mtlx_value[1])
        elif mtlx_type in ("color3", "vector3"):
            return Gf.Vec3f(mtlx_value[0], mtlx_value[1], mtlx_value[2])
        elif mtlx_type in ("color4", "vector4"):
            return Gf.Vec4f(mtlx_value[0], mtlx_value[1], mtlx_value[2], mtlx_value[3])
        return None

    def map_mtlx_to_usd_shader_notation(self, name):
        '''
        Utility to map from MaterialX shader notation to USD notation.
        @param name: MaterialX shader notation.
        @return: Corresponding USD notation.
        '''
        if name == "surfaceshader":
            return "surface"
        elif name == "displacementshader":
            return "displacement"
        elif name == "volumeshader":
            return "volume"
        return name

    def emit_usd_connections(self, node, stage, root_path):
        '''
        Emit connections between MaterialX elements as USD connections for
        a given MaterialX node.
        @param node: MaterialX node to examine.
        @param stage: USD stage to write connection to.
        @param root_path: Root path for connections.
        '''
        if not node:
            return

        material_path = None
        if node.getType() == "material":
            material_path = node.getName()

        for value_element in node.getActiveValueElements():
            is_input = value_element.isA(mx.Input)
            is_output = value_element.isA(mx.Output)

            if is_input or is_output:
                interface_name = ""

                # Find out what type of element is connected to upstream:
                # node, nodegraph, or interface input.
                mtlx_connection = value_element.getAttribute("nodename")
                if not mtlx_connection:
                    mtlx_connection = value_element.getAttribute("nodegraph")
                if is_input and not mtlx_connection:
                    mtlx_connection = value_element.getAttribute("interfacename")
                    interface_name = mtlx_connection

                connection_path = ""
                if mtlx_connection:
                    # Handle input connection by searching for the appropriate parent node.
                    # - If it's an interface input we want the parent nodegraph. Otherwise
                    # we want the node or nodegraph specified above.
                    # - If the parent path is the root (getNamePath() is empty), then this is to
                    # nodes at the root document level.
                    if is_input:
                        parent = node.getParent()
                        if parent.getNamePath():
                            if interface_name:
                                connection_path = root_path + parent.getNamePath()
                            else:
                                connection_path = root_path + parent.getNamePath() + "/" + mtlx_connection
                        else:
                            # The connection is to a prim at the root level so insert a '/' identifier
                            # as getNamePath() will return an empty string at the root Document level.
                            if interface_name:
                                connection_path = root_path
                            else:
                                connection_path = root_path + mtlx_connection

                    # Handle output connection by looking for sibling elements
                    else:
                        parent = node.getParent()

                        # Connection is to sibling under the same nodegraph
                        if node.isA(mx.NodeGraph):
                            connection_path = root_path + node.getNamePath() + "/" + mtlx_connection
                        else:
                            # Connection is to a nodegraph parent of the current node
                            if parent.getNamePath():
                                connection_path = root_path + parent.getNamePath() + "/" + mtlx_connection
                            # Connection is to the root document.
                            else:
                                connection_path = root_path + mtlx_connection

                    # Find the source prim
                    # Assumes that the source is either a nodegraph, a material or a shader
                    connection_path = connection_path.removesuffix("/")
                    source_prim = None
                    source_port = "out"
                    source = stage.GetPrimAtPath(connection_path)
                    if not source and material_path:
                        connection_path = "/" + material_path + connection_path
                        source = stage.GetPrimAtPath(connection_path)
                        if not source:
                            source = stage.GetPrimAtPath("/" + material_path)

                    if source:
                        if source.IsA(UsdShade.Material):
                            source_prim = UsdShade.Material(source)
                        elif source.IsA(UsdShade.NodeGraph):
                            source_prim = UsdShade.NodeGraph(source)
                        elif source.IsA(UsdShade.Shader):
                            source_prim = UsdShade.Shader(source)

                        # Special case handle interface input vs an output
                        if interface_name:
                            source_port = interface_name
                        else:
                            source_port = value_element.getAttribute("output") or "out"

                    # Find destination prim and port and make the appropriate connection.
                    # Assumes that the destination is either a nodegraph, a material or a shader
                    if source_prim:
                        dest = stage.GetPrimAtPath(root_path + node.getNamePath())
                        if dest:
                            port_name = value_element.getName()
                            dest_node = None
                            if dest.IsA(UsdShade.Material):
                                dest_node = UsdShade.Material(dest)
                            elif dest.IsA(UsdShade.NodeGraph):
                                dest_node = UsdShade.NodeGraph(dest)
                            elif dest.IsA(UsdShade.Shader):
                                dest_node = UsdShade.Shader(dest)

                            # Find downstream port (input or output)
                            if dest_node:
                                if is_input:
                                    # Map from MaterialX to USD connection syntax
                                    if dest.IsA(UsdShade.Material):
                                        port_name = self.map_mtlx_to_usd_shader_notation(port_name)
                                        port_name = "mtlx:" + port_name
                                        dest_port = dest_node.GetOutput(port_name)
                                    else:
                                        dest_port = dest_node.GetInput(port_name)
                                else:
                                    dest_port = dest_node.GetOutput(port_name)

                                # Make connection to interface input, or node/nodegraph output
                                if dest_port:
                                    if interface_name:
                                        interface_input = source_prim.GetInput(source_port)
                                        if interface_input:
                                            if not dest_port.ConnectToSource(interface_input):
                                                self.log(f"> Failed to connect: {source.GetPrimPath()} --> {dest_port.GetFullName()}")
                                    else:
                                        source_prim_api = source_prim.ConnectableAPI()
                                        if not dest_port.ConnectToSource(source_prim_api, source_port):
                                            self.log(f"> Failed to connect: {source.GetPrimPath()} --> {dest_port.GetFullName()}")
                                else:
                                    self.log(f"> Failed to find destination port: {port_name}")

    def emit_usd_value_elements(self, node, usd_node, emit_all_value_elements):
        '''
        Emit MaterialX value elements in USD.
        @param node: MaterialX node with value elements to scan.
        @param usd_node: UsdShade node to create value elements on.
        @param emit_all_value_elements: Emit value elements based on node definition, even if not specified on node instance.
        '''
        if not node:
            return

        is_material = node.getType() == "material"
        node_def = node.getNodeDef()

        # Instantiate with all the nodedef inputs (if emit_all_value_elements is True).
        # Note that outputs are always created.
        if node_def and not is_material:
            for value_element in node_def.getActiveValueElements():
                if value_element.isA(mx.Input):
                    if emit_all_value_elements:
                        mtlx_type = value_element.getType()
                        usd_type = self.map_mtlx_to_usd_type(mtlx_type)
                        port_name = value_element.getName()
                        usd_input = usd_node.CreateInput(port_name, usd_type)

                        if value_element.getValueString():
                            mtlx_value = value_element.getValue()
                            usd_value = self.map_mtlx_to_usd_value(mtlx_type, mtlx_value)
                            if usd_value is not None:
                                usd_input.Set(usd_value)
                        color_space = value_element.getAttribute("colorspace")
                        if color_space:
                            usd_input.GetAttr().SetColorSpace(color_space)                            

                elif not is_material and value_element.isA(mx.Output):
                    usd_node.CreateOutput(value_element.getName(), self.map_mtlx_to_usd_type(value_element.getType()))

        # From the given instance add inputs and outputs and set values.
        # This may override the default value specified on the definition.
        for value_element in node.getActiveValueElements():
            if value_element.isA(mx.Input):
                mtlx_type = value_element.getType()
                usd_type = self.map_mtlx_to_usd_type(mtlx_type)
                port_name = value_element.getName()
                if is_material:
                    # Map from Materials to USD notation
                    port_name = self.map_mtlx_to_usd_shader_notation(port_name)
                    usd_input = usd_node.CreateOutput("mtlx:" + port_name, usd_type)
                else:
                    usd_input = usd_node.CreateInput(port_name, usd_type)

                # Set value. Note that we check the length of the value string
                # instead of getValue() as a 0 value will be skipped.
                if value_element.getValueString():
                    mtlx_value = value_element.getValue()
                    usd_value = self.map_mtlx_to_usd_value(mtlx_type, mtlx_value)
                    if usd_value is not None:
                        usd_input.Set(usd_value)
                color_space = value_element.getAttribute("colorspace")
                if color_space:
                    usd_input.GetAttr().SetColorSpace(color_space)                            


            elif not is_material and value_element.isA(mx.Output):
                usd_output = usd_node.GetInput(value_element.getName())
                if not usd_output:
                    usd_node.CreateOutput(value_element.getName(), self.map_mtlx_to_usd_type(value_element.getType()))

    def emit_usd_shader_graph(self, doc, stage, mtlx_nodes, emit_all_value_elements, root="/MaterialX/Materials/"):
        '''
        Emit USD shader graph to a given stage from a list of MaterialX nodes.
        @param doc: MaterialX source document.
        @param stage: USD target stage.
        @param mtlx_nodes: MaterialX shader nodes.
        @param emit_all_value_elements: Emit value elements based on node definition, even if not specified on node instance.
        @param root: Root path for the shader graph.
        '''
        material_path = None
        for node_name in mtlx_nodes:
            elem = doc.getDescendant(node_name)
            if elem.getType() == "material":
                material_path = elem.getName()
                break

        # Emit USD nodes
        for node_name in mtlx_nodes:
            elem = doc.getDescendant(node_name)
            usd_path = root + elem.getNamePath()

            node_def = None
            usd_node = None
            if elem.getType() == "material":
                self.log(f"Add material at path: {usd_path}", -1)
                usd_node = UsdShade.Material.Define(stage, usd_path)
                material_prim = usd_node.GetPrim()
                material_prim.ApplyAPI("MaterialXConfigAPI")
            elif elem.isA(mx.Node):
                node_def = elem.getNodeDef()
                self.log(f"Add node at path: {usd_path}", -1)
                usd_node = UsdShade.Shader.Define(stage, usd_path)
            elif elem.isA(mx.NodeGraph):
                self.log(f"Add nodegraph at path: {usd_path}", -1)
                usd_node = UsdShade.NodeGraph.Define(stage, usd_path)

            if usd_node:
                if node_def:
                    usd_node.SetShaderId(node_def.getName())
                self.emit_usd_value_elements(elem, usd_node, emit_all_value_elements)

        # Emit connections between USD nodes
        for node_name in mtlx_nodes:
            elem = doc.getDescendant(node_name)
            if elem.getType() == "material" or elem.isA(mx.Node) or elem.isA(mx.NodeGraph):
                self.emit_usd_connections(elem, stage, root)

    def find_materialx_nodes(self, doc):
        '''
        Find all nodes in a MaterialX document.
        @param doc: MaterialX document.
        @return: List of node paths.
        '''
        visited_nodes = []
        for elem in doc.traverseTree():
            path = elem.getNamePath()
            if path not in visited_nodes:
                visited_nodes.append(path)
        return visited_nodes
    
    def emit_document_metadata(self, doc, stage):
        '''
        Emit MaterialX document metadata to the USD stage.
        @param doc: MaterialX document.
        @param stage: USD stage.
        '''
        root_layer = stage.GetRootLayer()
        # - color space
        color_space = doc.getColorSpace()
        if not color_space:
            color_space = "lin_rec709"
        
        custom_layer_data = {"colorSpace": color_space}        
        if root_layer.customLayerData:
            root_layer.customLayerData.update(custom_layer_data)
        else:
            root_layer.customLayerData = custom_layer_data

    def emit(self, mtlx_file_name, emit_all_value_elements):
        '''
        Read in a MaterialX file and emit it to a new USD Stage.
        Dump results for display and save to usda file.
        @param mtlx_file_name: Name of file containing MaterialX document. Assumed to end in ".mtlx".
        @param emit_all_value_elements: Emit value elements based on node definition, even if not specified on node instance.
        @return: USD stage.
        '''
        stage = Usd.Stage.CreateInMemory()
        doc = mx.createDocument()
        mtlx_file_path = mx.FilePath(mtlx_file_name)

        if not mtlx_file_path.exists():
            self.log(f"Failed to read file: {mtlx_file_path.asString()}")
            return

        # Find nodes to transform before importing the definition library
        mx.readFromXmlFile(doc, mtlx_file_name)
        mtlx_nodes = self.find_materialx_nodes(doc)

        stdlib = self.create_library_document()
        doc.setDataLibrary(stdlib)

        self.emit_document_metadata(doc, stage)

        # Translate
        self.emit_usd_shader_graph(doc, stage, mtlx_nodes, emit_all_value_elements)
        return stage

    def create_library_document(self):
        '''
        Create a MaterialX library document.
        @return: MaterialX library document.
        '''
        stdlib = mx.createDocument()
        search_path = mx.getDefaultDataSearchPath()
        mx.loadLibraries(mx.getDefaultDataLibraryFolders(), search_path, stdlib)
        return stdlib
