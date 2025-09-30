#!/usr/bin/env python3
"""
Script to add new Swift files to Xcode project
"""

import subprocess
import sys

def add_files_to_xcode():
    """Add new Swift files to the Xcode project"""
    
    new_files = [
        "DualCameraApp/PermissionManager.swift",
        "DualCameraApp/CameraPreviewView.swift"
    ]
    
    for file_path in new_files:
        print(f"Adding {file_path} to Xcode project...")
        
        # Use xcodebuild to add the file
        # Note: This is a simplified approach. In practice, you might need to manually add via Xcode
        # or use a more sophisticated pbxproj manipulation library
        
    print("\nNote: Please add the following files to your Xcode project manually:")
    for file_path in new_files:
        print(f"  - {file_path}")
    
    print("\nTo add files in Xcode:")
    print("1. Right-click on the 'DualCameraApp' folder in Xcode")
    print("2. Select 'Add Files to DualCameraApp...'")
    print("3. Select the new .swift files")
    print("4. Make sure 'Copy items if needed' is checked")
    print("5. Click 'Add'")

if __name__ == "__main__":
    add_files_to_xcode()

