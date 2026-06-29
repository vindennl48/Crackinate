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

echo -e "${YELLOW}Uninstalling Crackinate...${NC}"

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
    if rm -f "${CLI_DEST}" 2>/dev/null; then
        echo -e "${GREEN}✓ Removed ${CLI_DEST}${NC}"
    else
        sudo rm -f "${CLI_DEST}" 2>/dev/null && echo -e "${GREEN}✓ Removed ${CLI_DEST} (via sudo)${NC}" || echo "  Could not remove CLI (try: sudo rm ${CLI_DEST})"
    fi
else
    echo "  CLI not found at ${CLI_DEST}"
fi

# 4. Remove sudoers file
if [ -f "${SUDOERS_FILE}" ]; then
    sudo rm -f "${SUDOERS_FILE}" 2>/dev/null && echo -e "${GREEN}✓ Removed ${SUDOERS_FILE}${NC}" || echo -e "${YELLOW}⚠ Could not remove sudoers file (try: sudo rm ${SUDOERS_FILE})${NC}"
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
echo -e "${GREEN}═══ Crackinate has been completely uninstalled ═══${NC}"
