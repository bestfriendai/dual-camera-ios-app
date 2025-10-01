#!/bin/bash

# Quick fix script to get the app building
echo "Applying quick fixes to get app building..."

# Add missing imports where needed
for file in DualCameraApp/AdaptiveQualityManager.swift DualCameraApp/CameraControlsView.swift; do
    if [ -f "$file" ]; then
        if ! grep -q "import os.log" "$file"; then
            sed -i '' '1s/^/import os.log\n/' "$file"
        fi
        if ! grep -q "import AVFoundation" "$file"; then
            sed -i '' '1s/^/import AVFoundation\n/' "$file"
        fi
    fi
done

echo "Quick fixes applied"
