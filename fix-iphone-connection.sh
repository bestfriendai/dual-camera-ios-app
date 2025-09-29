#!/bin/bash

echo "🔧 iPhone Connection Troubleshooting Script"
echo "=========================================="
echo ""

# Check if iPhone is connected via USB
echo "1️⃣ Checking USB connection..."
if system_profiler SPUSBDataType | grep -q "iPhone"; then
    echo "✅ iPhone detected via USB"
else
    echo "❌ iPhone NOT detected via USB"
    echo "   → Check cable connection"
    echo "   → Try a different USB port"
    echo "   → Try a different cable"
    echo "   → Make sure iPhone is unlocked"
fi
echo ""

# Check for connected devices
echo "2️⃣ Checking Xcode device list..."
DEVICES=$(xcrun xctrace list devices 2>&1 | grep "iPhone")
if [ -n "$DEVICES" ]; then
    echo "✅ iPhone(s) found:"
    echo "$DEVICES"
else
    echo "❌ No iPhone devices found in Xcode"
    echo "   → Make sure you've trusted this computer on your iPhone"
    echo "   → Enable Developer Mode on iPhone (Settings → Privacy & Security)"
fi
echo ""

# Check Xcode version
echo "3️⃣ Checking Xcode version..."
XCODE_VERSION=$(xcodebuild -version | head -1)
echo "   $XCODE_VERSION"
echo ""

# Offer to clean Xcode cache
echo "4️⃣ Would you like to clean Xcode cache? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "   Killing Xcode processes..."
    killall Xcode 2>/dev/null || true
    
    echo "   Cleaning derived data..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
    
    echo "   ✅ Cache cleaned!"
    echo "   → Please restart Xcode and reconnect your iPhone"
else
    echo "   Skipped cache cleaning"
fi
echo ""

echo "📱 Manual Steps to Try:"
echo "======================="
echo "1. On iPhone: Settings → Privacy & Security → Developer Mode → ON"
echo "2. Unplug and replug the USB cable"
echo "3. On iPhone: Tap 'Trust' when prompted"
echo "4. In Xcode: Window → Devices and Simulators (Cmd+Shift+2)"
echo "5. Check if iPhone appears in the left sidebar"
echo ""
echo "If still not working:"
echo "- Restart your iPhone"
echo "- Restart your Mac"
echo "- Update Xcode from the App Store"
echo "- Try a different USB cable"
echo ""

