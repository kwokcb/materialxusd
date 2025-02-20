import argparse
import os

def main():
    parser = argparse.ArgumentParser(description="Render a file")
    parser.add_argument("file", help="The file to render")
    parser.add_argument("--output", help="The output file")
    parser.add_argument("--width", type=int, help="The width of the output file", default=512)
    parser.add_argument("--showBackground", type=bool, help="Show the background", default=False)

    print("Rendering file")

    # Run usdrecord with arguments
    args = parser.parse_args()
    cmd = "usdrecord " + args.file + " --imageWidth " + str(args.width)
    output_file = args.file.rsplit(".", 1)[0] + ".png"
    if args.output:
        output_file = args.output        
    cmd += " " + output_file
    if args.showBackground:
        cmd += " --enableDomeLightVisibility"

    print("Running command: ", cmd)
    os.system(cmd)

if __name__ == "__main__":
    main()