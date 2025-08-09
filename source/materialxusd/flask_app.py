#!/usr/bin/env python
"""
Flask application with WebSocket support for MaterialX file processing.
Provides functionality to:
1. Preprocess MaterialX files
2. Convert MaterialX to USD files
"""

import os
import sys
import uuid
import json
import logging
from pathlib import Path
from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO, emit
import tempfile
import shutil

# Import MaterialX utilities
import materialxusd_utils as mxusd_utils
import materialxusd as mxusd
import materialxusd_custom as mxcust
import MaterialX as mx

# Get the directory where this script is located
script_dir = os.path.dirname(os.path.abspath(__file__))
template_dir = os.path.join(script_dir, 'templates')

app = Flask(__name__, template_folder=template_dir)
app.config['SECRET_KEY'] = 'your-secret-key-here'
socketio = SocketIO(app, cors_allowed_origins="*", logger=False, engineio_logger=False)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('MaterialXWebApp')

# Global utilities
utils = mxusd_utils.MaterialXUsdUtilities()
usd_converter = mxusd.MaterialxUSDConverter()

class WebSocketLogger:
    """Custom logger that emits messages to WebSocket clients"""
    def __init__(self, session_id):
        self.session_id = session_id
    
    def info(self, message):
        socketio.emit('log_message', {
            'level': 'info',
            'message': str(message)
        }, room=self.session_id)
        logger.info(message)
    
    def warning(self, message):
        socketio.emit('log_message', {
            'level': 'warning', 
            'message': str(message)
        }, room=self.session_id)
        logger.warning(message)
    
    def error(self, message):
        socketio.emit('log_message', {
            'level': 'error',
            'message': str(message)
        }, room=self.session_id)
        logger.error(message)
    
    def debug(self, message):
        socketio.emit('log_message', {
            'level': 'debug',
            'message': str(message)
        }, room=self.session_id)
        logger.debug(message)

@app.route('/')
def index():
    """Serve the main page"""
    return render_template('index.html')

@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    session_id = request.sid
    emit('connected', {'session_id': session_id})
    logger.info(f"Client connected: {session_id}")

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    logger.info(f"Client disconnected: {request.sid}")

@socketio.on('upload_file')
def handle_file_upload(data):
    """Handle MaterialX file upload"""
    try:
        session_id = request.sid
        file_content = data.get('content', '')
        filename = data.get('filename', 'uploaded.mtlx')
        
        if not filename.endswith('.mtlx'):
            emit('error', {'message': 'Please upload a .mtlx file'})
            return
        
        # Create temporary directory for this session
        temp_dir = tempfile.mkdtemp(prefix=f'mtlx_session_{session_id}_')
        file_path = os.path.join(temp_dir, filename)
        
        # Save the uploaded file
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(file_content)
        
        # Validate the MaterialX file
        try:
            doc = utils.create_document(file_path)
            valid, errors = doc.validate()
            
            if not valid:
                emit('file_validation', {
                    'valid': False,
                    'errors': errors,
                    'message': 'MaterialX file has validation errors'
                })
            else:
                emit('file_validation', {
                    'valid': True,
                    'message': 'MaterialX file is valid'
                })
            
            # Store file info in session
            emit('file_uploaded', {
                'filename': filename,
                'temp_path': file_path,
                'temp_dir': temp_dir,
                'size': len(file_content)
            })
            
        except Exception as e:
            emit('error', {'message': f'Error validating MaterialX file: {str(e)}'})
            # Cleanup on error
            shutil.rmtree(temp_dir, ignore_errors=True)
            
    except Exception as e:
        emit('error', {'message': f'Error uploading file: {str(e)}'})

