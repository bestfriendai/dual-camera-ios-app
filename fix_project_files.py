#!/usr/bin/env python3
import re
import os

def fix_project_pbxproj():
    project_file = "DualCameraApp.xcodeproj/project.pbxproj"
    
    # Read the current project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Files to add to the build phase
    files_to_add = [
        "A1000033294A0000000000001 /* VisualCountdownView.swift in Sources */",
        "A1000034294A0000000000001 /* SettingsManager.swift in Sources */",
        "A1000035294A0000000000001 /* TripleOutputControlView.swift in Sources */",
        "A1000036294A0000000000001 /* CameraControlsView.swift in Sources */",
        "A1000037294A0000000000001 /* AdvancedCameraControlsManager.swift in Sources */",
        "A1000038294A0000000000001 /* AudioControlsView.swift in Sources */"
    ]
    
    # Files to add to the group
    files_to_add_to_group = [
        "A1000034294A0000000000001 /* VisualCountdownView.swift */",
        "A1000035294A0000000000001 /* SettingsManager.swift */",
        "A1000036294A0000000000001 /* TripleOutputControlView.swift */",
        "A1000037294A0000000000001 /* CameraControlsView.swift */",
        "A1000038294A0000000000001 /* AdvancedCameraControlsManager.swift */",
        "A1000039294A0000000000001 /* AudioControlsView.swift */"
    ]
    
    # Find and update the PBXSourcesBuildPhase section
    sources_pattern = r'(\t\tA1000022294A0000000000000 /\* Sources \*/ = \{\s+isa = PBXSourcesBuildPhase;\s+buildActionMask = 2147483647;\s+files = \(\s+.*?A1000032294A0000000000001 /\* CameraPreviewView\.swift in Sources \*/,\s*)(\s*\);)'
    
    def replace_sources(match):
        before = match.group(1)
        after = match.group(2)
        
        # Add the missing files
        added_files = ""
        for file_ref in files_to_add:
            added_files += f"\t\t\t\t{file_ref},\n"
        
        return before + added_files + after
    
    content = re.sub(sources_pattern, replace_sources, content, flags=re.DOTALL)
    
    # Find and update the PBXGroup section
    group_pattern = r'(\t\tA1000018294A0000000000001 /\* DualCameraApp \*/ = \{\s+isa = PBXGroup;\s+children = \(\s+.*?A1000033294A0000000000001 /\* CameraPreviewView\.swift \*/,\s*)(\s+A1000016294A0000000000001 /\* Assets\.xcassets \*/,\s+)'
    
    def replace_group(match):
        before = match.group(1)
        middle = match.group(2)
        
        # Add the missing files
        added_files = ""
        for file_ref in files_to_add_to_group:
            added_files += f"\t\t\t\t{file_ref},\n"
        
        return before + added_files + middle
    
    content = re.sub(group_pattern, replace_group, content, flags=re.DOTALL)
    
    # Write the updated content back to the file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("Successfully updated project.pbxproj file")

if __name__ == "__main__":
    fix_project_pbxproj()