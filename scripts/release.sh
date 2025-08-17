#!/bin/bash

# Hand & Foot Game Release Script
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.0.0

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.0"
    exit 1
fi

VERSION="$1"
TAG="v$VERSION"

echo "🎮 Creating release for Hand & Foot Game v$VERSION"

# Update pubspec.yaml version
echo "📝 Updating pubspec.yaml version..."
sed -i.bak "s/^version: .*/version: $VERSION+1/" pubspec.yaml
rm pubspec.yaml.bak

# Commit version update
echo "📦 Committing version update..."
git add pubspec.yaml
git commit -m "chore: bump version to $VERSION"

# Create and push tag
echo "🏷️  Creating git tag $TAG..."
git tag -a "$TAG" -m "Release $TAG

🎮 Hand & Foot Card Game Release $TAG

Features:
- Beautiful Balatro-inspired neon theme
- Smart AI opponents with strategic gameplay  
- Complete Hand & Foot rules implementation
- Multi-platform support (Android, iOS, Web, Desktop)

Download the appropriate build for your platform from the release assets!"

echo "🚀 Pushing tag to trigger release build..."
git push origin "$TAG"

echo "✅ Release $TAG created successfully!"
echo "🔗 GitHub Actions will now build and create the release automatically."
echo "📱 Check https://github.com/BenDaSpur/hand-foot-game-flutter/releases for downloads once complete."