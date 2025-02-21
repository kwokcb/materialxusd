import argparse
from pxr import Usd, UsdGeom, Gf, Sdf
from pxr.Usdviewq import usdviewApi

def capture_image(usd_file_path, output_image_path=None):
    # If no output image path is provided, replace the USD file extension with .png
    if output_image_path is None:
        output_image_path = usd_file_path.rsplit(".", 1)[0] + ".png"

    # Open the USD file
    stage = Usd.Stage.Open(usd_file_path)
    if not stage:
        raise Exception(f"Could not open USD file: {usd_file_path}")

    help(usdviewApi)

    # Create a usdview API instance
    usdview_api = usdviewApi.UsdviewApi(stage)
    #print('viewport size', usdviewApi.viewportSize())

    qimage = usdviewApi.GrabViewportShot()

    # Save the image to the output path
    qimage.save(output_image_path, "PNG")

    #help(usdview_api)

    # Access the main window and viewport
    #main_window = usdview_api.qMainWindow
    #viewport = main_window._stageView

    # Save the current view as an image
    #viewport.saveScreenShot(output_image_path)

    print(f"Image saved to {output_image_path}")

if __name__ == "__main__":
    # Set up command-line argument parsing
    parser = argparse.ArgumentParser(description="Capture an image from a USD file using usdview.")
    parser.add_argument("usd_file", help="Path to the input USD file.")
    parser.add_argument("--output", "-o", help="Path to the output image file. Default: <input_file>.png")

    # Parse arguments
    args = parser.parse_args()

    # Call the function to capture the image
    capture_image(args.usd_file, args.output)