import os
import argparse

mtlx_version = None
try:
    import MaterialX as mx
    mtlx_version = mx.getVersionString()
    #print(f"MaterialX version: {mtlx_version}")
except ImportError:
    mtlx_version = None

usd_version = None
try:
    from pxr import Usd
    usd_version = Usd.GetVersion()
    usd_version = f"{usd_version[0]}.{usd_version[1]}.{usd_version[2]}"
    #print(f"USD Version: {usd_version}")
except ImportError:
    usd_version = None

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description="Generate an HTML file with a Bootstrap grid of PNG images.")
    parser.add_argument('input_folder', type=str, help="Path to the folder containing PNG images.")
    parser.add_argument('-o', '--output_file', type=str, default='usd_mtlx_image_gallery.html', help="Path to the output HTML file.")
    parser.add_argument('-c', '--columns', type=int, default=4, help="Number of columns in the grid.")
    parser.add_argument('-sc', '--scroll', action="store_true", help="Enable scrolling for the gallery.")
    parser.add_argument('-hd', '--header', type=str, default='MaterialX RTS / USD Render Gallery', help="Title of the HTML page.")
    parser.add_argument('-r', '--root', type=str, default='https://kwokcb.github.io/materialxusd/tests', help="Root directory for the images.")
    args = parser.parse_args()
    print(args)

    # Directory to scan for PNG files
    image_directory = args.input_folder

    # Output HTML file
    output_html_file = args.output_file

    # Scan for PNG files in all subdirectories
    png_files = []
    for root, _, files in os.walk(image_directory):
        for file in files:
            if file.endswith('glslfx.png'):
                root = root.replace("\\", "/")
                root = root.replace("./", args.root + "/")
                full_path = os.path.join(root, file)
                #print("Add file: ", full_path)
                png_files.append(full_path)

    # Generate HTML content
    html_content = '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>__TITLE__</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.1/dist/css/bootstrap.min.css" rel="stylesheet">
        <style>
            .img-fluid { max-width: 100%; height: auto; }
            .image-name { text-align: center; margin-top: 10px; font-size: 11px; }
        </style>
    </head>
    <body data-bs-theme="dark" class="p-4">
    <!--Start-->
        <h2 class="text-center">__TITLE__</h2>
        <div class="p-2 container-fluid border rounded-4" style="__SCROLL_STYLE__">
            <div class="row">
    '''
    print(args.header)
    html_content = html_content.replace('__TITLE__', args.header)
    scroll_style = ''
    if args.scroll:
        scroll_style = 'max-height: 800px; overflow-y: auto;'
    html_content = html_content.replace('__SCROLL_STYLE__', scroll_style)

    # Add images to the HTML content
    images_per_row = min(args.columns, 12)
    column_width = int(12 / images_per_row)
    for i, png_file in enumerate(png_files):
        if i % images_per_row == 0 and i != 0:
            html_content += '</div><div class="row">\n'  # Start a new row every 6 images
        file_name = os.path.basename(png_file)
        html_content += f'''
            <div class="col-md-{column_width}">
                <img src="{png_file}" class="img-fluid" alt="{file_name}" loading="lazy">
                <div class="image-name">{file_name}</div>
            </div>
        '''

    # Close the HTML content
    html_content += '''
            </div>
        </div>
    <!--End-->
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.1/dist/js/bootstrap.bundle.min.js"></script>
    </body>
    </html>
    '''

    # Write the HTML content to the output file
    with open(output_html_file, 'w') as file:
        file.write(html_content)

    print(f"HTML file '{output_html_file}' generated successfully with {len(png_files)} images.")

if __name__ == "__main__":
    main()