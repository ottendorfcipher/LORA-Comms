#!/bin/bash

set -e

echo "🦀 Building Rust Core Library..."
cd Core
cargo build --release --features serial
cd ..

echo "📱 Building Swift App..."
# Build the app using xcodebuild
PROJECT_DIR="$(pwd)"
RUST_LIB_PATH="$PROJECT_DIR/Core/target/release"
SHARED_PATH="$PROJECT_DIR/Shared"
BRIDGE_HEADER="$PROJECT_DIR/Shared/lora_comms_bridge.h"

# Clean any extended attributes first
xattr -cr .
find . -name "._*" -delete 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true

# Build without codesigning first
xcodebuild \
    -project "LORA Comms.xcodeproj" \
    -scheme "LORA Comms" \
    -configuration Debug \
    -derivedDataPath "./DerivedData" \
    LIBRARY_SEARCH_PATHS="$RUST_LIB_PATH" \
    HEADER_SEARCH_PATHS="$SHARED_PATH" \
    SWIFT_OBJC_BRIDGING_HEADER="$BRIDGE_HEADER" \
    OTHER_LDFLAGS="-L\"$RUST_LIB_PATH\" -llora_comms_core -framework Security -framework CoreFoundation -framework IOKit" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

echo "🚀 Running the app..."
# Find the built app
APP_PATH=$(find ./DerivedData -name "LORA Comms.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find built app"
    exit 1
fi

echo "Found app at: $APP_PATH"
open "$APP_PATH"
