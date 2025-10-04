#!/usr/bin/env python3
import os
import uuid
import glob

# Read the pbxproj file
pbxproj_path = "/Users/letsmakemillions/Desktop/APp/Z/DualApp.xcodeproj/project.pbxproj"
with open(pbxproj_path, 'r') as f:
    content = f.read()

# Find all Swift files in Core, App, VideoProcessing, Features folders
base_path = "/Users/letsmakemillions/Desktop/APp/Z/DualApp"
folders_to_add = [
    "Core",
    "App", 
    "VideoProcessing",
    "Features"
]

files_to_add = []
for folder in folders_to_add:
    folder_path = os.path.join(base_path, folder)
    if os.path.exists(folder_path):
        swift_files = glob.glob(f"{folder_path}/**/*.swift", recursive=True)
        metal_files = glob.glob(f"{folder_path}/**/*.metal", recursive=True)
        files_to_add.extend(swift_files + metal_files)

# Generate UUIDs for each file
file_refs = []
build_files = []

for file_path in files_to_add:
    rel_path = file_path.replace(base_path + "/", "")
    filename = os.path.basename(file_path)
    
    # Generate unique IDs
    file_ref_id = uuid.uuid4().hex[:24].upper()
    build_file_id = uuid.uuid4().hex[:24].upper()
    
    file_refs.append({
        'id': file_ref_id,
        'path': rel_path,
        'name': filename
    })
    
    build_files.append({
        'id': build_file_id,
        'file_ref_id': file_ref_id,
        'name': filename
    })

# Insert PBXBuildFile entries after line 66
pbxbuildfile_section = "/* End PBXBuildFile section */"
new_build_entries = []
for bf in build_files:
    entry = f"\t\t{bf['id']} /* {bf['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {bf['file_ref_id']} /* {bf['name']} */; }};\n"
    new_build_entries.append(entry)

content = content.replace(
    pbxbuildfile_section,
    ''.join(new_build_entries) + pbxbuildfile_section
)

# Insert PBXFileReference entries after line 128
pbxfilereference_section = "/* End PBXFileReference section */"
new_file_ref_entries = []
for fr in file_refs:
    file_type = "sourcecode.swift" if fr['name'].endswith('.swift') else "sourcecode.metal"
    entry = f"\t\t{fr['id']} /* {fr['name']} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {fr['path']}; sourceTree = \"<group>\"; }};\n"
    new_file_ref_entries.append(entry)

content = content.replace(
    pbxfilereference_section,
    ''.join(new_file_ref_entries) + pbxfilereference_section
)

# Insert into Sources build phase (before line 330)
sources_section_end = "\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase section */"
new_source_entries = []
for bf in build_files:
    entry = f"\t\t\t\t{bf['id']} /* {bf['name']} in Sources */,\n"
    new_source_entries.append(entry)

# Find the sources build phase section and add entries before the closing
import re
sources_pattern = r'(/\* Begin PBXSourcesBuildPhase section \*/.*?files = \()(.*?)(\);\s+runOnlyForDeploymentPostprocessing)'
match = re.search(sources_pattern, content, re.DOTALL)
if match:
    before = match.group(1)
    existing = match.group(2)
    after = match.group(3)
    new_sources = before + existing + ''.join(new_source_entries) + after
    content = re.sub(sources_pattern, new_sources, content, flags=re.DOTALL)

# Add frameworks to PBXFrameworksBuildPhase
frameworks = [
    "AVFoundation.framework",
    "CoreImage.framework", 
    "Metal.framework",
    "MetalKit.framework",
    "Photos.framework",
    "PhotosUI.framework",
    "Combine.framework",
    "SwiftUI.framework"
]

# Frameworks section is currently empty, add framework references
framework_refs = []
framework_builds = []

for fw in frameworks:
    fw_ref_id = uuid.uuid4().hex[:24].upper()
    fw_build_id = uuid.uuid4().hex[:24].upper()
    
    framework_refs.append({
        'id': fw_ref_id,
        'name': fw
    })
    framework_builds.append({
        'id': fw_build_id,
        'file_ref_id': fw_ref_id,
        'name': fw
    })

# Add framework file references
new_fw_refs = []
for fwr in framework_refs:
    entry = f"\t\t{fwr['id']} /* {fwr['name']} */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = {fwr['name']}; path = System/Library/Frameworks/{fwr['name']}; sourceTree = SDKROOT; }};\n"
    new_fw_refs.append(entry)

content = content.replace(
    pbxfilereference_section,
    ''.join(new_fw_refs) + pbxfilereference_section
)

# Add framework build files
new_fw_builds = []
for fwb in framework_builds:
    entry = f"\t\t{fwb['id']} /* {fwb['name']} in Frameworks */ = {{isa = PBXBuildFile; fileRef = {fwb['file_ref_id']} /* {fwb['name']} */; }};\n"
    new_fw_builds.append(entry)

content = content.replace(
    pbxbuildfile_section,
    ''.join(new_fw_builds) + pbxbuildfile_section
)

# Add to Frameworks build phase
frameworks_pattern = r'(A1000000294A0000000000000 /\* Frameworks \*/ = \{.*?files = \()(.*?)(\);)'
fw_match = re.search(frameworks_pattern, content, re.DOTALL)
if fw_match:
    before = fw_match.group(1)
    existing = fw_match.group(2)
    after = fw_match.group(3)
    
    new_fw_entries = []
    for fwb in framework_builds:
        entry = f"\t\t\t\t{fwb['id']} /* {fwb['name']} in Frameworks */,\n"
        new_fw_entries.append(entry)
    
    new_frameworks = before + ''.join(new_fw_entries) + existing + after
    content = re.sub(frameworks_pattern, new_frameworks, content, flags=re.DOTALL)

# Write back
with open(pbxproj_path, 'w') as f:
    f.write(content)

print(f"✅ Added {len(files_to_add)} source files to Xcode project")
print(f"✅ Added {len(frameworks)} frameworks to Xcode project")
print("\nFiles added:")
for f in files_to_add[:10]:
    print(f"  - {os.path.basename(f)}")
if len(files_to_add) > 10:
    print(f"  ... and {len(files_to_add) - 10} more")
print("\nFrameworks added:")
for fw in frameworks:
    print(f"  - {fw}")
