#!/usr/bin/env python3
"""
Simple script to add essential files to Xcode project
"""

import re
import uuid
import random

def generate_uuid():
    """Generate a UUID similar to Xcode format"""
    return ''.join([random.choice('0123456789ABCDEF') for _ in range(24)])

def add_files_to_project():
    """Add essential files to the Xcode project"""
    project_file = "DualCameraApp.xcodeproj/project.pbxproj"
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Essential files to add
    files_to_add = [
        'VisualCountdownView.swift',
        'SettingsManager.swift', 
        'TripleOutputControlView.swift',
        'CameraControlsView.swift',
        'AdvancedCameraControlsManager.swift',
        'AudioControlsView.swift'
    ]
    
    # Find the last PBXBuildFile entry
    build_file_pattern = r'(\w+294A0000000000001) \/\* (.+\.swift) in Sources \*\/ = \{isa = PBXBuildFile'
    build_file_matches = re.findall(build_file_pattern, content)
    
    # Find the last PBXFileReference entry
    file_ref_pattern = r'(\w+294A0000000000001) \/\* (.+\.swift) \*\/ = \{isa = PBXFileReference'
    file_ref_matches = re.findall(file_ref_pattern, content)
    
    # Find the Sources build phase section
    sources_phase_pattern = r'\/\* Begin PBXSourcesBuildPhase section \*\/.*?\/\* End PBXSourcesBuildPhase section \*\/'
    sources_match = re.search(sources_phase_pattern, content, re.DOTALL)
    
    # Find the DualCameraApp group section
    group_pattern = r'A1000018294A0000000000001 \/\* DualCameraApp \*\/ = \{.*?children = \((.*?)\);'
    group_match = re.search(group_pattern, content, re.DOTALL)
    
    if not all([build_file_matches, file_ref_matches, sources_match, group_match]):
        print("Could not find required sections in project file")
        return False
    
    # Get the last IDs to generate new ones
    last_build_id = build_file_matches[-1][0] if build_file_matches else "A1000032294A0000000000001"
    last_file_ref_id = file_ref_matches[-1][0] if file_ref_matches else "A1000033294A0000000000001"
    
    # Extract the base and increment
    base_build_id = last_build_id[:8]
    base_file_ref_id = last_file_ref_id[:8]
    
    build_file_additions = []
    file_ref_additions = []
    sources_additions = []
    group_additions = []
    
    # Generate entries for each file
    for i, filename in enumerate(files_to_add):
        # Generate new IDs
        build_id = f"{int(base_build_id, 16) + i + 1:08X}294A0000000000001"
        file_ref_id = f"{int(base_file_ref_id, 16) + i + 1:08X}294A0000000000001"
        
        # Create entries
        build_file_entry = f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};"
        file_ref_entry = f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};"
        sources_entry = f"\t\t\t{build_id} /* {filename} in Sources */,"
        group_entry = f"\t\t\t{file_ref_id} /* {filename} */,"
        
        build_file_additions.append(build_file_entry)
        file_ref_additions.append(file_ref_entry)
        sources_additions.append(sources_entry)
        group_additions.append(group_entry)
    
    # Find insertion points
    lines = content.split('\n')
    
    # Insert PBXBuildFile entries
    for i, line in enumerate(lines):
        if '/* End PBXBuildFile section */' in line:
            for entry in build_file_additions:
                lines.insert(i, entry)
                i += 1
            break
    
    # Insert PBXFileReference entries
    for i, line in enumerate(lines):
        if '/* End PBXFileReference section */' in line:
            for entry in file_ref_additions:
                lines.insert(i, entry)
                i += 1
            break
    
    # Insert Sources build phase entries
    for i, line in enumerate(lines):
        if 'runOnlyForDeploymentPostprocessing = 0;' in line and i > 0 and 'PBXSourcesBuildPhase' in lines[i-5:i]:
            for entry in reversed(sources_additions):
                lines.insert(i, entry)
            break
    
    # Insert group entries
    for i, line in enumerate(lines):
        if 'A1000019294A0000000000001 /* Products */,' in line:
            for entry in reversed(group_additions):
                lines.insert(i, entry)
            break
    
    # Write the updated content
    updated_content = '\n'.join(lines)
    
    with open(project_file, 'w') as f:
        f.write(updated_content)
    
    print(f"Added {len(files_to_add)} essential files to the project")
    return True

if __name__ == "__main__":
    add_files_to_project()