import os
import re
import argparse
import cv2
import numpy as np

def extract_number(filename):
    """Extract the number from the filename."""
    match = re.search(r'\d+', filename)
    return int(match.group()) if match else 0

def concatenate_images(image_paths, output_height):
    """Concatenate images left to right, resizing to the specified height."""
    images = [cv2.imread(img) for img in image_paths]

    # Get image height of images[0]
    if not images:
        print("No images found in the folder")
        return None, 0, 0
    
    image_height = images[0].shape[0]
    if output_height == 0:
        output_height = image_height
    
    # Resize images to have the same height while maintaining aspect ratio
    resized_images = []
    min_number = extract_number(image_paths[0])
    max_number = extract_number(image_paths[-1])
    for img in images:
        aspect_ratio = img.shape[1] / img.shape[0]  # width / height
        new_width = int(output_height * aspect_ratio)
        resized_img = cv2.resize(img, (new_width, output_height))
        resized_images.append(resized_img)
    
    # Concatenate images horizontally
    concatenated_image = np.hstack(resized_images)
    
    return concatenated_image, min_number, max_number

def main(image_folder, output_height, output_filename):
    """Main function to read images, concatenate them, and save the result."""
    # Get list of image files in the folder
    image_files = [os.path.join(image_folder, f) for f in os.listdir(image_folder) 
                   if f.endswith(('.png', '.jpg', '.jpeg', '.bmp', '.gif'))]
    
    # Sort images by the number in their filename
    image_files.sort(key=extract_number)
    
    # Concatenate images
    concatenated_image, min_number, max_number = concatenate_images(image_files, output_height)
    
    # Save the result
    if not output_filename:
        # Get first image name and last image name
        first_image_name = os.path.basename(image_files[0])
        # replace number with min_number_max_number
        last_image_name = re.sub(r'\d+', f"{min_number}_{max_number}", first_image_name)
        output_filename = os.path.join(image_folder, last_image_name)        

    cv2.imwrite(output_filename, concatenated_image)
    print(f"Concatenated image saved as {output_filename}")

if __name__ == "__main__":
    # Set up argument parser
    parser = argparse.ArgumentParser(description="Concatenate images left to right based on numbers in filenames.")
    parser.add_argument("image_folder", type=str, help="Path to the folder containing images")
    parser.add_argument("-y", "--output_height", type=int, default=0, help="Height of the output image")
    parser.add_argument("-o", "--output_filename", default="", type=str, help="Filename for the output image")
    
    # Parse arguments
    args = parser.parse_args()
    
    # Call main function
    main(args.image_folder, args.output_height, args.output_filename)
