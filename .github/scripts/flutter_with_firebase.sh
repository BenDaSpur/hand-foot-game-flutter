#!/bin/bash
# Helper script to run Flutter commands with Firebase configuration from GitHub Secrets

# Enable basic error handling (less strict to avoid compatibility issues)
set -e

# Logging function
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Check if we're building for web
IS_WEB_BUILD=false
for arg in "$@"; do
  if [ "$arg" = "web" ]; then
    IS_WEB_BUILD=true
    break
  fi
done

# Validate critical Firebase variables for web builds using simple if statements
if [ "$IS_WEB_BUILD" = "true" ]; then
  log "Detected web build - validating critical Firebase configuration..."
  
  missing_count=0
  if [ -z "${FIREBASE_WEB_API_KEY:-}" ]; then
    log "ERROR: Missing FIREBASE_WEB_API_KEY"
    missing_count=$((missing_count + 1))
  fi
  if [ -z "${FIREBASE_WEB_APP_ID:-}" ]; then
    log "ERROR: Missing FIREBASE_WEB_APP_ID" 
    missing_count=$((missing_count + 1))
  fi
  if [ -z "${FIREBASE_PROJECT_ID:-}" ]; then
    log "ERROR: Missing FIREBASE_PROJECT_ID"
    missing_count=$((missing_count + 1))
  fi
  
  if [ $missing_count -gt 0 ]; then
    log "Web builds require these variables to avoid Firebase authentication errors."
    exit 1
  fi
  
  log "✓ All critical Firebase web configuration present"
fi

# Build the Firebase dart-define flags using simple if statements
FIREBASE_FLAGS=""
firebase_vars_count=0

if [ -n "${FIREBASE_WEB_API_KEY:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_WEB_API_KEY=$FIREBASE_WEB_API_KEY"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_WEB_APP_ID:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_WEB_APP_ID=$FIREBASE_WEB_APP_ID"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_WEB_MEASUREMENT_ID:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_WEB_MEASUREMENT_ID=$FIREBASE_WEB_MEASUREMENT_ID"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_ANDROID_API_KEY:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_ANDROID_API_KEY=$FIREBASE_ANDROID_API_KEY"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_ANDROID_APP_ID:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_ANDROID_APP_ID=$FIREBASE_ANDROID_APP_ID"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_IOS_API_KEY:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_IOS_API_KEY=$FIREBASE_IOS_API_KEY"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_IOS_APP_ID:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_IOS_APP_ID=$FIREBASE_IOS_APP_ID"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_IOS_BUNDLE_ID:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_IOS_BUNDLE_ID=$FIREBASE_IOS_BUNDLE_ID"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_MACOS_API_KEY:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_MACOS_API_KEY=$FIREBASE_MACOS_API_KEY"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_MACOS_APP_ID:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_MACOS_APP_ID=$FIREBASE_MACOS_APP_ID"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_MACOS_BUNDLE_ID:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_MACOS_BUNDLE_ID=$FIREBASE_MACOS_BUNDLE_ID"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_MESSAGING_SENDER_ID:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_PROJECT_ID:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID"
  firebase_vars_count=$((firebase_vars_count + 1))
fi
if [ -n "${FIREBASE_STORAGE_BUCKET:-}" ]; then
  FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=FIREBASE_STORAGE_BUCKET=$FIREBASE_STORAGE_BUCKET"
  firebase_vars_count=$((firebase_vars_count + 1))
fi

# Log Firebase configuration status
if [ $firebase_vars_count -eq 0 ]; then
  log "WARNING: No Firebase environment variables found. Flutter will run without Firebase configuration."
else
  log "✓ Applied $firebase_vars_count Firebase configuration variables to Flutter build"
fi

# Log the command being executed (without exposing secrets)
log "Executing: flutter $* [with $firebase_vars_count Firebase dart-define flags]"

# Run flutter with Firebase configuration and all passed arguments
exec flutter "$@" $FIREBASE_FLAGS