#!/bin/bash
# Script to run Flutter with environment variables from .env file

# Check if .env exists
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    exit 1
fi

# Extract environment variables from .env file
export $(grep -v '^#' .env | xargs)

# Run Flutter with dart-define flags
flutter run \
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