#!/bin/bash

# Export analytics data from Firebase for Claude analysis
# Usage: ./scripts/export_analytics.sh [days] [output_file]

echo "🔥 Hand & Foot Analytics Exporter"
echo "================================"

# Set defaults
DAYS=${1:-14}
OUTPUT=${2:-"analytics_export.json"}

echo "📋 Exporting last $DAYS days to $OUTPUT"
echo ""

# Check if Flutter/Dart is available
if ! command -v dart &> /dev/null; then
    echo "❌ Dart not found. Make sure Flutter is installed and in PATH."
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Please run this script from the Flutter project root directory"
    exit 1
fi

# Get dependencies if needed
if [ ! -d ".dart_tool" ]; then
    echo "📦 Getting Flutter dependencies..."
    flutter pub get
fi

# Try the main export script first, fallback to simple export if it fails
echo "🚀 Running export..."
if dart run scripts/export_analytics.dart --days $DAYS --output $OUTPUT 2>/dev/null; then
    echo "✅ Export successful!"
else
    echo "⚠️  Main export failed (likely Flutter SDK issues), creating template..."
    dart scripts/simple_export.dart $DAYS $OUTPUT
fi

# Check if export was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Export completed successfully!"
    echo "📄 Analytics data saved to: $OUTPUT"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Open $OUTPUT in a text editor"
    echo "  2. Copy the JSON content"
    echo "  3. Share it with Claude for AI analysis"
    echo ""
    
    # Show file size for reference
    if [ -f "$OUTPUT" ]; then
        SIZE=$(du -h "$OUTPUT" | cut -f1)
        echo "📊 File size: $SIZE"
    fi
else
    echo "❌ Export failed. Check the error messages above."
    exit 1
fi