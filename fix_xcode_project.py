#!/usr/bin/env python3
"""
Script to automatically add all missing Swift files to the Xcode project
"""

import os
import re
import glob
import uuid
import random

def generate_uuid():
    """Generate a random UUID for Xcode project file references"""
    return ''.join([random.choice('0123456789ABCDEF') for _ in range(24)])

def get_missing_swift_files():
    """Get all Swift files that are in the directory but not in the project"""
    directory = "DualCameraApp"
    project_file = "DualCameraApp.xcodeproj/project.pbxproj"
    
    # Get all Swift files in directory
    directory_files = []
    for file in glob.glob(f"{directory}/*.swift"):
        directory_files.append(os.path.basename(file))
    
    # Get Swift files in project
    with open(project_file, 'r') as f:
        content = f.read()
    
    pattern = r'(\w+)\s*\/\*\s*(.+\.swift)\s*\*\/\s*=\s*\{isa\s*=\s*PBXFileReference'
    matches = re.findall(pattern, content)
    project_files = [match[1] for match in matches]
    
    # Find missing files
    missing_files = [f for f in directory_files if f not in project_files]
    return missing_files

def update_project_file():
    """Update the Xcode project file to include all missing Swift files"""
    project_file = "DualCameraApp.xcodeproj/project.pbxproj"
    
    # Read current project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    missing_files = get_missing_swift_files()
    
    if not missing_files:
        print("No missing files found!")
        return
    
    print(f"Adding {len(missing_files)} missing Swift files to project...")
    
    # Find insertion points
    pbx_build_file_section = re.search(r'\/\* Begin PBXBuildFile section \*\/', content)
    pbx_file_reference_section = re.search(r'\/\* Begin PBXFileReference section \*\/', content)
    pbx_sources_build_phase = re.search(r'\/\* Begin PBXSourcesBuildPhase section \*\/', content)
    dual_camera_app_group = re.search(r'A1000018294A0000000000001 \/\* DualCameraApp \*\/ = \{', content)
    
    if not all([pbx_build_file_section, pbx_file_reference_section, pbx_sources_build_phase, dual_camera_app_group]):
        print("Could not find required sections in project file!")
        return
    
    # Generate additions for each section
    build_file_additions = []
    file_reference_additions = []
    sources_build_phase_additions = []
    group_additions = []
    
    for file in missing_files:
        # Generate unique IDs
        file_ref_id = generate_uuid()
        build_file_id = generate_uuid()
        
        # Build file entry
        build_file_entry = f"\t\t{build_file_id}294A0000000000001 /* {file} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id}294A0000000000001 /* {file} */; }};"
        build_file_additions.append(build_file_entry)
        
        # File reference entry
        file_ref_entry = f"\t\t{file_ref_id}294A0000000000001 /* {file} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file}; sourceTree = \"<group>\"; }};"
        file_reference_additions.append(file_ref_entry)
        
        # Sources build phase entry
        sources_entry = f"\t\t\t{build_file_id}294A0000000000001 /* {file} in Sources */,"
        sources_build_phase_additions.append(sources_entry)
        
        # Group entry
        group_entry = f"\t\t\t{file_ref_id}294A0000000000001 /* {file} */,"
        group_additions.append(group_entry)
    
    # Insert additions into content
    lines = content.split('\n')
    
    # Insert PBXBuildFile entries
    build_file_insert = pbx_build_file_section.end() + len('/* Begin PBXBuildFile section */\n')
    for entry in reversed(build_file_additions):
        lines.insert(build_file_insert, entry)
    
    # Insert PBXFileReference entries
    file_ref_insert = pbx_file_reference_section.end() + len('/* Begin PBXFileReference section */\n')
    for entry in reversed(file_reference_additions):
        lines.insert(file_ref_insert, entry)
    
    # Insert Sources build phase entries
    sources_insert = pbx_sources_build_phase.end() + len('/* Begin PBXSourcesBuildPhase section */\n')
    # Find the end of the files array in Sources build phase
    for i in range(sources_insert, len(lines)):
        if lines[i].strip() == ");" and "runOnlyForDeploymentPostprocessing" in lines[i+1] if i+1 < len(lines) else False:
            sources_insert = i
            break
    for entry in reversed(sources_build_phase_additions):
        lines.insert(sources_insert, entry)
    
    # Insert group entries
    group_insert = dual_camera_app_group.end()
    # Find the children array in DualCameraApp group
    for i in range(group_insert, len(lines)):
        if lines[i].strip() == "children = (":
            group_insert = i + 1
            break
    for i in range(group_insert, len(lines)):
        if lines[i].strip() == ");":
            group_insert = i
            break
    for entry in reversed(group_additions):
        lines.insert(group_insert, entry)
    
    # Write updated content
    updated_content = '\n'.join(lines)
    
    with open(project_file, 'w') as f:
        f.write(updated_content)
    
    print(f"Successfully added {len(missing_files)} Swift files to the project!")
    
    # List added files
    for file in missing_files:
        print(f"  + {file}")

def main():
    print("Fixing Xcode project to include all Swift files...")
    update_project_file()
    print("\nProject file updated successfully!")

if __name__ == "__main__":
    main()