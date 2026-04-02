#!/bin/bash
# Build ClipStash and create a proper .app bundle

set -e

echo "Building ClipStash..."
swift build -c release 2>&1

APP_NAME="ClipStash"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous build
rm -rf "$APP_DIR"

# Create .app structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "ClipStash/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "Built $APP_DIR successfully!"
echo "You can now:"
echo "  1. Double-click $APP_DIR to launch"
echo "  2. Drag $APP_DIR to /Applications"
echo "  3. Run: open $APP_DIR"
