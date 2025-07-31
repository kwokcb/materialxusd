
"""
@file mtlxdownload.py
@brief MaterialX release downloader command for fetching releases and libraries from GitHub.
"""
import os
import requests
import zipfile
import argparse
import json

import MaterialXDownloader

def main() -> None:
    """Main function to parse command line arguments and execute the MaterialX release downloader.
    
    @return: None
    """
    parser = argparse.ArgumentParser(description="Download MaterialX releases and libraries.")
    parser.add_argument("--version", type=str, default="", help="Specify the version of MaterialX to download. If not specified, the latest releases will be downloaded. e.g. 1.39.3")
    parser.add_argument("--n", type=int, default=1, help="Number of latest releases to download (default: 15)")
    parser.add_argument("--version-count", type=int, default=15, help="Number of latest releases to download (default: 15)")
    parser.add_argument("--by-count", action='store_true', help="Download the latest N releases instead of a specific version")
    parser.add_argument("--download-dir", type=str, default="downloaded_release_libraries", help="Directory to save downloaded files (default: 'downloaded_release_libraries')")
    parser.add_argument("-l", "--libraries", action='store_true', help="Download the standard 'libraries' folder only from the releases")
    parser.add_argument("-f", "--filter", type=str, nargs='*', default=["libraries"], help="Filter to specify which folders to extract from the release zip files (default: ['libraries'])")
    parser.add_argument("-t", "--target", type=str, nargs='*', default=["Windows"], help="Target file names to filter the assets (default: ['Windows'])")

    args = parser.parse_args()
    
    downloader = MaterialXDownloader.MaterialXDownloader()
    downloader.download_directory = args.download_dir
    downloader.chunk_size = 65536*65536*16  # Set chunk size to 16 MB
    downloader.version_count = args.version_count  # Set the number of releases to download

    if len(args.version) > 1:
        version_parts = list(map(int, args.version.split('.')))
        if len(version_parts) == 3:
            downloader.version_number = version_parts
        else:
            raise ValueError("Version must be in the format 'major.minor.patch' e.g. 1.39.3")
        
    #download_releases()
    by_count = args.by_count    
    if args.libraries:
        print("Downloading libraries only...")
        downloader.remove_zip_after_extract = False
        if args.filter:
            print(f"Using folder filter: {args.filter}")
            downloader.folder_filter = args.filter
        downloader.download_libraries(by_count)
    else:
        print("Downloading full releases...")
        if args.target:
            downloader.target_file_names = args.target
        downloader.folder_filter = []
        downloader.download_releases(by_count)

if __name__ == "__main__":
    main()
