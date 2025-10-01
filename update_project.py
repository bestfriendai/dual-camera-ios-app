#!/usr/bin/env python3
"""
Script to update the Xcode project with all missing Swift files
"""

import os
import re
import glob

def get_swift_files_in_directory():
    """Get all Swift files in the DualCameraApp directory"""
    swift_files = []
    directory = "DualCameraApp"
    
    for file in glob.glob(f"{directory}/*.swift"):
        swift_files.append(os.path.basename(file))
    
    return sorted(swift_files)

def get_swift_files_in_project():
    """Get Swift files currently referenced in the project"""
    project_file = "DualCameraApp.xcodeproj/project.pbxproj"
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Find all Swift file references
    pattern = r'(\w+)\s*\/\*\s*(.+\.swift)\s*\*\/\s*=\s*\{isa\s*=\s*PBXFileReference'
    matches = re.findall(pattern, content)
    
    swift_files = []
    for match in matches:
        swift_files.append(match[1])
    
    return sorted(swift_files)

def main():
    print("Checking for missing Swift files in Xcode project...")
    
    directory_files = get_swift_files_in_directory()
    project_files = get_swift_files_in_project()
    
    print(f"Swift files in directory: {len(directory_files)}")
    print(f"Swift files in project: {len(project_files)}")
    
    missing_files = [f for f in directory_files if f not in project_files]
    
    if missing_files:
        print(f"\nMissing {len(missing_files)} Swift files from project:")
        for file in missing_files:
            print(f"  - {file}")
        
        print("\nThese files need to be added to the Xcode project manually.")
        print("Please open the project in Xcode and add these files to the target.")
    else:
        print("\nAll Swift files are properly included in the project!")

if __name__ == "__main__":
    main()