#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="StockTicker"
APP_DEST="/Applications/${APP_NAME}.app"
CONFIG_DIR="$HOME/.stockticker"

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Stop running instance
stop_app() {
    if pgrep -x "$APP_NAME" > /dev/null; then
        print_step "Stopping ${APP_NAME}..."
        pkill -x "$APP_NAME" || true
        sleep 1
        print_success "Stopped"
    else
        print_success "${APP_NAME} is not running"
    fi
}

# Remove from login items
remove_login_item() {
    print_step "Checking login items..."

    if osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -q "$APP_NAME"; then
        osascript -e "tell application \"System Events\" to delete login item \"$APP_NAME\"" 2>/dev/null || true
        print_success "Removed from login items"
    else
        print_success "Not in login items"
    fi
}

# Remove app from Applications
remove_app() {
    print_step "Removing application..."

    if [[ -d "$APP_DEST" ]]; then
        rm -rf "$APP_DEST"
        print_success "Removed $APP_DEST"
    else
        print_success "Application not installed"
    fi
}

# Remove configuration
remove_config() {
    if [[ -d "$CONFIG_DIR" ]]; then
        echo ""
        read -p "Would you like to remove configuration files at ${CONFIG_DIR}? [y/N] " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            print_success "Removed $CONFIG_DIR"
        else
            print_warning "Configuration preserved at $CONFIG_DIR"
        fi
    fi
}

# Remove Xcode derived data (optional)
remove_build_data() {
    DERIVED_DATA=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "StockTicker-*" -type d 2>/dev/null | head -1)

    if [[ -n "$DERIVED_DATA" && -d "$DERIVED_DATA" ]]; then
        echo ""
        read -p "Would you like to remove Xcode build cache? [y/N] " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$DERIVED_DATA"
            print_success "Removed build cache"
        else
            print_warning "Build cache preserved"
        fi
    fi
}

# Main uninstall flow
main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║       ${APP_NAME} Uninstaller           ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Confirm uninstall
    read -p "Are you sure you want to uninstall ${APP_NAME}? [y/N] " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi

    echo ""

    stop_app
    remove_login_item
    remove_app
    remove_config
    remove_build_data

    echo ""
    echo "════════════════════════════════════════"
    print_success "Uninstall complete!"
    echo ""
}

# Run main
main
