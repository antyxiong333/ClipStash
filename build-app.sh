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
ENTITLEMENTS_PATH="ClipStash/Resources/ClipStash.entitlements"

echo "Generating app icon..."
swift scripts/generate-app-icon.swift
iconutil -c icns -o "ClipStash/Resources/AppIcon.icns" "ClipStash/Resources/AppIcon.iconset"

# Clean previous build
rm -rf "$APP_DIR"

# Create .app structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "ClipStash/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy app icon if it has been generated
if [ -f "ClipStash/Resources/AppIcon.icns" ]; then
    cp "ClipStash/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# The lightweight local inference runtime is bundled; language-model weights
# are downloaded by ClipStash on demand into Application Support.
if [ -d "Vendor/llama-runtime" ]; then
    cp -R "Vendor/llama-runtime" "$RESOURCES_DIR/LocalInference"
fi

# Prefer this Mac's Apple Development identity. Other machines fall back to
# ad-hoc signing unless CLIPSTASH_SIGNING_IDENTITY is provided explicitly.
LOCAL_DEVELOPMENT_IDENTITY="Apple Development: Created via API (GFK6Y5HGLR)"
if [ -n "${CLIPSTASH_SIGNING_IDENTITY:-}" ]; then
    SIGNING_IDENTITY="$CLIPSTASH_SIGNING_IDENTITY"
elif security find-identity -v -p codesigning | grep -Fq "$LOCAL_DEVELOPMENT_IDENTITY"; then
    SIGNING_IDENTITY="$LOCAL_DEVELOPMENT_IDENTITY"
else
    SIGNING_IDENTITY="-"
fi

if [ "$SIGNING_IDENTITY" = "-" ]; then
    if [ -d "$RESOURCES_DIR/LocalInference" ]; then
        find "$RESOURCES_DIR/LocalInference" -type f \( -name "*.dylib" -o -name "llama-server" \) -exec codesign --force --sign - {} \;
    fi
    codesign --force --sign - --identifier com.clipstash.app \
        --entitlements "$ENTITLEMENTS_PATH" "$APP_DIR"
elif [[ "$SIGNING_IDENTITY" == Developer\ ID\ Application:* ]]; then
    if [ -d "$RESOURCES_DIR/LocalInference" ]; then
        find "$RESOURCES_DIR/LocalInference" -type f \( -name "*.dylib" -o -name "llama-server" \) -exec codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" {} \;
    fi
    codesign --force --options runtime --timestamp \
        --sign "$SIGNING_IDENTITY" --identifier com.clipstash.app \
        --entitlements "$ENTITLEMENTS_PATH" "$APP_DIR"
else
    if [ -d "$RESOURCES_DIR/LocalInference" ]; then
        find "$RESOURCES_DIR/LocalInference" -type f \( -name "*.dylib" -o -name "llama-server" \) -exec codesign --force --options runtime --timestamp=none --sign "$SIGNING_IDENTITY" {} \;
    fi
    codesign --force --options runtime --timestamp=none \
        --sign "$SIGNING_IDENTITY" --identifier com.clipstash.app \
        --entitlements "$ENTITLEMENTS_PATH" "$APP_DIR"
fi
codesign --verify --strict "$APP_DIR"

echo "Built $APP_DIR successfully!"
echo "You can now:"
echo "  1. Double-click $APP_DIR to launch"
echo "  2. Drag $APP_DIR to /Applications"
echo "  3. Run: open $APP_DIR"
