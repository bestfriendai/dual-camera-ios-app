#!/usr/bin/env python3
import re
import uuid

# Files to add
files_to_add = [
    "ZoomControl.swift",
    "FlashControl.swift",
    "TimerControl.swift",
    "FocusExposureControl.swift"
]

# Read project file
with open("DualCameraApp.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# Find the file references section
file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)', content, re.DOTALL)
build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)', content, re.DOTALL)
sources_build_phase = re.search(r'(/\* Sources \*/.*?isa = PBXSourcesBuildPhase;.*?files = \((.*?)\);)', content, re.DOTALL)
group_section = re.search(r'(A2[0-9A-F]+ /\* DualCameraApp \*/ = \{.*?children = \((.*?)\);.*?name = DualCameraApp;)', content, re.DOTALL)

new_file_refs = []
new_build_files = []
new_file_ids = []

for filename in files_to_add:
    file_ref_id = uuid.uuid4().hex[:24].upper()
    build_file_id = uuid.uuid4().hex[:24].upper()
    
    file_ref = f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
    build_file = f"\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n"
    
    new_file_refs.append((file_ref_id, file_ref))
    new_build_files.append((build_file_id, build_file))
    new_file_ids.append(file_ref_id)

# Insert file references
file_ref_insert = file_ref_section.group(1).replace("/* End PBXFileReference section */", 
                                                      "".join([f[1] for f in new_file_refs]) + "/* End PBXFileReference section */")
content = content.replace(file_ref_section.group(1), file_ref_insert)

# Insert build files  
build_file_insert = build_file_section.group(1).replace("/* End PBXBuildFile section */",
                                                         "".join([b[1] for b in new_build_files]) + "/* End PBXBuildFile section */")
content = content.replace(build_file_section.group(1), build_file_insert)

# Insert into sources build phase
source_files = sources_build_phase.group(2).strip()
new_build_file_refs = "\n".join([f"\t\t\t\t{b[0]} /* {files_to_add[i]} in Sources */," for i, b in enumerate(new_build_files)])
new_source_files = source_files + "\n" + new_build_file_refs
content = re.sub(r'(/\* Sources \*/.*?files = \().*?(\);)', 
                 r'\1\n' + new_source_files + r'\n\t\t\t\2', content, flags=re.DOTALL, count=1)

# Insert into group
if group_section:
    children = group_section.group(2).strip()
    new_children_refs = "\n".join([f"\t\t\t\t{file_id} /* {files_to_add[i]} */," for i, (file_id, _) in enumerate(new_file_refs)])
    new_children = children + "\n" + new_children_refs
    old_group = group_section.group(1)
    new_group = old_group.replace(f"children = ({group_section.group(2)});", f"children = (\n{new_children}\n\t\t\t);")
    content = content.replace(old_group, new_group)

# Write back
with open("DualCameraApp.xcodeproj/project.pbxproj", "w") as f:
    f.write(content)

print(f"✅ Successfully added {len(files_to_add)} files to Xcode project!")
for f in files_to_add:
    print(f"  - {f}")
