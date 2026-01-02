#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Setting up GhosttyKit framework ===${NC}"

FRAMEWORK_DIR="Frameworks"
FRAMEWORK_NAME="GhosttyKit.xcframework"
FRAMEWORK_PATH="$FRAMEWORK_DIR/$FRAMEWORK_NAME"
REPO="mherrera53/GitMac"
RELEASE_TAG="dependencies"

# Check if the framework already exists
if [ -d "$FRAMEWORK_PATH" ]; then
    echo -e "${GREEN}✓ GhosttyKit framework already exists${NC}"
    exit 0
fi

echo -e "${YELLOW}Downloading GhosttyKit framework from GitHub release...${NC}"

# Create Frameworks directory if it doesn't exist
mkdir -p "$FRAMEWORK_DIR"

# Download the framework from GitHub release
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$RELEASE_TAG/$FRAMEWORK_NAME.zip"

echo -e "${BLUE}Downloading from: $DOWNLOAD_URL${NC}"

if command -v curl &> /dev/null; then
    curl -L -o "$FRAMEWORK_DIR/$FRAMEWORK_NAME.zip" "$DOWNLOAD_URL"
elif command -v wget &> /dev/null; then
    wget -O "$FRAMEWORK_DIR/$FRAMEWORK_NAME.zip" "$DOWNLOAD_URL"
else
    echo -e "${RED}Error: curl or wget is required to download the framework${NC}"
    exit 1
fi

# Extract the framework
echo -e "${YELLOW}Extracting framework...${NC}"
cd "$FRAMEWORK_DIR"
unzip -q "$FRAMEWORK_NAME.zip"
rm "$FRAMEWORK_NAME.zip"
cd ..

# Verify extraction
if [ -d "$FRAMEWORK_PATH" ]; then
    echo -e "${GREEN}✓ GhosttyKit framework successfully downloaded and extracted${NC}"
    echo -e "${GREEN}✓ Framework location: $FRAMEWORK_PATH${NC}"
else
    echo -e "${RED}Error: Framework extraction failed${NC}"
    exit 1
fi

echo -e "${BLUE}=== Setup complete ===${NC}"
