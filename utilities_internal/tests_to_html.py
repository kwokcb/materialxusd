#!/usr/bin/python

import sys
import os
import datetime
import argparse
import numpy as np
import time

try:
    # Install OpenCV to enable image differencing and statistics.
    import cv2
    #import OpenImageIO as oiio
    import matplotlib.pyplot as plt
    DIFF_ENABLED = True
except Exception:
    DIFF_ENABLED = False

def save_histogram_difference(image1Path, image2Path, histDiffPath):
    # Read images
    image1 = cv2.imread(image1Path)
    image2 = cv2.imread(image2Path)

    if image1 is None or image2 is None:
        print("Error reading one or both images.")
        return None

    # Convert to HSV color space (better for histogram analysis)
    image1_hsv = cv2.cvtColor(image1, cv2.COLOR_BGR2HSV)
    image2_hsv = cv2.cvtColor(image2, cv2.COLOR_BGR2HSV)

    # Define colors for each channel (H, S, V)
    colors = ['r', 'g', 'b']
    channels = ['Hue', 'Saturation', 'Value']

    # Create the figure
    plt.figure(figsize=(8, 6))

    for i, col in enumerate(colors):
        # Compute histograms
        hist1 = cv2.calcHist([image1_hsv], [i], None, [256], [0, 256])
        hist2 = cv2.calcHist([image2_hsv], [i], None, [256], [0, 256])

        # Normalize histograms
        hist1 = cv2.normalize(hist1, hist1).flatten()
        hist2 = cv2.normalize(hist2, hist2).flatten()

        # Compute absolute difference
        hist_diff = np.abs(hist1 - hist2)

        # Plot histogram difference
        plt.plot(hist_diff, color=col, label=f'{channels[i]} Difference', alpha=0.7)

    plt.title(f'Histogram Difference Comparison')
    plt.xlabel('Pixel Value')
    plt.ylabel('Difference (Normalized)')
    plt.legend()

    # Save the histogram difference image
    plt.savefig(histDiffPath)
    plt.close()  # Close plot to free memory

    return histDiffPath

def save_overlayed_histogram(image1Path, image2Path, histPath):
    # Read images
    image1 = cv2.imread(image1Path)
    image2 = cv2.imread(image2Path)

    if image1 is None or image2 is None:
        print("Error reading one or both images.")
        return None

    # Convert to HSV color space
    image1_hsv = cv2.cvtColor(image1, cv2.COLOR_BGR2HSV)
    image2_hsv = cv2.cvtColor(image2, cv2.COLOR_BGR2HSV)

    # Define colors for each channel (H, S, V)
    colors = ['r', 'g', 'b']
    channels = ['Hue', 'Saturation', 'Value']

    # Create the figure
    plt.figure(figsize=(8, 6))

    for i, col in enumerate(colors):
        # Compute histograms
        hist1 = cv2.calcHist([image1_hsv], [i], None, [256], [0, 256])
        hist2 = cv2.calcHist([image2_hsv], [i], None, [256], [0, 256])

        # Normalize histograms for fair comparison
        hist1 = cv2.normalize(hist1, hist1).flatten()
        hist2 = cv2.normalize(hist2, hist2).flatten()

        # Plot both histograms on the same graph
        plt.plot(hist1, color=col, linestyle='-', label=f'{channels[i]} - Image 1', alpha=0.7)
        plt.plot(hist2, color=col, linestyle='--', label=f'{channels[i]} - Image 2', alpha=0.7)

    plt.title(f'Overlayed Histogram Comparison')
    plt.xlabel('Pixel Value')
    plt.ylabel('Frequency (Normalized)')
    plt.legend()

    # Save the histogram comparison image
    plt.savefig(histPath)
    plt.close()  # Close plot to free memory

    return histPath


