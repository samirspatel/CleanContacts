#!/bin/bash

# xcrun notarytool store-credentials "AC_PASSWORD" \
#     --apple-id "sameg14@icloud.com" \
#     --team-id "L3Z9CXRSFM" \
#     --password "pzoa-wrzu-vucz-gzcv"

# Configuration
APP_NAME="CleanContacts"
SCHEME_NAME="CleanContacts"
DEVELOPER_ID="E28DC0BBC4E7FE3563B3937F2A68028FEF861912" # security find-identity -v -p codesigning
TEAM_ID="L3Z9CXRSFM"  # Replace with your Team ID
VERSION=$(xcrun agvtool what-version -terse)
ARCHIVE_PATH="$HOME/Desktop/$APP_NAME.xcarchive"
DMG_PATH="$HOME/Desktop/$APP_NAME-$VERSION.dmg"
NOTARIZATION_PROFILE="AC_PASSWORD"  # Set this up in your keychain

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "📦 Installing create-dmg..."
    brew install create-dmg
fi

echo "🚀 Building $APP_NAME version $VERSION..."

# Clean build folder
xcodebuild clean -scheme "$SCHEME_NAME" -configuration Release

# Create archive
xcodebuild archive \
    -scheme "$SCHEME_NAME" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE="Manual" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    SWIFT_OPTIMIZATION_LEVEL="-O" \
    SWIFT_COMPILATION_MODE="wholemodule"

if [ $? -ne 0 ]; then
    echo "❌ Archive failed"
    exit 1
fi

echo "✅ Archive created successfully"

# Export archive
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$HOME/Desktop/$APP_NAME" \
    -exportOptionsPlist "scripts/ExportOptions.plist"

if [ $? -ne 0 ]; then
    echo "❌ Export failed"
    exit 1
fi

echo "✅ App exported successfully"

# Create ZIP for notarization
echo "📦 Creating ZIP for notarization..."
cd "$HOME/Desktop/$APP_NAME"
ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"

# Notarize the app
echo "🔐 Notarizing app..."
xcrun notarytool submit "$HOME/Desktop/$APP_NAME/$APP_NAME.zip" \
    --keychain-profile "$NOTARIZATION_PROFILE" \
    --wait

if [ $? -ne 0 ]; then
    echo "❌ Notarization failed"
    exit 1
fi

echo "✅ App notarized successfully"

# Staple the ticket to the .app, not the zip
xcrun stapler staple "$HOME/Desktop/$APP_NAME/$APP_NAME.app"

if [ $? -ne 0 ]; then
    echo "❌ Stapling failed"
    exit 1
fi

echo "✅ Ticket stapled successfully"

# Clean up the zip file
rm "$HOME/Desktop/$APP_NAME/$APP_NAME.zip"

# Before creating DMG, check and remove existing DMG
if [ -f "$DMG_PATH" ]; then
    echo "Removing existing DMG..."
    rm "$DMG_PATH"
fi

echo "📦 Creating DMG..."
create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 200 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 600 185 \
    "$DMG_PATH" \
    "$HOME/Desktop/$APP_NAME/$APP_NAME.app"

if [ $? -ne 0 ]; then
    echo "❌ DMG creation failed"
    exit 1
fi

echo "✅ DMG created successfully at $DMG_PATH"

# Clean up
rm -rf "$ARCHIVE_PATH"
rm -rf "$HOME/Desktop/$APP_NAME"

echo "🎉 Build process completed successfully!" 