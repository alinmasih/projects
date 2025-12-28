#!/bin/bash
# Run the Flutter medicine tracker app

set -e

echo "📱 Medicine Tracker Flutter App"
echo "==============================="

cd app

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found!"
    echo "   Install from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -1)"

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Run app
echo "🚀 Starting Flutter app..."
echo "   Make sure an Android emulator is running or device is connected"
echo ""

flutter run