def compare_histograms(image1Path, image2Path):
    # Read images
    image1 = cv2.imread(image1Path)
    image2 = cv2.imread(image2Path)

    if image1 is None or image2 is None:
        print("Error reading images.")
        return None

    # Convert to HSV color space (better for histogram comparison)
    image1_hsv = cv2.cvtColor(image1, cv2.COLOR_BGR2HSV)
    image2_hsv = cv2.cvtColor(image2, cv2.COLOR_BGR2HSV)

    # Compute histograms for each channel (H, S, V)
    hist1 = cv2.calcHist([image1_hsv], [0, 1], None, [50, 60], [0, 180, 0, 256])
    hist2 = cv2.calcHist([image2_hsv], [0, 1], None, [50, 60], [0, 180, 0, 256])

    # Normalize histograms
    cv2.normalize(hist1, hist1, alpha=0, beta=1, norm_type=cv2.NORM_MINMAX)
    cv2.normalize(hist2, hist2, alpha=0, beta=1, norm_type=cv2.NORM_MINMAX)

    # Compare histograms using different metrics
    methods = {
        "Correlation": cv2.HISTCMP_CORREL,
        "Chi-Square": cv2.HISTCMP_CHISQR,
        "Intersection": cv2.HISTCMP_INTERSECT,
        "Bhattacharyya": cv2.HISTCMP_BHATTACHARYYA
    }

    results = {name: cv2.compareHist(hist1, hist2, method) for name, method in methods.items()}

    return results

def computeDiff_OIIO(image1Path, image2Path, imageDiffPath):
    try:
        # Remove the diff image if it already exists
        if os.path.exists(imageDiffPath):
            os.remove(imageDiffPath)

        # Check if input images exist
        if not os.path.exists(image1Path):
            print("Image diff input missing: " + image1Path)
            return

        if not os.path.exists(image2Path):
            print("Image diff input missing: " + image2Path)
            return

        # Load images using OpenImageIO (no reshaping, directly as NumPy arrays)
        image1 = oiio.ImageInput.open(image1Path)
        image2 = oiio.ImageInput.open(image2Path)

        if not image1 or not image2:
            print("Failed to load images.")
            return

        # Read the image data in a single call (as float)
        pixels1 = image1.read_image(format=oiio.FLOAT)
        pixels2 = image2.read_image(format=oiio.FLOAT)

        image1.close()
        image2.close()

        # Directly access the image specifications
        spec1 = image1.spec()
        spec2 = image2.spec()

        # Ensure images have the same dimensions
        if spec1.width != spec2.width or spec1.height != spec2.height:
            print("Image dimensions do not match.")
            return

        # Slice the arrays to ignore the alpha channel (keep only RGB)
        pixels1_rgb = pixels1[:, :, :3]  # Take the first 3 channels (RGB)
        pixels2_rgb = pixels2[:, :, :3]  # Take the first 3 channels (RGB)

        # Compute the absolute difference (using vectorized NumPy operations)
        diff = np.abs(pixels1_rgb - pixels2_rgb)

        # Save the difference image
        out_spec = oiio.ImageSpec(spec1.width, spec1.height, 3, oiio.FLOAT)
        out_image = oiio.ImageOutput.create(imageDiffPath)
        if out_image:
            out_image.open(imageDiffPath, out_spec)
            out_image.write_image(diff)
            out_image.close()
        else:
            print("Failed to write difference image.")

        # Compute normalized RMS error using vectorized NumPy operations
        normalized_rms = np.sqrt(np.mean(diff ** 2)) / (3.0 * 1.0)

        return normalized_rms

    except Exception as e:
        print(f"Error during image comparison: {e}")
        return


def computeDiff(image1Path, image2Path, imageDiffPath):
    try:
        # Remove the diff image if it already exists
        if os.path.exists(imageDiffPath):
            os.remove(imageDiffPath)

        # Check if input images exist
        if not os.path.exists(image1Path):
            print("Image diff input missing: " + image1Path)
            return

        if not os.path.exists(image2Path):
            print("Image diff input missing: " + image2Path)
            return

        # Load images using OpenCV
        image1 = cv2.imread(image1Path)
        image2 = cv2.imread(image2Path)

        # Ensure images were loaded successfully
        if image1 is None or image2 is None:
            print("Failed to load images.")
            return

        # Convert images to RGB (OpenCV loads images in BGR by default)
        image1 = cv2.cvtColor(image1, cv2.COLOR_BGR2RGB)
        image2 = cv2.cvtColor(image2, cv2.COLOR_BGR2RGB)

        # Compute the absolute difference between the two images
        diff = cv2.absdiff(image1, image2)

        # Save the difference image
        cv2.imwrite(imageDiffPath, cv2.cvtColor(diff, cv2.COLOR_RGB2BGR))

        # Compute normalized RMS error
        normalized_rms = np.sqrt(np.mean(diff**2))  / (3.0 * 255.0)

        return normalized_rms

    except Exception as e:
        # Clean up and print error message
        if os.path.exists(imageDiffPath):
            os.remove(imageDiffPath)
        print("Failed to create image diff between: " + image1Path + ", " + image2Path)
        print(f"Error: {e}")

