#!/usr/bin/env python3
"""
Script to add essential missing files to the Xcode project using xcodeproj gem
"""

import subprocess
import os

def add_file_to_project(file_path):
    """Add a file to the Xcode project using xcodeproj command line"""
    try:
        # First, try to install xcodeproj gem if not available
        subprocess.run(['gem', 'install', 'xcodeproj'], check=True, capture_output=True)
        
        # Create a Ruby script to add the file
        ruby_script = f"""
require 'xcodeproj'

project_path = 'DualCameraApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.first

# Find the DualCameraApp group
main_group = project.main_group
dual_camera_group = main_group['DualCameraApp']

# Add the file
file_path = '{file_path}'
file_ref = dual_camera_group.new_reference(file_path)

# Add to target
target.add_file_references([file_ref])

# Save the project
project.save

puts "Added {{file_path}} to project"
"""
        
        # Write and execute the Ruby script
        with open('add_file.rb', 'w') as f:
            f.write(ruby_script)
        
        result = subprocess.run(['ruby', 'add_file.rb'], check=True, capture_output=True, text=True)
        print(f"✓ Added {file_path}")
        return True
        
    except Exception as e:
        print(f"✗ Failed to add {file_path}: {e}")
        return False
    finally:
        # Clean up
        if os.path.exists('add_file.rb'):
            os.remove('add_file.rb')

def main():
    print("Adding essential missing files to Xcode project...")
    
    # List of essential files that are causing build errors
    essential_files = [
        'DualCameraApp/VisualCountdownView.swift',
        'DualCameraApp/SettingsManager.swift',
        'DualCameraApp/TripleOutputControlView.swift',
        'DualCameraApp/CameraControlsView.swift',
        'DualCameraApp/AdvancedCameraControlsManager.swift',
        'DualCameraApp/AudioControlsView.swift',
        'DualCameraApp/ContentView.swift',
        'DualCameraApp/VideoQuality.swift',
        'DualCameraApp/HapticFeedbackManager.swift',
        'DualCameraApp/ErrorHandlingManager.swift',
        'DualCameraApp/AudioManager.swift'
    ]
    
    success_count = 0
    for file_path in essential_files:
        if os.path.exists(file_path):
            if add_file_to_project(file_path):
                success_count += 1
        else:
            print(f"✗ File not found: {file_path}")
    
    print(f"\nSuccessfully added {success_count}/{len(essential_files)} essential files")

if __name__ == "__main__":
    main()