#!/bin/bash

set -e

PROJECT_DIR="/Users/nicholasweiner/Desktop/LORA Comms"
PROJECT_NAME="LORA Comms"
SCHEME="LORA Comms"
DERIVED_DATA_PATH="$PROJECT_DIR/DerivedData"
BUILD_DIR="$DERIVED_DATA_PATH/Build/Products/Debug"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"
ENTITLEMENTS_PATH="$PROJECT_DIR/LORA Comms/LORA Comms.entitlements"
SIGNING_IDENTITY="Apple Development: Nicholas Weiner (4JGA686QU4)"

echo "🧹 Cleaning build directory..."
rm -rf "$DERIVED_DATA_PATH" || true

echo "🦀 Building Rust core with Meshtastic protocol support..."
cd "$PROJECT_DIR/Core"
cargo build --release --features="serial,bluetooth"
cd "$PROJECT_DIR"

echo "🔨 Building project..."
xcodebuild -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -arch arm64 \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    build

echo "🧹 Cleaning app bundle of extended attributes..."
find "$APP_PATH" -name "._*" -delete 2>/dev/null || true
find "$APP_PATH" -name ".DS_Store" -delete 2>/dev/null || true
xattr -cr "$APP_PATH" 2>/dev/null || true

echo "✍️ Code signing app bundle..."
# Sign the frameworks and dylibs first
find "$APP_PATH" -name "*.dylib" -exec codesign --force --sign "$SIGNING_IDENTITY" {} \; 2>/dev/null || true

# Then sign the main app bundle
codesign --force --deep --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" "$APP_PATH"

echo "✅ Verifying code signature..."
codesign --verify --verbose "$APP_PATH"

echo "🎉 Build and signing completed successfully!"
echo "App location: $APP_PATH"

# Also create a symlink in the project root for easy access
ln -sf "$APP_PATH" "$PROJECT_DIR/LORA Comms.app" 2>/dev/null || true
echo "Symlink created: $PROJECT_DIR/LORA Comms.app"