@socketio.on('preprocess_mtlx')
def handle_preprocess_mtlx(data):
    """Handle MaterialX preprocessing"""
    try:
        session_id = request.sid
        ws_logger = WebSocketLogger(session_id)
        
        input_path = data.get('input_path', '')
        options = data.get('options', {})
        
        if not os.path.exists(input_path):
            emit('error', {'message': 'Input file not found'})
            return
        
        emit('operation_started', {'type': 'preprocess', 'message': 'Starting MaterialX preprocessing...'})
        
        # Load the document
        doc = utils.create_document(input_path)
          # Apply preprocessing steps based on options
        total_changes = 0
        
        if options.get('add_materials', True):
            ws_logger.info("Adding materials for shaders...")
            materials_added = utils.add_materials_for_shaders(doc)
            total_changes += materials_added
            if materials_added > 0:
                ws_logger.info(f"Added {materials_added} shader materials")
        
        if options.get('add_nodegraph_outputs', True):
            ws_logger.info("Adding nodegraph output qualifiers...")
            outputs_added = utils.add_nodegraph_output_qualifier_on_shaders(doc)
            total_changes += outputs_added
            if outputs_added > 0:
                ws_logger.info(f"Added {outputs_added} explicit outputs")
        
        if options.get('add_downstream_materials', True):
            ws_logger.info("Adding downstream materials...")
            try:
                # Check if we have the function available
                if not hasattr(utils, 'add_downstream_materials'):
                    raise AttributeError("add_downstream_materials function not found in utils")
                
                downstream_added = utils.add_downstream_materials(doc)
                downstream_added = 0
                
                total_changes += downstream_added
                if downstream_added > 0:
                    ws_logger.info(f"Added {downstream_added} downstream materials")
            except Exception as e:
                ws_logger.warning(f"Failed to add downstream materials: {str(e)}")
                # Continue processing even if this step fails
        
        if options.get('resolve_image_paths', True):
            # Include absolute path of the input file's folder (like mtlx2usd.py)
            resolved_image_paths = False
            image_paths = options.get('image_search_paths', [])
            if input_path:
                image_paths.append(os.path.dirname(os.path.abspath(input_path)))
            
            if image_paths:
                ws_logger.info(f"Resolving image paths with search paths: {image_paths}")
                
                # Use the same approach as mtlx2usd.py - compare before/after
                beforeDoc = mx.prettyPrint(doc)
                mx_search_path = utils.create_FileSearchPath(image_paths)
                utils.resolve_image_file_paths(doc, mx_search_path)
                afterDoc = mx.prettyPrint(doc)
                
                if beforeDoc != afterDoc:
                    resolved_image_paths = True
                    ws_logger.info(f"Successfully resolved image file paths using search paths: {mx_search_path.asString()}")
                    total_changes += 1  # Count this as a change
                else:
                    ws_logger.info("No image paths needed resolution")
                    
                # Always set to True like mtlx2usd.py does for consistency
                resolved_image_paths = True
        
        if options.get('encapsulate_nodes', False):
            nodegraph_name = options.get('nodegraph_name', 'root_graph')
            remove_original = options.get('remove_original_nodes', True)
            ws_logger.info(f"Encapsulating top-level nodes into '{nodegraph_name}'...")
            nodes_encapsulated = utils.encapsulate_top_level_nodes(doc, nodegraph_name, remove_original)
            total_changes += nodes_encapsulated
            if nodes_encapsulated > 0:
                ws_logger.info(f"Encapsulated {nodes_encapsulated} top-level nodes")
        
        # Set standard library
        doc.setDataLibrary(utils.get_standard_libraries())
        
        if options.get('add_geometry_streams', True):
            ws_logger.info("Adding explicit geometry streams...")
            try:
                implicit_nodes = utils.add_explicit_geometry_stream(doc)
                total_changes += implicit_nodes
                if implicit_nodes > 0:
                    ws_logger.info(f"Added {implicit_nodes} implicit geometry nodes")
            except Exception as e:
                ws_logger.warning(f"Failed to add explicit geometry streams: {str(e)}")
        
        # Validate the processed document
        valid, errors = doc.validate()
        if not valid:
            ws_logger.warning(f"Validation errors after preprocessing: {errors}")
        else:
            ws_logger.info("Preprocessed document is valid")
        
        # Generate output filename
        input_dir = os.path.dirname(input_path)
        input_name = os.path.splitext(os.path.basename(input_path))[0]
        output_path = os.path.join(input_dir, f"{input_name}_preprocessed.mtlx")
        
        # Save the preprocessed document
        doc.setDataLibrary(None)  # Remove library before saving
        try:
            ws_logger.info(f"Saving preprocessed document to: {output_path}")
            success = utils.write_document(doc, output_path)
            
            if not success:
                # Try to get more specific error information
                try:
                    mx.writeToXmlFile(doc, output_path)
                    success = True
                    ws_logger.info("Successfully wrote file using direct MaterialX call")
                except Exception as write_error:
                    ws_logger.error(f"Failed to write MaterialX file: {str(write_error)}")
                    success = False
        except Exception as e:
            ws_logger.error(f"Error during file save: {str(e)}")
            success = False
        
        if success:
            # Read the output file content
            ws_logger.info(f"Preprocessed file saved to: {output_path}")
            with open(output_path, 'r', encoding='utf-8') as f:
                output_content = f.read()
            
            emit('preprocess_complete', {
                'success': True,
                'output_path': output_path,
                'output_content': output_content,
                'total_changes': total_changes,
                'message': f'Preprocessing completed with {total_changes} changes'
            })
        else:
            emit('error', {'message': 'Failed to save preprocessed file'})
            
    except Exception as e:
        emit('error', {'message': f'Error during preprocessing: {str(e)}'})

