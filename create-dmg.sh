#!/bin/bash
# Create a styled DMG installer for ClipStash (Docker-style layout)
set -e

APP_NAME="ClipStash"
DMG_FINAL="${APP_NAME}-Installer.dmg"
DMG_TEMP="${APP_NAME}-temp.dmg"
VOLUME_NAME="${APP_NAME}"
STAGING_DIR=".dmg-staging"
BG_IMG="dmg-background.png"
WINDOW_W=660
WINDOW_H=400
ICON_SIZE=128

echo "=== Building ClipStash ==="
swift build -c release 2>&1 | grep -E "(Build complete|error:)"

echo "=== Creating .app bundle ==="
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"
cp ".build/release/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
cp "ClipStash/Resources/Info.plist" "${APP_NAME}.app/Contents/Info.plist"

echo "=== Creating DMG ==="
rm -rf "${STAGING_DIR}" "${DMG_FINAL}" "${DMG_TEMP}"
mkdir -p "${STAGING_DIR}"

# Copy app and create Applications symlink
cp -R "${APP_NAME}.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# Copy background
mkdir -p "${STAGING_DIR}/.background"
cp "${BG_IMG}" "${STAGING_DIR}/.background/background.png"

# Create a read-write DMG first (needed for AppleScript styling)
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDRW \
    "${DMG_TEMP}" 2>/dev/null

# Mount it
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "${DMG_TEMP}" | grep "/Volumes/" | tail -1 | awk '{print $NF}')
echo "Mounted at: ${MOUNT_DIR}"

# Wait for mount
sleep 2

# Apply styling with AppleScript
echo "=== Styling DMG window ==="
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 200, $((200 + WINDOW_W)), $((200 + WINDOW_H))}

        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to ${ICON_SIZE}
        set background picture of theViewOptions to file ".background:background.png"

        -- Position icons: app on left, Applications on right
        set position of item "${APP_NAME}.app" to {170, 220}
        set position of item "Applications" to {490, 220}

        update without registering applications
        close
    end tell
end tell
APPLESCRIPT

# Make sure changes are synced
sync

# Unmount
hdiutil detach "${MOUNT_DIR}" -quiet 2>/dev/null || true
sleep 1

# Convert to compressed read-only DMG
hdiutil convert "${DMG_TEMP}" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL}" 2>/dev/null

# Clean up
rm -rf "${STAGING_DIR}" "${DMG_TEMP}"

echo ""
echo "=== Done! ==="
echo "Created: ${DMG_FINAL}"
echo "Size: $(du -h "${DMG_FINAL}" | cut -f1)"
