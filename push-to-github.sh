#!/bin/bash

echo "🚀 Push Dual Camera App to GitHub"
echo "=================================="
echo ""

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "❌ Git not initialized. Run: git init"
    exit 1
fi

echo "✅ Git repository ready"
echo ""
echo "📋 STEP 1: Create Repository on GitHub"
echo "======================================="
echo ""
echo "Please open your browser and go to:"
echo "👉 https://github.com/new"
echo ""
echo "Fill in the following:"
echo "  Repository name: dual-camera-ios-app"
echo "  Description: Professional dual camera iOS app with simultaneous recording"
echo "  Visibility: ✅ Public"
echo "  Initialize: ❌ DON'T check any boxes"
echo ""
echo "Then click 'Create repository'"
echo ""
read -p "Press ENTER after you've created the repository on GitHub..."

echo ""
echo "📤 STEP 2: Push to GitHub"
echo "========================="
echo ""

# Add remote
echo "Adding remote repository..."
git remote remove origin 2>/dev/null
git remote add origin https://github.com/bestfriendai/dual-camera-ios-app.git

# Rename branch to main
echo "Setting branch to main..."
git branch -M main

# Push
echo ""
echo "Pushing to GitHub..."
echo "You may be prompted for your GitHub credentials."
echo ""

git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS! Your repository is now on GitHub!"
    echo ""
    echo "📱 View it at:"
    echo "   https://github.com/bestfriendai/dual-camera-ios-app"
    echo ""
    echo "🎨 Next steps:"
    echo "   1. Add topics/tags on GitHub"
    echo "   2. Add screenshots to README"
    echo "   3. Share your project!"
else
    echo ""
    echo "❌ Push failed. Trying alternative method..."
    echo ""
    echo "Please authenticate with GitHub CLI:"
    echo "   gh auth login"
    echo ""
    echo "Then run this script again."
fi

