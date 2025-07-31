import os
import requests
import zipfile
import argparse

class MaterialXReleaseDownloader:
    """Class to handle downloading MaterialX releases and libraries."""

    def __init__(self):
        self.GITHUB_TOKEN = None
        self.REPO_OWNER = "AcademySoftwareFoundation" 
        self.REPO_NAME = "MaterialX"
        self.version_count = 15  # Number of latest releases to download
        self.version_number = [1, 39, 4]  # Default version to download
        self.DOWNLOAD_DIR = "downloaded_release_libraries"  # Directory to save downloaded files
        self.TARGET_FILE_NAMES = ["Windows"] # Default to Windows assets
        #self.GET_FIRST = True
        self.CHUNK_SIZE = (65536*65536*16) # 16 MB chunk size for downloading  
        self.remove_zip_after_extract = False  # Whether to remove the zip file after extraction
        self.folder_filter = ["libraries"] 

        # GitHub API URL for releases
        self.RELEASES_API_URL = f"https://api.github.com/repos/{self.REPO_OWNER}/{self.REPO_NAME}/releases"

    def set_folder_filter(self, folder_filter):
        """Set the folder filter for extracting specific folders from the downloaded zip files."""
        self.folder_filter = folder_filter

    def get_folder_filter(self):
        """Get the current folder filter."""
        return self.folder_filter

    def set_target_file_names(self, target_file_names):
        """Set the target file names to filter assets for downloading."""
        self.TARGET_FILE_NAMES = target_file_names

    def get_target_file_names(self):
        """Get the current target file names."""
        return self.TARGET_FILE_NAMES

    def set_download_directory(self, download_dir):
        """Set the directory where downloaded files will be saved."""
        self.DOWNLOAD_DIR = download_dir
        self.create_download_directory()
    
    def get_download_directory(self):
        """Get the current download directory."""
        return self.DOWNLOAD_DIR
    
    def set_chunk_size(self, chunk_size):
        """Set the chunk size for downloading files."""
        if chunk_size <= 0:
            raise ValueError("Chunk size must be a positive integer.")
        self.CHUNK_SIZE = chunk_size

    def get_chunk_size(self):
        """Get the current chunk size for downloading files."""
        return self.CHUNK_SIZE    
    
    def set_version_count(self, n):
        """Set the number of latest releases to download."""
        self.version_count = n

    def get_version_count(self):
        """Get the current number of latest releases to download."""
        return self.version_count
    
    def set_version_number(self, version_number):
        """Set the version number to download."""
        if isinstance(version_number, list) and len(version_number) == 3:
            self.version_number = version_number
        else:
            raise ValueError("Version number must be a list of three integers [major, minor, patch].")
        
    def get_version_number(self):
        """Get the current version number."""
        return self.version_number
    
    def get_version_string(self):
        """Get the version number as a string."""
        return ".".join(map(str, self.version_number))
    
    def create_download_directory(self):
        """Create the download directory if it doesn't exist."""
        os.makedirs(self.DOWNLOAD_DIR, exist_ok=True)   

    def download_file(self, url, dest_path):
        
        """Download a file from a given URL to the specified destination."""
        headers = {"Authorization": f"token {self.GITHUB_TOKEN}"} if self.GITHUB_TOKEN else {}
        response = requests.get(url, headers=headers, stream=True)
        response.raise_for_status()

        download_chunk_size = self.CHUNK_SIZE
        with open(dest_path, "wb") as file:
            for chunk in response.iter_content(chunk_size=download_chunk_size):
                #print(f"...Downloading {len(chunk)} bytes")
                print('*', end='', flush=True)  # Print a dot for each chunk downloaded
                file.write(chunk)
    
    def download_releases(self, by_count=True):
        """
        Download the assets of the latest N releases.
        """
        headers = {"Authorization": f"token {self.GITHUB_TOKEN}"} if self.GITHUB_TOKEN else {}
        response = requests.get(self.RELEASES_API_URL, headers=headers)
        response.raise_for_status()

        releases = response.json()
        index = 0
        version_string = None
        if not by_count:
            version_string = self.get_version_string()
        stop_search = False

        for release in releases:
            release_name = release["name"]
            
            # Look by version
            if version_string:
                if version_string in release_name:
                    stop_search = True
                else:
                    print(f"Skipping release: {release_name} (does not match version string {version_string})")
                    continue            

            asset_urls = []
            asset_names = []
            tag_names = []
            print(f"Checking assets for release: {release_name}. Tag: {release['tag_name']}")
            for asset in release["assets"]:
                asset_name = asset["name"]
                # Check if the asset name contains any of the target file names
                if any(target in asset_name for target in self.TARGET_FILE_NAMES):
                    print("- Found asset:", asset_name)
                    tag_names.append(release["tag_name"].replace(" ", "_").replace(".", "_"))
                    #asset_names.append(asset_name)
                    asset_url = asset["browser_download_url"]
                    asset_urls.append(asset_url)            

            # Sort asset_urls and tag_names by value of tag_names 
            asset_urls, tag_names = zip(*sorted(zip(asset_urls, tag_names), key=lambda x: x[1], reverse=True))
            #print(f"Sorted asset URLs and tag names: {asset_urls}\n, {tag_names}")
            for asset_url, tag_name in zip(asset_urls, tag_names):
                print(f"- Downloading {asset_name} from {asset_url}")
                dest_path = os.path.join(self.DOWNLOAD_DIR, tag_name + ".zip")
                self.download_file(asset_url, dest_path)
                print(f"Saved to {dest_path}")
            print(f"Finished checking assets for release: {release_name}")

            if by_count:
                if index >= self.version_count - 1:
                    stop_search = True
                index += 1

            if stop_search:
                break

    def download_libraries(self, by_count=True):
        """Download the 'Source code (zip)' for the latest N releases and 
        extract the standard 'libraries' folder
        """
        headers = {"Authorization": f"token {self.GITHUB_TOKEN}"} if self.GITHUB_TOKEN else {}
        response = requests.get(self.RELEASES_API_URL, headers=headers)
        response.raise_for_status()

        releases = response.json()
        index = 0
        version_string = None
        if not by_count:
            version_string = self.get_version_string()
        stop_search = False

        for release in releases:
            tag_name = release["tag_name"]
            release_name = release["name"]
            if version_string:
                if version_string not in release_name:
                    print(f"Skipping release: {release_name} (does not match version string {version_string})")
                    continue
                else:
                    stop_search = True

            print(f"Downloading 'Source code (zip)' for release: {release_name} (tag: {tag_name})")

            source_zip_url = f"https://github.com/{self.REPO_OWNER}/{self.REPO_NAME}/archive/refs/tags/{tag_name}.zip"
            dest_path = os.path.join(self.DOWNLOAD_DIR, f"{tag_name}.zip")
            self.download_file(source_zip_url, dest_path)
            print(f"\nSaved ZIP to {dest_path}")

            # Extract out the "libraries" folder from the zip file
            print(f"Extracing ZIP files from {dest_path} to {os.path.join(self.DOWNLOAD_DIR, tag_name)}")
            with zipfile.ZipFile(dest_path, 'r') as zip_ref:
                for file in zip_ref.namelist():
                    # Check file name against folder_filter strings
                    # if file in self.folder_filter then extract, or 
                    # extract if folder_filter is empty

                    if not self.folder_filter or any(folder in file for folder in self.folder_filter):
                    #if "libraries" in file and "resources" not in file:
                        zip_ref.extract(file, os.path.join(self.DOWNLOAD_DIR, tag_name))
                        print('+', end='', flush=True)  # Print a dot for each chunk downloaded
                       # print(f"Extracted {file} to {os.path.join(self.DOWNLOAD_DIR, tag_name)}")
                print("\nFinished extracting libraries folder from zip file.")

            # Optionally, remove the zip file after extraction
            if self.remove_zip_after_extract:
                os.remove(dest_path)
                print(f"Removed zip file: {dest_path}") 

            if by_count:
                if index >= self.version_count - 1:
                    stop_search = True
                index += 1
            
            if stop_search:
                break

