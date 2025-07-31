
"""
@file MaterialXDownloader.py
@brief MaterialX release downloader utility for fetching releases and libraries from GitHub.
"""
import os
import requests
import zipfile
import argparse
import json

class MaterialXDownloader:
    """Class to handle downloading MaterialX releases and libraries."""

    def __init__(self) -> None:
        """Initialize the MaterialX release downloader with default settings.
        
        Sets up default configuration for downloading MaterialX releases including
        version count, target file names, chunk size, and download directory.
        """
        self.GITHUB_TOKEN = None
        self.REPO_OWNER = "AcademySoftwareFoundation"
        self.REPO_NAME = "MaterialX"

        self._version_count = 15  # Number of latest releases to download
        self._version_number = [1, 39, 4]  # Default version to download
        self._download_directory = "downloaded_release_libraries"  # Directory to save downloaded files
        self._target_file_names = ["Windows"] # Default to Windows assets
        self._chunk_size = (65536*65536*16) # 16 MB chunk size for downloading  
        self._remove_zip_after_extract = False  # Whether to remove the zip file after extraction
        self._folder_filter = ["libraries"]        
        
        # GitHub API URL for releases
        self.RELEASES_API_URL = f"https://api.github.com/repos/{self.REPO_OWNER}/{self.REPO_NAME}/releases"

    def __setattr__(self, name: str, value) -> None:
        """Custom attribute setter with validation.
        
        @param name: The name of the attribute to set
        @param value: The value to set for the attribute
        @return: None
        """
        if name == 'chunk_size':
            if value <= 0:
                raise ValueError("Chunk size must be a positive integer.")
            super().__setattr__('_chunk_size', value)
        elif name == 'version_number':
            if isinstance(value, list) and len(value) == 3:
                super().__setattr__('_version_number', value)
            else:
                raise ValueError("Version number must be a list of three integers [major, minor, patch].")
        elif name == 'download_directory':
            super().__setattr__('_download_directory', value)
            if hasattr(self, 'create_download_directory'):
                self.create_download_directory()
        elif name in ['version_count', 'target_file_names', 'folder_filter']:
            super().__setattr__(f'_{name}', value)
        else:
            super().__setattr__(name, value)

    def __getattr__(self, name: str):
        """Custom attribute getter for private attributes.
        
        @param name: The name of the attribute to get
        @return: The value of the requested attribute
        """
        if name in ['version_count', 'version_number', 'download_directory', 'target_file_names', 'chunk_size', 'folder_filter']:
            return getattr(self, f'_{name}')
        elif name == 'version_string':
            return ".".join(map(str, self._version_number))
        raise AttributeError(f"'{self.__class__.__name__}' object has no attribute '{name}'")

    def create_download_directory(self) -> None:
        """Create the download directory if it doesn't exist.
        
        @return: None
        """
        os.makedirs(self._download_directory, exist_ok=True)

    def download_file(self, url: str, dest_path: str) -> None:
        """Download a file from a given URL to the specified destination.
        
        @param url: The URL to download the file from
        @param dest_path: The local path where the file should be saved
        @return: None
        """
        headers = {"Authorization": f"token {self.GITHUB_TOKEN}"} if self.GITHUB_TOKEN else {}
        response = requests.get(url, headers=headers, stream=True)
        response.raise_for_status()

        download_chunk_size = self._chunk_size
        with open(dest_path, "wb") as file:
            for chunk in response.iter_content(chunk_size=download_chunk_size):
                #print(f"...Downloading {len(chunk)} bytes")
                print('*', end='', flush=True)  # Print a dot for each chunk downloaded
                file.write(chunk)

    def download_releases(self, by_count: bool = True) -> None:
        """Download the assets of the latest N releases.
        
        @param by_count: If True, download by count limit; if False, download specific version
        @return: None
        """
        headers = {"Authorization": f"token {self.GITHUB_TOKEN}"} if self.GITHUB_TOKEN else {}
        response = requests.get(self.RELEASES_API_URL, headers=headers)
        response.raise_for_status()

        releases = response.json()
        index = 0
        version_string = None
        if not by_count:
            version_string = self.version_string
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
                if any(target in asset_name for target in self._target_file_names):
                    print("- Found asset:", asset_name)
                    tag_names.append(release["tag_name"]) #.replace(" ", "_").replace(".", "_"))
                    asset_url = asset["browser_download_url"]
                    asset_urls.append(asset_url)            

            # Sort asset_urls and tag_names by value of tag_names 
            #asset_urls, tag_names = zip(*sorted(zip(asset_urls, tag_names), key=lambda x: x[1], reverse=True))
            asset_urls = list(asset_urls)
            tag_names = list(tag_names)
            #print(f"Sorted asset URLs and tag names: {asset_urls}\n, {tag_names}")
            for asset_url, tag_name in zip(asset_urls, tag_names):
                print(f"- Downloading {asset_name} from {asset_url}")
                dest_path = os.path.join(self._download_directory, tag_name + ".zip")
                self.download_file(asset_url, dest_path)
                print(f"Saved to {dest_path}")

                # Unzip the downloaded file
                print(f"Extracting {dest_path} to {os.path.join(self._download_directory, tag_name)}")
                with zipfile.ZipFile(dest_path, 'r') as zip_ref:
                    zip_ref.extractall(os.path.join(self._download_directory, tag_name))
                    print(f"Extracted to {os.path.join(self._download_directory, tag_name)}")

                # TODO Just pick one for now.
                break
            print(f"Finished checking assets for release: {release_name}")

            if by_count:
                if index >= self._version_count - 1:
                    stop_search = True
                index += 1

            if stop_search:
                break

    def download_libraries(self, by_count: bool = True) -> None:
        """Download the 'Source code (zip)' for the latest N releases and extract the standard 'libraries' folder.
        
        @param by_count: If True, download by count limit; if False, download specific version
        @return: None
        """
        headers = {"Authorization": f"token {self.GITHUB_TOKEN}"} if self.GITHUB_TOKEN else {}
        response = requests.get(self.RELEASES_API_URL, headers=headers)
        response.raise_for_status()

        releases = response.json()
        index = 0
        version_string = None
        if not by_count:
            version_string = self.version_string
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
            dest_path = os.path.join(self._download_directory, f"{tag_name}.zip")
            self.download_file(source_zip_url, dest_path)
            print(f"\nSaved ZIP to {dest_path}")            
            
            # Extract out the "libraries" folder from the zip file
            print(f"Extracing ZIP files from {dest_path} to {os.path.join(self._download_directory, tag_name)}")
            with zipfile.ZipFile(dest_path, 'r') as zip_ref:
                for file in zip_ref.namelist():
            
                    # Strip the top-level folder first to check the actual path structure
                    path_parts = file.split('/')
                    if len(path_parts) > 1:
            
                        # Get path without the top-level folder (e.g., MaterialX-1.39.3/)
                        relative_path = '/'.join(path_parts[1:])
            
                        # Check if the path starts with any of the folder_filter entries
                        if any(relative_path.startswith(f"{folder}/") for folder in self._folder_filter):  
                            
                            # Create new path without the top-level folder
                            new_file_path = relative_path
                            
                            # Create a ZipInfo object with the modified path
                            info = zip_ref.getinfo(file)
                            info.filename = new_file_path
                            
                            # Extract with the modified path
                            zip_ref.extract(info, os.path.join(self._download_directory, tag_name))
                            
                            print('+', end='', flush=True)  # Print a dot for each chunk downloaded
                            #print(f"Extracted {new_file_path} to {os.path.join(self._download_directory, tag_name, new_file_path)}")
                
                print("\nFinished extracting libraries folder from zip file.")

            # Optionally, remove the zip file after extraction
            if self._remove_zip_after_extract:
                os.remove(dest_path)
                print(f"Removed zip file: {dest_path}") 

            if by_count:
                if index >= self._version_count - 1:
                    stop_search = True
                index += 1
            
            if stop_search:
                break

