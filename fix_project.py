#!/usr/bin/env python3
import re
import sys

# Read the project file
with open("DualCameraApp.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# Find an existing .swift file that's properly configured (AppDelegate.swift)
ref_match = re.search(r'([A-F0-9]{24}) /\* AppDelegate\.swift \*/ = \{isa = PBXFileReference;[^}]+\};', content)
build_match = re.search(r'([A-F0-9]{24}) /\* AppDelegate\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})', content)

if not ref_match or not build_match:
    print("ERROR: Could not find reference file")
    sys.exit(1)

# Extract the pattern
ref_pattern = ref_match.group(0)
build_pattern_template = build_match.group(0)
file_ref_id_template = build_match.group(2)

# Files we need to add
files_to_add = [
    "ZoomControl.swift",
    "FlashControl.swift", 
    "TimerControl.swift",
    "FocusExposureControl.swift"
]

# Generate unique IDs
import hashlib
def generate_id(filename):
    return hashlib.md5(f"com.dualcamera.{filename}".encode()).hexdigest()[:24].upper()

# Remove any existing broken references
for filename in files_to_add:
    content = re.sub(rf'[A-F0-9]{{24}} /\* {re.escape(filename)}[^;]*;', '', content)

# Find the DualCameraApp group
group_match = re.search(r'(A2[A-F0-9]{23}) /\* DualCameraApp \*/ = \{\s+isa = PBXGroup;\s+children = \((.*?)\);', content, re.DOTALL)
if not group_match:
    print("ERROR: Could not find DualCameraApp group")
    sys.exit(1)

group_id = group_match.group(1)
children = group_match.group(2).strip().split('\n')
children = [c.strip() for c in children if c.strip()]

# Find sections
file_ref_section_match = re.search(r'(/\* Begin PBXFileReference section \*/\n)(.*?)(\n\s*/\* End PBXFileReference section \*/)', content, re.DOTALL)
build_file_section_match = re.search(r'(/\* Begin PBXBuildFile section \*/\n)(.*?)(\n\s*/\* End PBXBuildFile section \*/)', content, re.DOTALL)
sources_phase_match = re.search(r'(/\* Sources \*/.*?files = \(\n)(.*?)(\n\s+\);)', content, re.DOTALL)

if not all([file_ref_section_match, build_file_section_match, sources_phase_match]):
    print("ERROR: Could not find required sections")
    sys.exit(1)

# Build new entries
new_file_refs = []
new_build_files = []
new_group_children = []
new_source_files = []

for filename in files_to_add:
    file_id = generate_id(filename)
    build_id = generate_id(f"build_{filename}")
    
    # Create file reference entry
    file_ref = f"\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
    new_file_refs.append(file_ref)
    
    # Create build file entry
    build_file = f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};\n"
    new_build_files.append(build_file)
    
    # Add to group
    new_group_children.append(f"\t\t\t\t{file_id} /* {filename} */,")
    
    # Add to sources
    new_source_files.append(f"\t\t\t\t{build_id} /* {filename} in Sources */,")

# Insert into content
content = content.replace(
    file_ref_section_match.group(3),
    ''.join(new_file_refs) + file_ref_section_match.group(3)
)

content = content.replace(
    build_file_section_match.group(3),
    ''.join(new_build_files) + build_file_section_match.group(3)
)

# Update group children
old_group = group_match.group(0)
new_children_str = '\n'.join(children + new_group_children)
new_group = old_group.replace(
    f"children = ({group_match.group(2)});",
    f"children = (\n{new_children_str}\n\t\t\t);"
)
content = content.replace(old_group, new_group)

# Update sources
content = content.replace(
    sources_phase_match.group(3),
    '\n' + '\n'.join(new_source_files) + sources_phase_match.group(3)
)

# Write back
with open("DualCameraApp.xcodeproj/project.pbxproj", "w") as f:
    f.write(content)

print("✅ Successfully added files to Xcode project:")
for f in files_to_add:
    print(f"   - {f}")
