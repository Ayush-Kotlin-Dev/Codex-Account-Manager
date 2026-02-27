#!/bin/bash
#
# archive-export-install.sh
# Archives, exports, and installs the Codex Account Manager app to /Applications
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="Codex-Account-Manager"
SCHEME="Codex-Account-Manager"
APP_NAME="Codex-Account-Manager.app"
INSTALL_PATH="/Applications/${APP_NAME}"

# Build paths
BUILD_DIR="$(pwd)/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/exported"
EXPORT_OPTIONS_PLIST="${BUILD_DIR}/ExportOptions.plist"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Codex Account Manager - Archive & Install${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}Error: Could not find ${PROJECT_NAME}.xcodeproj${NC}"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Clean previous builds
echo -e "${YELLOW}→ Cleaning previous builds...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Create ExportOptions.plist
echo -e "${YELLOW}→ Creating export options...${NC}"
cat > "${EXPORT_OPTIONS_PLIST}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

# Archive
echo -e "${YELLOW}→ Archiving...${NC}"
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo -e "${RED}Error: Archive failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Archive created${NC}"

# Export
echo -e "${YELLOW}→ Exporting...${NC}"
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"

if [ ! -d "${EXPORT_PATH}/${APP_NAME}" ]; then
    echo -e "${RED}Error: Export failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ App exported${NC}"

# Install
echo -e "${YELLOW}→ Installing to /Applications...${NC}"

if [ -d "${INSTALL_PATH}" ]; then
    echo -e "${BLUE}  Removing existing app...${NC}"
    sudo rm -rf "${INSTALL_PATH}"
fi

sudo cp -R "${EXPORT_PATH}/${APP_NAME}" "/Applications/"
sudo chown -R "$(whoami)" "${INSTALL_PATH}"

echo -e "${GREEN}✓ Installed${NC}"

# Get version
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${EXPORT_PATH}/${APP_NAME}/Contents/Info.plist" 2>/dev/null || echo "unknown")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${EXPORT_PATH}/${APP_NAME}/Contents/Info.plist" 2>/dev/null || echo "unknown")

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Done!                                ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Version:  ${BLUE}${VERSION} (${BUILD})${NC}"
echo -e "  Location: ${BLUE}${INSTALL_PATH}${NC}"
echo ""
echo -e "  Launch:   ${YELLOW}Cmd+Space → 'codex' → Enter${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