def main(args=None):

    parser = argparse.ArgumentParser()
    parser.add_argument('-i1', '--inputdir1', dest='inputdir1', action='store', help='Input directory', default=".")
    parser.add_argument('-i2', '--inputdir2', dest='inputdir2', action='store', help='Second input directory', default="")
    parser.add_argument('-i3', '--inputdir3', dest='inputdir3', action='store', help='Third input directory', default="")
    parser.add_argument('-o', '--outputfile', dest='outputfile', action='store', help='Output file name', default="tests.html")
    parser.add_argument('-d', '--diff', dest='CREATE_DIFF', action='store_true', help='Perform image diff', default=False)
    parser.add_argument('-t', '--timestamp', dest='ENABLE_TIMESTAMPS', action='store_true', help='Write image timestamps', default=False)
    parser.add_argument('-w', '--imagewidth', type=int, dest='imagewidth', action='store', help='Set image display width', default=256)
    parser.add_argument('-ht', '--imageheight', type=int, dest='imageheight', action='store', help='Set image display height', default=256)
    parser.add_argument('-cp', '--cellpadding', type=int, dest='cellpadding', action='store', help='Set table cell padding', default=0)
    parser.add_argument('-tb', '--tableborder', type=int, dest='tableborder', action='store', help='Table border width. 0 means no border', default=3)
    parser.add_argument('-l1', '--lang1', dest='lang1', action='store', help='First target language for comparison. Default is glsl', default="glsl")
    parser.add_argument('-l2', '--lang2', dest='lang2', action='store', help='Second target language for comparison. Default is osl', default="osl")
    parser.add_argument('-l3', '--lang3', dest='lang3', action='store', help='Third target language for comparison. Default is empty', default="")

    args = parser.parse_args(args)

    fh = open(args.outputfile,"w+")

    html_content = '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>MaterialX RTS Comparison</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.1/dist/css/bootstrap.min.css" rel="stylesheet">
        <style>
            .img-fluid { max-width: 100%; height: auto; }
            .image-name { text-align: center; margin-top: 10px; font-size: 11px; }
        </style>
    </head>
    <body data-bs-theme="dark" class="p-4">
        <h2 class="text-center">MaterialX RTS Comparison</h2>
        <div class="p-2 container-fluid border rounded-4" style="__SCROLL_STYLE__">
    '''
    fh.write(html_content)    

    if args.inputdir1 == ".":
        args.inputdir1 = os.getcwd()

    if args.inputdir2 == ".":
        args.inputdir2 = os.getcwd()
    elif args.inputdir2 == "":
        args.inputdir2 = args.inputdir1

    if args.inputdir3 == ".":
        args.inputdir3 = os.getcwd()
    elif args.inputdir3 == "":
        args.inputdir3 = args.inputdir1

    useThirdLang = args.lang3
    
    if useThirdLang:
        fh.write("<b>" + args.lang1 + " (in: " + args.inputdir1 + ") vs "+ args.lang2 + " (in: " + args.inputdir2 + ") vs "+ args.lang3 + " (in: " + args.inputdir3 + ")</b>\n")
    else:
        fh.write("<b>" + args.lang1 + " (in: " + args.inputdir1 + ") vs "+ args.lang2 + " (in: " + args.inputdir2 + ")</b>\n")

    if not DIFF_ENABLED and args.CREATE_DIFF:
        print("--diff argument ignored. Diff utility not installed. Install OpenCV using 'pip install opencv-python'.")

    # Remove potential trailing path separators
    if args.inputdir1[-1:] == '/' or args.inputdir1[-1:] == '\\':
        args.inputdir1 = args.inputdir1[:-1]
    if args.inputdir2[-1:] == '/' or args.inputdir2[-1:] == '\\':
        args.inputdir2 = args.inputdir2[:-1]
    if args.inputdir3[-1:] == '/' or args.inputdir3[-1:] == '\\':
        args.inputdir3 = args.inputdir3[:-1]

    # Get all source files
    langFiles1 = []
    langPaths1 = []
    for subdir, _, files in os.walk(args.inputdir1):
        for curFile in files:
            if curFile.endswith(args.lang1 + ".png"):
                langFiles1.append(curFile)
                langPaths1.append(subdir)

    # Get all destination files, matching source files
    langFiles2 = []
    langPaths2 = []
    langFiles3 = []
    langPaths3 = []
    preFixLen: int = len(args.inputdir1) + 1  # including the path separator
    postFix: str = args.lang1 + ".png"
    for file1, path1 in zip(langFiles1, langPaths1):
        # Allow for just one language to be shown if source and dest are the same.
        # Otherwise add in equivalent name with dest language replacement if
        # pointing to the same directory 
        if args.inputdir1 != args.inputdir2 or args.lang1 != args.lang2:
            file2 = file1[:-len(postFix)] + args.lang2 + ".png"
            path2 = os.path.join(args.inputdir2, path1[len(args.inputdir1)+1:])
        else:
            file2 = ""
            path2 = None
        langFiles2.append(file2)
        langPaths2.append(path2)

        if useThirdLang:
            file3 = file1[:-len(postFix)] + args.lang3 + ".png"
            path3 = os.path.join(args.inputdir2, path1[len(args.inputdir1)+1:])
        else:
            file3 = ""
            path3 = None
        langFiles3.append(file3)
        langPaths3.append(path3)

    start_time = time.perf_counter()

    skippedComparisons = []    

    if langFiles1:
        curPath = ""
        for file1, file2, file3, path1, path2, path3 in zip(langFiles1, langFiles2, langFiles3, langPaths1, langPaths2, langPaths3):
                      
            fullPath1 = os.path.join(path1, file1) if file1 else None
            fullPath2 = os.path.join(path2, file2) if file2 else None
            fullPath3 = os.path.join(path3, file3) if file3 else None
            diffPath1 = diffPath2 = diffPath3 = None
            diffRms1 = diffRms2 = diffRms3 = None
            histPath1 = None
            histPath2 = None

            if not os.path.exists(fullPath1) or not os.path.exists(fullPath2):
                skippedComparisons.append((fullPath1, fullPath2))
                continue

            if curPath != path1:
                if curPath != "":
                    fh.write("</table>\n")
                fh.write("<p>" + os.path.normpath(path1) + ":</p>\n")
                fh.write("<table class='container-fluid'>\n")
                curPath = path1

            if file1 and file2 and DIFF_ENABLED and args.CREATE_DIFF:
                diffPath1 = fullPath1[0:-8] + "_" + args.lang1 + "-1_vs_" + args.lang2 + "-2_diff.png"
                diffRms1 = computeDiff(fullPath1, fullPath2, diffPath1)
                histPath1 = diffPath1[:-4] + "_hist.png"
                save_histogram_difference(fullPath1, fullPath2, histPath1)

            if useThirdLang and file1 and file3 and DIFF_ENABLED and args.CREATE_DIFF:
                diffPath2 = fullPath1[0:-8] + "_" + args.lang1 + "-1_vs_" + args.lang3 + "-3_diff.png"
                diffRms2 = computeDiff(fullPath1, fullPath3, diffPath2)
                #diffPath3 = fullPath1[0:-8] + "_" + args.lang2 + "-2_vs_" + args.lang3 + "-3_diff.png"
                #diffRms3 = computeDiff(fullPath2, fullPath3, diffPath3)
                histPath2 = diffPath2[:-4] + "_hist.png"
                save_histogram_difference(fullPath1, fullPath3, histPath2)

            def prependFileUri(filepath: str) -> str:
                if os.path.isabs(filepath):
                    return 'file:///' + filepath
                else:
                    return filepath

            fh.write("<tr class='row'>\n")
            if fullPath1:
                fh.write("<td class='col-sm'><img width=100% src='" + prependFileUri(fullPath1) + "' loading='lazy' style='background-color:rgb(80,80,80);'/></td>\n")
            if fullPath2:
                fh.write("<td class='col-sm'><img width=100% src='" + prependFileUri(fullPath2) + "' loading='lazy' style='background-color:rgb(80,80,80);'/></td>\n")
            if fullPath3:
                fh.write("<td class='col-sm'><img width=100% src='" + prependFileUri(fullPath3) + "' loading='lazy' style='background-color:rgb(80,80,80);'/></td>\n")
            if diffPath1:
                fh.write("<td class='col-sm'>")
                fh.write("<img width=100% src='" + prependFileUri(diffPath1) + "' loading='lazy' style='background-color:rgb(80,80,80);'/>")
                if histPath1:
                    if diffPath2:
                        fh.write("<br><img width=100% src='" + prependFileUri(histPath1) + "' loading='lazy' style='background-color:rgb(80,80,80);'/>\n")
                    else:
                        fh.write("</td><td class='col-sm'><img width=100% src='" + prependFileUri(histPath1) + "' height='" + str(args.imageheight) + "' width='" + str(args.imagewidth*1.5) + "' loading='lazy' style='background-color:rgb(80,80,80);'/>\n")
                fh.write("</td>\n")
            if diffPath2:
                fh.write("<td class='col-sm'>")
                fh.write("<img width=100% src='" + prependFileUri(diffPath2) + "' loading='lazy' style='background-color:rgb(80,80,80);'/>")
                if histPath2:
                    fh.write("<br><img width=100% src='" + prependFileUri(histPath2) + "' loading='lazy' style='background-color:rgb(80,80,80);'/>\n")
                fh.write("</td>\n")
            #if diffPath3:
            #    fh.write("<td class='col-sm'><img width=100% src='" + prependFileUri(diffPath3) + "' loading='lazy' style='background-color:rgb(80,80,80);'/></td>\n")
            fh.write("</tr>\n")

            fh.write("<tr class='row'>\n")
            if fullPath1:
                fh.write("<td class='col-sm'>" + file1)
                if args.ENABLE_TIMESTAMPS and os.path.isfile(fullPath1):
                    fh.write("<br>(" + str(datetime.datetime.fromtimestamp(os.path.getmtime(fullPath1))) + ")")
                fh.write("</td>\n")
            if fullPath2:
                fh.write("<td class='col-sm'>" + file2)
                if args.ENABLE_TIMESTAMPS and os.path.isfile(fullPath2):
                    fh.write("<br>(" + str(datetime.datetime.fromtimestamp(os.path.getmtime(fullPath2))) + ")")
                fh.write("</td>\n")
            if fullPath3:
                fh.write("<td class='col-sm'>" + file3)
                if args.ENABLE_TIMESTAMPS and os.path.isfile(fullPath3):
                    fh.write("<br>(" + str(datetime.datetime.fromtimestamp(os.path.getmtime(fullPath3))) + ")")
                fh.write("</td>\n")
            if diffPath1:
                rms = " (RMS " + "%.5f" % diffRms1 + ")" if diffRms1 else ""
                fh.write("<td class='col-sm'>")
                fh.write("<p>" + args.lang1.upper() + " vs. " + args.lang2.upper() + "RMS: " + rms + "</p>\n")
                if not diffPath2 and histPath1:
                    fh.write("</td><td class='col-sm'>Histogram: " + args.lang1.upper() + " vs. " + args.lang2.upper() + "</p>\n")
                fh.write("</td>\n")
            if diffPath2:
                rms = " (RMS " + "%.5f" % diffRms2 + ")" if diffRms2 else ""
                fh.write("<td class='col-sm'>")
                fh.write("<p>" + args.lang1.upper() + " vs. " + args.lang3.upper() + "RMS: " + rms + "</p>\n")
                #if histPath2:
                #    fh.write("<p>Histogram: " + args.lang1.upper() + " vs. " + args.lang3.upper() + "</p>\n")
                fh.write("</td>\n")
            #if diffPath3:
            #    rms = " (RMS " + "%.5f" % diffRms3 + ")" if diffRms3 else ""
            #    fh.write("<td class='col-sm'>" + args.lang2.upper() + " vs. " + args.lang3.upper() + rms + "</td>\n")
            fh.write("</tr>\n")

    fh.write("</table>\n")

    if skippedComparisons:
        print(f"Skipped {len(skippedComparisons)} comparisons due to missing files")
        fh.write("<details><summary>Skipped Files</summary>\n")
        fh.write("<ol>")
        for skipped in skippedComparisons:
            fh.write(f"  <li>{skipped[0]} vs {skipped[1]} </li>\n")
        fh.write("</ol>")        
        fh.write("</details>\n")

    # Calculate elapsed time
    elapsed_time = time.perf_counter() - start_time
    print(f"Time spent: {elapsed_time:.4f} seconds")

    html_content = '''
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.1/dist/js/bootstrap.bundle.min.js"></script>
    </body>
    </html>
    '''
    fh.write(html_content)

    #fh.write("</body>\n")
    #fh.write("</html>\n")

if __name__ == "__main__":
    main(sys.argv[1:])
