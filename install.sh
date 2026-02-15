#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="StockTicker"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DEST="/Applications/${APP_NAME}.app"
CONFIG_DIR="$HOME/.stockticker"
CONFIG_FILE="$CONFIG_DIR/config.json"

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

# Check macOS version
check_macos_version() {
    print_step "Checking macOS version..."

    macos_version=$(sw_vers -productVersion)
    major_version=$(echo "$macos_version" | cut -d. -f1)

    if [[ "$major_version" -lt 13 ]]; then
        print_error "macOS 13.0 (Ventura) or later required. You have $macos_version"
        exit 1
    fi

    print_success "macOS $macos_version"
}

# Check Xcode installation
check_xcode() {
    print_step "Checking Xcode installation..."

    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed. Please install Xcode from the App Store."
        exit 1
    fi

    # Check if Xcode (not just Command Line Tools) is selected
    xcode_path=$(xcode-select -p 2>/dev/null)
    if [[ "$xcode_path" == "/Library/Developer/CommandLineTools" ]]; then
        print_warning "Xcode Command Line Tools selected, but full Xcode is required."
        echo ""
        echo "Run the following command to switch to Xcode:"
        echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        echo ""
        read -p "Would you like to run this now? (requires sudo) [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
            print_success "Switched to Xcode"
        else
            print_error "Please run the command manually and re-run this script."
            exit 1
        fi
    fi

    xcode_version=$(xcodebuild -version | head -1)
    print_success "$xcode_version"
}

# Build the app
build_app() {
    print_step "Building ${APP_NAME}..."

    cd "$PROJECT_DIR"

    if xcodebuild -project "${APP_NAME}.xcodeproj" \
                  -scheme "$APP_NAME" \
                  -configuration Release \
                  build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"; then

        # Check if build actually succeeded
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            print_error "Build failed"
            exit 1
        fi
    fi

    # Find the built app
    BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "${APP_NAME}.app" -path "*/Release/*" -type d 2>/dev/null | head -1)

    if [[ -z "$BUILT_APP" || ! -d "$BUILT_APP" ]]; then
        print_error "Could not find built app"
        exit 1
    fi

    print_success "Build complete: $BUILT_APP"
}

# Stop running instance
stop_app() {
    if pgrep -x "$APP_NAME" > /dev/null; then
        print_step "Stopping running instance..."
        pkill -x "$APP_NAME" || true
        sleep 1
        print_success "Stopped"
    fi
}

# Install the app
install_app() {
    print_step "Installing to /Applications..."

    # Remove existing installation
    if [[ -d "$APP_DEST" ]]; then
        rm -rf "$APP_DEST"
    fi

    # Copy new build
    cp -R "$BUILT_APP" "$APP_DEST"

    print_success "Installed to $APP_DEST"
}

# Create default config if needed
create_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        print_success "Configuration exists at $CONFIG_FILE"
        return
    fi

    print_step "Creating default configuration..."
    mkdir -p "$CONFIG_DIR"

    # Let the app create its default config on first launch
    print_success "Config will be created on first launch"
}

# Run a command with a timeout (portable, no coreutils needed)
run_with_timeout() {
    local secs=$1; shift
    "$@" &
    local pid=$!
    ( sleep "$secs"; kill "$pid" 2>/dev/null ) &
    local watchdog=$!
    wait "$pid" 2>/dev/null
    local rc=$?
    kill "$watchdog" 2>/dev/null
    wait "$watchdog" 2>/dev/null
    return $rc
}

# Setup login item
setup_login_item() {
    print_step "Checking login items..."

    # Check if already in login items (timeout after 5s to avoid hanging on permission prompts)
    local login_items
    if login_items=$(run_with_timeout 5 osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null); then
        if echo "$login_items" | grep -q "$APP_NAME"; then
            print_success "Already configured to start at login"
            return
        fi
    else
        print_warning "Could not check login items (permission required or timed out)"
        return
    fi

    # Non-interactive (piped stdin) — add silently
    if [[ ! -t 0 ]]; then
        if run_with_timeout 5 osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP_DEST\", hidden:false}" > /dev/null 2>&1; then
            print_success "Added to login items"
        else
            print_warning "Could not add login item"
        fi
        return
    fi

    echo ""
    read -p "Would you like ${APP_NAME} to start automatically at login? [Y/n] " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP_DEST\", hidden:false}" > /dev/null
        print_success "Added to login items"
    else
        print_warning "Skipped login item setup"
    fi
}

# Launch the app
launch_app() {
    print_step "Launching ${APP_NAME}..."
    open "$APP_DEST"
    sleep 1

    if pgrep -x "$APP_NAME" > /dev/null; then
        print_success "Running - check your menu bar!"
    else
        print_warning "App may not have started. Try opening manually."
    fi
}

# Main installation flow
main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║       ${APP_NAME} Installer             ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    check_macos_version
    check_xcode
    build_app
    stop_app
    install_app
    create_config
    setup_login_item
    launch_app

    echo ""
    echo "════════════════════════════════════════"
    print_success "Installation complete!"
    echo ""
    echo "Configuration file: $CONFIG_FILE"
    echo "To edit symbols, click the menu bar item and select 'Edit Watchlist...'"
    echo ""
}

# Run main
main
