#!/bin/bash
# Helper script to run Flutter commands with Firebase configuration from GitHub Secrets

# Run flutter with Firebase configuration and all passed arguments
flutter \
  --dart-define=FIREBASE_WEB_API_KEY="$FIREBASE_WEB_API_KEY" \
  --dart-define=FIREBASE_WEB_APP_ID="$FIREBASE_WEB_APP_ID" \
  --dart-define=FIREBASE_WEB_MEASUREMENT_ID="$FIREBASE_WEB_MEASUREMENT_ID" \
  --dart-define=FIREBASE_ANDROID_API_KEY="$FIREBASE_ANDROID_API_KEY" \
  --dart-define=FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID" \
  --dart-define=FIREBASE_IOS_API_KEY="$FIREBASE_IOS_API_KEY" \
  --dart-define=FIREBASE_IOS_APP_ID="$FIREBASE_IOS_APP_ID" \
  --dart-define=FIREBASE_IOS_BUNDLE_ID="$FIREBASE_IOS_BUNDLE_ID" \
  --dart-define=FIREBASE_MACOS_API_KEY="$FIREBASE_MACOS_API_KEY" \
  --dart-define=FIREBASE_MACOS_APP_ID="$FIREBASE_MACOS_APP_ID" \
  --dart-define=FIREBASE_MACOS_BUNDLE_ID="$FIREBASE_MACOS_BUNDLE_ID" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  "$@"