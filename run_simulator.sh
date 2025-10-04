#!/bin/bash
set -e

echo "Building app..."
xcodebuild -project DualCameraApp.xcodeproj -scheme DualCameraApp -configuration Debug -sdk iphonesimulator -derivedDataPath build 2>&1 | grep -E "(BUILD|error:|warning:)" | tail -20

echo -e "\nLaunching simulator..."
open -a Simulator

echo "Waiting for simulator to boot..."
sleep 3

echo -e "\nInstalling app..."
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/DualCameraApp.app

echo -e "\nLaunching app with console output..."
xcrun simctl launch --console booted com.dualcamera.DualCameraApp 2>&1 | head -100
