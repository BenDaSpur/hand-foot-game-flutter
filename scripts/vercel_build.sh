#!/usr/bin/env bash
set -euo pipefail

export PATH="$PWD/flutter/bin:$PATH"

if [ -n "${FIREBASE_WEB_CONFIG:-}" ]; then
  echo "Injecting production Firebase config from FIREBASE_WEB_CONFIG"
  echo "$FIREBASE_WEB_CONFIG" | base64 -d > lib/firebase_options.dart
  if ! grep -q "class DefaultFirebaseOptions" lib/firebase_options.dart; then
    echo "Error: Firebase config does not contain expected DefaultFirebaseOptions class"
    exit 1
  fi
else
  echo "FIREBASE_WEB_CONFIG not set — using stub config (solo play only)"
fi

BUILD_NUMBER="${VERCEL_GIT_COMMIT_SHA:-local}"
echo "Building web release with BUILD_NUMBER=$BUILD_NUMBER"

flutter build web --release --dart-define=BUILD_NUMBER="$BUILD_NUMBER"