@socketio.on('convert_to_usd')
def handle_convert_to_usd(data):
    """Handle MaterialX to USD conversion"""
    try:
        session_id = request.sid
        ws_logger = WebSocketLogger(session_id)
        
        input_path = data.get('input_path', '')
        options = data.get('options', {})
        use_custom = options.get('use_custom_converter', True)
        
        if not os.path.exists(input_path):
            emit('error', {'message': 'Input file not found'})
            return
        
        emit('operation_started', {'type': 'convert', 'message': 'Starting MaterialX to USD conversion...'})
        
        # Generate output filename
        input_dir = os.path.dirname(input_path)
        input_name = os.path.splitext(os.path.basename(input_path))[0]
        output_path = os.path.join(input_dir, f"{input_name}.usda")
        
        # Set up scene assets paths
        data_dir = os.path.join(os.path.dirname(__file__), 'data')
        shaderball_path = os.path.join(data_dir, 'shaderball.usda') if options.get('add_geometry', True) else None
        environment_path = os.path.join(data_dir, 'san_giuseppe_bridge.hdr') if options.get('add_environment', True) else None
        camera_path = os.path.join(data_dir, 'camera.usda') if options.get('add_camera', True) else None
        
        # Ensure asset files exist, fallback to None if not found
        if shaderball_path and not os.path.exists(shaderball_path):
            ws_logger.warning(f"Geometry file not found: {shaderball_path}")
            shaderball_path = None
        if environment_path and not os.path.exists(environment_path):
            ws_logger.warning(f"Environment file not found: {environment_path}")
            environment_path = None
        if camera_path and not os.path.exists(camera_path):
            ws_logger.warning(f"Camera file not found: {camera_path}")
            camera_path = None
        
        if use_custom:
            ws_logger.info("Using complete MaterialX to USD converter with scene setup...")
            # Use the complete conversion method that includes geometry, lights, and camera
            stage, materials, geom_prim, light_prim, camera_prim = usd_converter.mtlx_to_usd(
                input_path, 
                shaderball_path, 
                environment_path, 
                None,  # material_file_path
                camera_path,
                use_custom=True
            )
            
            if stage:
                # Set required validation attributes
                usd_converter.set_required_validation_attributes(stage)
                
                # Export the stage
                stage.GetRootLayer().Export(output_path)
                ws_logger.info(f"USD stage exported to: {output_path}")
                
                # Log what was added
                if materials:
                    ws_logger.info(f"Added {len(materials)} materials to the scene")
                if geom_prim:
                    ws_logger.info(f"Added geometry: {geom_prim.GetPath()}")
                if light_prim:
                    ws_logger.info(f"Added environment light: {light_prim.GetPath()}")
                if camera_prim:
                    ws_logger.info(f"Added camera: {camera_prim.GetPath()}")
            else:
                emit('error', {'message': 'Failed to create USD stage'})
                return
        else:
            ws_logger.info("Using built-in USD MaterialX conversion...")
            # Use built-in USD conversion
            try:
                from pxr import Usd
                stage = Usd.Stage.Open(input_path)
                if stage:
                    usd_converter.set_required_validation_attributes(stage)
                    stage.GetRootLayer().Export(output_path)
                    ws_logger.info(f"USD stage exported to: {output_path}")
                else:
                    raise Exception("Failed to open MaterialX file as USD stage")
            except Exception as e:
                emit('error', {'message': f'Built-in conversion failed: {str(e)}'})
                return
        
        # Validate the output if requested
        if options.get('validate_output', True):
            ws_logger.info("Validating output USD file...")
            try:
                errors, warnings, failed_checks = usd_converter.validate_stage(output_path, False)
                if errors or warnings or failed_checks:
                    validation_msg = f"Validation completed with issues. Errors: {len(errors)}, Warnings: {len(warnings)}, Failed checks: {len(failed_checks)}"
                    ws_logger.warning(validation_msg)
                else:
                    ws_logger.info("USD file validation passed")
            except Exception as e:
                ws_logger.warning(f"Validation failed: {str(e)}")
        
        # Read the output file content
        try:
            with open(output_path, 'r', encoding='utf-8') as f:
                output_content = f.read()
        except Exception:
            output_content = "Could not read output file content"
        
        emit('convert_complete', {
            'success': True,
            'output_path': output_path,
            'output_content': output_content,
            'message': 'Conversion to USD completed successfully'
        })
        
    except Exception as e:
        emit('error', {'message': f'Error during USD conversion: {str(e)}'})

@socketio.on('cleanup_session')
def handle_cleanup_session(data):
    """Clean up temporary files for a session"""
    try:
        temp_dir = data.get('temp_dir', '')
        if temp_dir and os.path.exists(temp_dir):
            shutil.rmtree(temp_dir, ignore_errors=True)
            emit('cleanup_complete', {'message': 'Session cleaned up successfully'})
    except Exception as e:
        emit('error', {'message': f'Error during cleanup: {str(e)}'})

if __name__ == '__main__':
    # Ensure templates directory exists
    os.makedirs(template_dir, exist_ok=True)
    
    print("Starting MaterialX Web Application...")
    print(f"Templates directory: {template_dir}")
    print("Open your browser and navigate to: http://localhost:5000")
    socketio.run(app, debug=True, host='0.0.0.0', port=5000)
