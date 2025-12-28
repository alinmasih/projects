#!/bin/bash
# Deploy Firestore and Storage security rules

set -e

echo "🔐 Deploying Firebase Security Rules"
echo "===================================="

# Check Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo "   Install: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found"

# Check if logged in
echo "Checking Firebase login..."
if ! firebase projects:list &> /dev/null; then
    echo "🔑 Logging in to Firebase..."
    firebase login
fi

# List projects
echo ""
echo "Available Firebase projects:"
firebase projects:list

echo ""
read -p "Enter Firebase project ID: " PROJECT_ID

echo ""
echo "Deploying to project: $PROJECT_ID"

# Deploy Firestore rules
echo "📝 Deploying Firestore rules..."
firebase deploy --only firestore:rules --project "$PROJECT_ID"

# Deploy Storage rules
echo "📝 Deploying Storage rules..."
firebase deploy --only storage:rules --project "$PROJECT_ID"

echo ""
echo "✅ Rules deployed successfully!"
