#!/bin/bash
set -euo pipefail

APP_NAME="Crackinate"
APP_BUNDLE="${APP_NAME}.app"
INSTALL_DIR="/Applications"
CLI_NAME="crackinate"
CLI_DEST="/usr/local/bin/${CLI_NAME}"
SUDOERS_FILE="/etc/sudoers.d/crackinate"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.crackinate.app.plist"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Uninstalling previous Crackinate installation...${NC}"

# 1. Kill running instances
pkill -f "${APP_NAME}.app" 2>/dev/null || true
sleep 1

# 2. Remove app bundle
if [ -d "${INSTALL_DIR}/${APP_BUNDLE}" ]; then
    rm -rf "${INSTALL_DIR}/${APP_BUNDLE}"
    echo -e "${GREEN}✓ Removed ${INSTALL_DIR}/${APP_BUNDLE}${NC}"
else
    echo "  App not found in ${INSTALL_DIR}"
fi

# 3. Remove CLI
if [ -f "${CLI_DEST}" ]; then
    sudo rm -f "${CLI_DEST}"
    echo -e "${GREEN}✓ Removed ${CLI_DEST}${NC}"
else
    echo "  CLI not found at ${CLI_DEST}"
fi

# 4. Remove sudoers file
if [ -f "${SUDOERS_FILE}" ]; then
    sudo rm -f "${SUDOERS_FILE}"
    echo -e "${GREEN}✓ Removed ${SUDOERS_FILE}${NC}"
else
    echo "  Sudoers file not found"
fi

# 5. Remove LaunchAgent
if [ -f "${LAUNCH_AGENT}" ]; then
    launchctl unload "${LAUNCH_AGENT}" 2>/dev/null || true
    rm -f "${LAUNCH_AGENT}"
    echo -e "${GREEN}✓ Removed LaunchAgent${NC}"
else
    echo "  LaunchAgent not found"
fi

# 6. Clear UserDefaults
defaults delete com.crackinate.app 2>/dev/null && echo -e "${GREEN}✓ Cleared UserDefaults${NC}" || echo "  No UserDefaults to clear"

echo ""
echo -e "${YELLOW}Installing Crackinate...${NC}"

# Determine project root (parent of this script's directory)
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 7. Build the app
cd "${SCRIPT_DIR}"
echo "  Building..."
swift build -c release --arch arm64 2>/dev/null
swift build -c release --arch x86_64 2>/dev/null || true

# 8. Copy app bundle
BUNDLE_SRC="${SCRIPT_DIR}/.build/release/${APP_BUNDLE}"
if [ ! -d "${BUNDLE_SRC}" ]; then
    echo -e "${RED}Error: App bundle not found at ${BUNDLE_SRC}${NC}"
    echo "Run 'make app' first."
    exit 1
fi
cp -R "${BUNDLE_SRC}" "${INSTALL_DIR}/"
xattr -rd com.apple.quarantine "${INSTALL_DIR}/${APP_BUNDLE}" 2>/dev/null || true
echo -e "${GREEN}✓ Installed ${INSTALL_DIR}/${APP_BUNDLE}${NC}"

# 9. Install CLI
CLI_SRC="${SCRIPT_DIR}/.build/release/CrackinateCLI"
if [ -f "${CLI_SRC}" ]; then
    sudo cp "${CLI_SRC}" "${CLI_DEST}"
    sudo chmod 755 "${CLI_DEST}"
    echo -e "${GREEN}✓ Installed CLI to ${CLI_DEST}${NC}"
else
    echo -e "${YELLOW}⚠ CLI binary not found, skipping${NC}"
fi

echo ""
echo -e "${GREEN}═══ Installation complete ═══${NC}"
echo ""
echo "  App:  ${INSTALL_DIR}/${APP_BUNDLE}"
echo "  CLI:  ${CLI_DEST}"
echo ""
echo "  Start Crackinate from Finder or Launchpad."
echo "  Or run:  open ${INSTALL_DIR}/${APP_BUNDLE}"
echo ""
echo "  CLI commands:"
echo "    crackinate activate       Turn ON both"
echo "    crackinate deactivate     Turn OFF both"
echo "    crackinate status         Show state"
echo "    crackinate --help         All commands"
