#!/bin/bash

# Secure script to set up local Firebase config for multiplayer testing
# This script helps you safely use Firebase secrets locally without committing them

echo "🔐 Setting up secure local Firebase config..."

if [ -f ".env" ]; then
    echo "✅ Found .env file"
    # shellcheck disable=SC1091
    source .env
else
    echo "❌ No .env file found. Create one with your Firebase config values."
    echo "   See .env.example or check GitHub repository secrets."
    exit 1
fi

# Create backup of stub config
cp lib/firebase_options.dart lib/firebase_options_stub_backup.dart

echo "🔥 Applying Firebase config for local development..."
bash scripts/generate_firebase_options_from_env.sh lib/firebase_options.dart

echo "✅ Local Firebase config applied"
echo "🚀 You can now run: flutter run"
echo ""
echo "⚠️  IMPORTANT: To restore stub config after testing, run:"
echo "   git checkout lib/firebase_options.dart"
echo "   OR: mv lib/firebase_options_stub_backup.dart lib/firebase_options.dart"
echo ""
echo "🔒 This config will NOT be committed to git (it's temporary for local testing only)"
