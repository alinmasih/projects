#!/bin/bash
# Start the Node.js WhatsApp medicine bot

set -e

echo "🤖 Medicine Tracker WhatsApp Bot"
echo "================================"

# Check for .env file
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "   Create .env from .env.example:"
    echo "   cp .env.example .env"
    exit 1
fi

# Check for Firebase credentials
CREDS_PATH=$(grep FIREBASE_CREDENTIALS_PATH .env | cut -d '=' -f 2)
if [ ! -f "$CREDS_PATH" ]; then
    echo "❌ Firebase credentials not found at: $CREDS_PATH"
    echo "   Download from Firebase Console → Project Settings → Service Accounts"
    exit 1
fi

echo "✅ Environment configured"
echo "Starting bot..."
echo ""

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Start the bot
echo "🚀 Starting WhatsApp bot..."
echo "   If this is the first run, scan the QR code with WhatsApp"
echo "   Press Ctrl+C to stop"
echo ""

npm start