def main():
    parser = argparse.ArgumentParser(description="Download MaterialX releases and libraries.")
    parser.add_argument("--version", type=str, default="", help="Specify the version of MaterialX to download. If not specified, the latest releases will be downloaded. e.g. 1.39.3")
    parser.add_argument("--n", type=int, default=1, help="Number of latest releases to download (default: 15)")
    parser.add_argument("--version-count", type=int, default=15, help="Number of latest releases to download (default: 15)")
    parser.add_argument("--by-count", action='store_true', help="Download the latest N releases instead of a specific version")
    parser.add_argument("--download-dir", type=str, default="downloaded_release_libraries", help="Directory to save downloaded files (default: 'downloaded_release_libraries')")
    parser.add_argument("-l", "--libraries", action='store_true', help="Download the standard 'libraries' folder only from the releases")

    args = parser.parse_args()
    
    downloader = MaterialXReleaseDownloader()
    downloader.set_download_directory(args.download_dir)
    downloader.set_chunk_size(65536*65536*16)  # Set chunk size to 16 MB
    downloader.set_version_count(args.version_count)  # Set the number of releases to download
    #downloader.set_target_file_names(["Windows"])  # Default to Windows assets
    if len(args.version) > 1:
        version_parts = list(map(int, args.version.split('.')))
        if len(version_parts) == 3:
            downloader.set_version_number(version_parts)
        else:
            raise ValueError("Version must be in the format 'major.minor.patch' e.g. 1.39.3")
        
    #download_releases()
    by_count = args.by_count    
    if args.libraries:
        downloader.set_folder_filter(["libraries"])
        print("Downloading libraries only...")
        downloader.download_libraries(by_count)
    else:
        downloader.set_folder_filter([])
        print("Downloading full releases...")
        downloader.download_libraries(by_count)

if __name__ == "__main__":
    main()
