from pxr import UsdRender, Usd, UsdGeom, Gf, UsdAppUtils
import os
import sys


def SetupOpenGLContext(width=100, height=100):
    from PySide6.QtOpenGLWidgets import QOpenGLWidget
    from PySide6.QtOpenGL import QOpenGLFramebufferObject
    from PySide6.QtOpenGL import QOpenGLFramebufferObjectFormat
    from PySide6.QtCore import QSize
    from PySide6.QtGui import QOffscreenSurface
    from PySide6.QtGui import QOpenGLContext
    from PySide6.QtGui import QSurfaceFormat
    from PySide6.QtWidgets import QApplication

    application = QApplication(sys.argv)

    glFormat = QSurfaceFormat()
    glFormat.setSamples(4)

    glWidget = QOffscreenSurface()
    glWidget.setFormat(glFormat)
    glWidget.create()

    glWidget._offscreenContext = QOpenGLContext()
    glWidget._offscreenContext.setFormat(glFormat)
    glWidget._offscreenContext.create()

    glWidget._offscreenContext.makeCurrent(glWidget)

    glFBOFormat = QOpenGLFramebufferObjectFormat()
    glWidget._fbo = QOpenGLFramebufferObject(QSize(1, 1), glFBOFormat)
    glWidget._fbo.bind()

    return glWidget


# Get the stage and camera
stage = Usd.Stage.Open("./examples/test_grid.usda")
# Find first camera in the stage
camera = None
for prim in stage.Traverse():
    # Check if the prim is a UsdGeomCamera
    if prim.IsA(UsdGeom.Camera):
        camera = UsdGeom.Camera(prim)
        break

#camera = UsdGeom.Camera(stage.GetPrimAtPath("/Camera"))
if not camera:
    print("No camera found in the stage")
    sys.exit(1)

# anim_length = stage.GetEndTimeCode()
anim_length = 1

# Create a renderer prim
render_prim = UsdGeom.Xform.Define(stage, "/Render")

horiz_ap = int(camera.GetHorizontalApertureAttr().Get())
vert_ap = int(camera.GetVerticalApertureAttr().Get())

#print(f"Camera resolution: {horiz_ap} x {vert_ap}")

# Camera resolution is the product of the apertures
#cam_res = horiz_ap * vert_ap

# Camera aspect ratio is horizontal : vertical or the apertures
#cam_asp = horiz_ap / vert_ap

# Define the renderer settings object
render_base = UsdRender.Settings(render_prim)

# Add a bunch of rendering parameters
render_base.CreateResolutionAttr().Set(Gf.Vec2i([horiz_ap, vert_ap]))
render_base.CreateCameraRel().AddTarget("/Camera")

GPU = True

if GPU:
    glWidget = SetupOpenGLContext(100, 100)    

renderer = UsdAppUtils.rendererArgs.GetPluginIdFromArgument("GL")
rs_prim_path = stage.SetMetadata("renderSettingsPrimPath",
                                 "/Render")

frame_recorder = UsdAppUtils.FrameRecorder(renderer, GPU)
frame_recorder.SetComplexity(1)  # 1 is the lowest
frame_recorder.SetCameraLightEnabled(False)
frame_recorder.SetDomeLightVisibility(True)
frame_recorder.SetImageWidth(512)
#frame_recorder.SetColorCorrectionMode()
#frame_recorder.SetClearColor(Gf.Vec4f(0.1, 0.8, 0.8, 1.0))  # RGBA

frame_recorder.SetRendererPlugin(renderer)
#for frame in range(int(anim_length)):
#    frame_recorder.Record(stage, camera, frame, f"./test{frame}.png")


#frame_recorder.Record(stage, camera, 0, f"./test.png")
