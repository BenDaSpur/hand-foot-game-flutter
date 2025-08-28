#!/bin/bash

# Secure script to set up local Firebase config for multiplayer testing
# This script helps you safely use Firebase secrets locally without committing them

echo "🔐 Setting up secure local Firebase config..."

if [ -f ".env" ]; then
    echo "✅ Found .env file"
    source .env
else
    echo "❌ No .env file found. Create one with your Firebase config values."
    echo "   See .env.example or check GitHub repository secrets."
    exit 1
fi

# Check if required Firebase variables are set
if [ -z "$FIREBASE_PROJECT_ID" ] || [ -z "$FIREBASE_WEB_API_KEY" ] || [ -z "$FIREBASE_WEB_APP_ID" ]; then
    echo "❌ Missing required Firebase environment variables in .env"
    echo "   Required: FIREBASE_PROJECT_ID, FIREBASE_WEB_API_KEY, FIREBASE_WEB_APP_ID"
    echo "   Check your .env file or GitHub repository secrets for values"
    exit 1
fi

# Create backup of stub config
cp lib/firebase_options.dart lib/firebase_options_stub_backup.dart

# Apply Firebase config temporarily
echo "🔥 Applying Firebase config for local development..."

cat > lib/firebase_options.dart << EOF
// TEMPORARY LOCAL CONFIG - DO NOT COMMIT THIS FILE!
// This file is auto-generated for local development only
// The original stub config is backed up as firebase_options_stub_backup.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return web;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '$FIREBASE_WEB_API_KEY',
    appId: '$FIREBASE_WEB_APP_ID',
    messagingSenderId: '$FIREBASE_MESSAGING_SENDER_ID',
    projectId: '$FIREBASE_PROJECT_ID',
    authDomain: '$FIREBASE_PROJECT_ID.firebaseapp.com',
    storageBucket: '$FIREBASE_STORAGE_BUCKET',
    measurementId: '$FIREBASE_WEB_MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '$FIREBASE_ANDROID_API_KEY',
    appId: '$FIREBASE_ANDROID_APP_ID',
    messagingSenderId: '$FIREBASE_MESSAGING_SENDER_ID',
    projectId: '$FIREBASE_PROJECT_ID',
    storageBucket: '$FIREBASE_STORAGE_BUCKET',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '$FIREBASE_IOS_API_KEY',
    appId: '$FIREBASE_IOS_APP_ID',
    messagingSenderId: '$FIREBASE_MESSAGING_SENDER_ID',
    projectId: '$FIREBASE_PROJECT_ID',
    storageBucket: '$FIREBASE_STORAGE_BUCKET',
    iosBundleId: '$FIREBASE_IOS_BUNDLE_ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: '$FIREBASE_MACOS_API_KEY',
    appId: '$FIREBASE_MACOS_APP_ID',
    messagingSenderId: '$FIREBASE_MESSAGING_SENDER_ID',
    projectId: '$FIREBASE_PROJECT_ID',
    storageBucket: '$FIREBASE_STORAGE_BUCKET',
    iosBundleId: '$FIREBASE_MACOS_BUNDLE_ID',
  );
}
EOF

echo "✅ Local Firebase config applied"
echo "🚀 You can now run: flutter run"
echo ""
echo "⚠️  IMPORTANT: To restore stub config after testing, run:"
echo "   git checkout lib/firebase_options.dart"
echo "   OR: mv lib/firebase_options_stub_backup.dart lib/firebase_options.dart"
echo ""
echo "🔒 This config will NOT be committed to git (it's temporary for local testing only)"