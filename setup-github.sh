#!/bin/bash

echo "🚀 GitHub Repository Setup for Dual Camera iOS App"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo -e "${BLUE}📦 Initializing Git repository...${NC}"
    git init
    echo -e "${GREEN}✅ Git initialized${NC}"
else
    echo -e "${GREEN}✅ Git already initialized${NC}"
fi

echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Before running this script, create a repository on GitHub:${NC}"
echo ""
echo "1. Go to: https://github.com/new"
echo "2. Repository name: dual-camera-ios-app"
echo "3. Description: Professional dual camera iOS app with simultaneous recording"
echo "4. Make it Public (recommended for portfolio)"
echo "5. DON'T add README, .gitignore, or license (we have them)"
echo "6. Click 'Create repository'"
echo ""
echo -e "${BLUE}Have you created the repository on GitHub? (y/n)${NC}"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Please create the repository first, then run this script again.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}📝 Staging files...${NC}"

# Add all files
git add .gitignore
git add LICENSE
git add README.md
git add IMPROVEMENTS.md
git add DualCameraApp/
git add DualCameraApp.xcodeproj/
git add Info.plist

echo -e "${GREEN}✅ Files staged${NC}"

echo ""
echo -e "${BLUE}💾 Creating initial commit...${NC}"
git commit -m "Initial commit: Dual Camera iOS App v2.0

Features:
- Simultaneous front and back camera recording
- Multiple quality settings (720p, 1080p, 4K)
- Picture-in-Picture and Side-by-Side layouts
- Pinch-to-zoom and tap-to-focus controls
- Video gallery with playback, share, and delete
- Progress indicators and error handling
- Memory optimization and auto-cleanup
- Modern glassmorphism UI design

Tech Stack:
- Swift 5.0+
- AVFoundation for camera management
- UIKit for UI
- Photos framework for library integration
- iOS 12.0+ compatible"

echo -e "${GREEN}✅ Initial commit created${NC}"

echo ""
echo -e "${BLUE}🔗 Adding remote repository...${NC}"
echo "Enter your GitHub username (default: bestfriendai):"
read -r username
username=${username:-bestfriendai}

REPO_URL="https://github.com/${username}/dual-camera-ios-app.git"
echo "Repository URL: $REPO_URL"

# Remove existing remote if it exists
git remote remove origin 2>/dev/null

git remote add origin "$REPO_URL"
echo -e "${GREEN}✅ Remote added${NC}"

echo ""
echo -e "${BLUE}📤 Pushing to GitHub...${NC}"
echo "This will push to the main branch."
echo ""

# Rename branch to main if needed
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    git branch -M main
fi

# Push to GitHub
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 SUCCESS! Repository pushed to GitHub!${NC}"
    echo ""
    echo "📱 Your repository is now available at:"
    echo "   https://github.com/${username}/dual-camera-ios-app"
    echo ""
    echo "🔗 Next steps:"
    echo "   1. Visit your repository on GitHub"
    echo "   2. Add topics/tags for better discoverability"
    echo "   3. Consider adding screenshots to README"
    echo "   4. Share your project!"
else
    echo ""
    echo -e "${YELLOW}⚠️  Push failed. This might be because:${NC}"
    echo "   1. Repository doesn't exist on GitHub"
    echo "   2. You need to authenticate (use GitHub CLI or Personal Access Token)"
    echo "   3. Repository URL is incorrect"
    echo ""
    echo "To authenticate, you can:"
    echo "   - Use GitHub CLI: gh auth login"
    echo "   - Or use SSH: git remote set-url origin git@github.com:${username}/dual-camera-ios-app.git"
fi

