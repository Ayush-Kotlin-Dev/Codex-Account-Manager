#!/bin/bash
#
# archive-install-local.sh
# Archives and installs the Codex Account Manager app locally (no paid dev account needed)
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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Codex Account Manager - Local Install${NC}"
echo -e "${BLUE}  (No paid developer account needed)    ${NC}"
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

# Archive
echo -e "${YELLOW}→ Archiving (this may take a minute)...${NC}"
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM="" \
    -allowProvisioningUpdates 2>&1 | tee "${BUILD_DIR}/archive.log"

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo -e "${RED}Error: Archive failed!${NC}"
    echo "Check ${BUILD_DIR}/archive.log for details"
    exit 1
fi
echo -e "${GREEN}✓ Archive created${NC}"

# The archived app is already signed with local development certificate
# Just copy it from the archive
ARCHIVED_APP="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}"

if [ ! -d "${ARCHIVED_APP}" ]; then
    echo -e "${RED}Error: Could not find app in archive${NC}"
    exit 1
fi

# Install
echo -e "${YELLOW}→ Installing to /Applications...${NC}"

if [ -d "${INSTALL_PATH}" ]; then
    echo -e "${BLUE}  Removing existing app...${NC}"
    sudo rm -rf "${INSTALL_PATH}"
fi

sudo cp -R "${ARCHIVED_APP}" "/Applications/"
sudo chown -R "$(whoami)" "${INSTALL_PATH}"

echo -e "${GREEN}✓ Installed${NC}"

# Get version
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${INSTALL_PATH}/Contents/Info.plist" 2>/dev/null || echo "unknown")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${INSTALL_PATH}/Contents/Info.plist" 2>/dev/null || echo "unknown")

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Done!                                ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Version:  ${BLUE}${VERSION} (${BUILD})${NC}"
echo -e "  Location: ${BLUE}${INSTALL_PATH}${NC}"
echo ""
echo -e "  ${YELLOW}Note: Since this uses ad-hoc signing, you may need to:${NC}"
echo -e "  1. Right-click the app in /Applications"
echo -e "  2. Select 'Open' and confirm"
echo -e "  3. Or run: xattr -cr ${INSTALL_PATH}"
echo ""
echo -e "  Launch:   ${YELLOW}Cmd+Space → 'codex' → Enter${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
