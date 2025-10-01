#!/usr/bin/env python3
"""
Comprehensive fix for the Xcode project structure
"""

def fix_project():
    """Fix the Xcode project structure"""
    project_file = "DualCameraApp.xcodeproj/project.pbxproj"
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Fix 1: Add files to DualCameraApp group (before the closing parenthesis)
    dual_camera_group_end = '\t\t\tA1000017294A0000000000001 /* Info.plist */,\n\t\t);'
    dual_camera_group_fixed = '\t\t\tA1000017294A0000000000001 /* Info.plist */,\n\t\t\tA1000034294A0000000000001 /* VisualCountdownView.swift */,\n\t\t\tA1000035294A0000000000001 /* SettingsManager.swift */,\n\t\t\tA1000036294A0000000000001 /* TripleOutputControlView.swift */,\n\t\t\tA1000037294A0000000000001 /* CameraControlsView.swift */,\n\t\t\tA1000038294A0000000000001 /* AdvancedCameraControlsManager.swift */,\n\t\t\tA1000039294A0000000000001 /* AudioControlsView.swift */,\n\t\t);'
    content = content.replace(dual_camera_group_end, dual_camera_group_fixed)
    
    # Fix 2: Add files to Sources build phase (before the closing parenthesis)
    sources_end = '\t\t\tA1000032294A0000000000001 /* CameraPreviewView.swift in Sources */,\n\t\t);'
    sources_fixed = '\t\t\tA1000032294A0000000000001 /* CameraPreviewView.swift in Sources */,\n\t\t\tA1000033294A0000000000001 /* VisualCountdownView.swift in Sources */,\n\t\t\tA1000034294A0000000000001 /* SettingsManager.swift in Sources */,\n\t\t\tA1000035294A0000000000001 /* TripleOutputControlView.swift in Sources */,\n\t\t\tA1000036294A0000000000001 /* CameraControlsView.swift in Sources */,\n\t\t\tA1000037294A0000000000001 /* AdvancedCameraControlsManager.swift in Sources */,\n\t\t\tA1000038294A0000000000001 /* AudioControlsView.swift in Sources */,\n\t\t);'
    content = content.replace(sources_end, sources_fixed)
    
    # Write the fixed content
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("Fixed Xcode project structure comprehensively")

if __name__ == "__main__":
    fix_project()