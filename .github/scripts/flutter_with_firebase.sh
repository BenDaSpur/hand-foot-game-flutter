#!/bin/bash
# Helper script to run Flutter commands with Firebase configuration from GitHub Secrets

# Enable strict error handling
set -euo pipefail

# Logging function
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Critical Firebase variables for Web builds
CRITICAL_WEB_VARS=("FIREBASE_WEB_API_KEY" "FIREBASE_WEB_APP_ID" "FIREBASE_PROJECT_ID")

# Check if we're building for web
IS_WEB_BUILD=false
for arg in "$@"; do
  if [[ "$arg" == "web" ]]; then
    IS_WEB_BUILD=true
    break
  fi
done

# Validate critical Firebase variables for web builds
if [[ "$IS_WEB_BUILD" == "true" ]]; then
  log "Detected web build - validating critical Firebase configuration..."
  missing_vars=()
  
  for var in "${CRITICAL_WEB_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing_vars+=("$var")
    fi
  done
  
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    log "ERROR: Missing critical Firebase environment variables for web build:"
    printf '  - %s\n' "${missing_vars[@]}" >&2
    log "Web builds require these variables to avoid Firebase authentication errors."
    exit 1
  fi
  
  log "✓ All critical Firebase web configuration present"
fi

# Build the Firebase dart-define flags
FIREBASE_FLAGS=""
firebase_vars_count=0

# Array of all Firebase environment variables
FIREBASE_VARS=(
  "FIREBASE_WEB_API_KEY"
  "FIREBASE_WEB_APP_ID" 
  "FIREBASE_WEB_MEASUREMENT_ID"
  "FIREBASE_ANDROID_API_KEY"
  "FIREBASE_ANDROID_APP_ID"
  "FIREBASE_IOS_API_KEY"
  "FIREBASE_IOS_APP_ID"
  "FIREBASE_IOS_BUNDLE_ID"
  "FIREBASE_MACOS_API_KEY"
  "FIREBASE_MACOS_APP_ID"
  "FIREBASE_MACOS_BUNDLE_ID"
  "FIREBASE_MESSAGING_SENDER_ID"
  "FIREBASE_PROJECT_ID"
  "FIREBASE_STORAGE_BUCKET"
)

# Build dart-define flags for each non-empty Firebase variable
for var in "${FIREBASE_VARS[@]}"; do
  if [[ -n "${!var:-}" ]]; then
    FIREBASE_FLAGS="$FIREBASE_FLAGS --dart-define=$var=${!var}"
    ((firebase_vars_count++))
  fi
done

# Log Firebase configuration status
if [[ $firebase_vars_count -eq 0 ]]; then
  log "WARNING: No Firebase environment variables found. Flutter will run without Firebase configuration."
else
  log "✓ Applied $firebase_vars_count Firebase configuration variables to Flutter build"
fi

# Log the command being executed (without exposing secrets)
log "Executing: flutter $* [with $firebase_vars_count Firebase dart-define flags]"

# Run flutter with Firebase configuration and all passed arguments
exec flutter "$@" $FIREBASE_FLAGS