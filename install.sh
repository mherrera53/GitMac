#!/bin/bash

# GitMac Installation Script
# Copies GitMac.app to /Applications

set -e

echo "🚀 Installing GitMac..."

# Check if GitMac.app exists
if [ ! -d "build/GitMac.app" ]; then
    echo "❌ Error: GitMac.app not found in build directory"
    echo "   Please build the app first with: xcodebuild -scheme GitMac -configuration Release"
    exit 1
fi

# Remove old version if exists
if [ -d "/Applications/GitMac.app" ]; then
    echo "🗑️  Removing old version..."
    rm -rf "/Applications/GitMac.app"
fi

# Copy new version
echo "📦 Copying GitMac.app to /Applications..."
cp -R "build/GitMac.app" "/Applications/"

# Verify installation
if [ -d "/Applications/GitMac.app" ]; then
    echo "✅ GitMac installed successfully!"
    echo ""
    echo "🎉 You can now launch GitMac from:"
    echo "   • Spotlight (⌘+Space, then type 'GitMac')"
    echo "   • Finder → Applications → GitMac"
    echo "   • Launchpad"
    echo ""

    # Ask to open
    read -p "Would you like to open GitMac now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "/Applications/GitMac.app"
    fi
else
    echo "❌ Installation failed"
    exit 1
fi
