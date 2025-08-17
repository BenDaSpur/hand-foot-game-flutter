#!/bin/bash

# Format and test script for Flutter Hand & Foot game
# This script formats code, runs tests, and checks for issues

echo "🔧 Formatting Dart code..."
dart format .

echo "📋 Running code analysis..."
dart analyze

echo "🧪 Running tests..."
flutter test

echo "✅ All checks completed!"