#!/bin/bash
# Generate Firebase configuration from template using environment variables

echo "Generating Firebase configuration..."

# Check if template exists
if [ ! -f "lib/firebase_options.dart.template" ]; then
    echo "Error: lib/firebase_options.dart.template not found!"
    exit 1
fi

# Substitute environment variables in template
envsubst < lib/firebase_options.dart.template > lib/firebase_options.dart

echo "Firebase configuration generated successfully at lib/firebase_options.dart"

# Verify the file was created
if [ -f "lib/firebase_options.dart" ]; then
    echo "✅ firebase_options.dart generated successfully"
else
    echo "❌ Failed to generate firebase_options.dart"
    exit 1
fi