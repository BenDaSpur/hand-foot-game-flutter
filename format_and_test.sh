#!/bin/bash

# Fast quality checks script for Flutter Hand & Foot game
# Matches the optimized CI pipeline for consistent local testing

echo "🔧 Formatting Dart code..."
dart format .

echo "🧪 Running tests..."
flutter test

echo "📋 Running code analysis..."
flutter analyze --no-fatal-warnings

echo "📦 Verifying dependencies..."
flutter pub deps

echo "✅ All quality checks completed!"