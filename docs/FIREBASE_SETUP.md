# Firebase Setup Instructions

This project uses Firebase with secrets stored in environment variables for security.

## Required GitHub Secrets

Add these secrets to your GitHub repository settings (`Settings > Secrets and variables > Actions > New repository secret`):

### Web Platform
- `FIREBASE_WEB_API_KEY`: `AIzaSyBpzXBxG_5_Fh6JBwqTQ4-K5tQ-SvDI8kE`
- `FIREBASE_WEB_APP_ID`: `1:1025181566550:web:5fb8f9f93e5c5c50abddf7`
- `FIREBASE_WEB_MEASUREMENT_ID`: `G-0M45KY6JEE`

### Android Platform
- `FIREBASE_ANDROID_API_KEY`: `AIzaSyDt8evUZ1-LX_fDZ790GnFtb4XVcQBw5MA`
- `FIREBASE_ANDROID_APP_ID`: `1:1025181566550:android:de35e743efbf1ae0abddf7`

### iOS Platform
- `FIREBASE_IOS_API_KEY`: `AIzaSyCoC0t8RKiDu37z8RPDCCkWrz8Xugj6Hus`
- `FIREBASE_IOS_APP_ID`: `1:1025181566550:ios:6501592fba896d39abddf7`
- `FIREBASE_IOS_BUNDLE_ID`: `com.example.handFootGameFlutter`

### macOS Platform
- `FIREBASE_MACOS_API_KEY`: `AIzaSyCoC0t8RKiDu37z8RPDCCkWrz8Xugj6Hus`
- `FIREBASE_MACOS_APP_ID`: `1:1025181566550:macos:a7c20e6ec0fcb1b2abddf7`
- `FIREBASE_MACOS_BUNDLE_ID`: `com.example.handFootGameFlutter`

### Shared Configuration
- `FIREBASE_MESSAGING_SENDER_ID`: `1025181566550`
- `FIREBASE_PROJECT_ID`: `hand-foot-game-flutter`
- `FIREBASE_STORAGE_BUCKET`: `hand-foot-game-flutter.firebasestorage.app`

## Local Development Setup

For local development, create the following files from their templates:

### 1. Copy Firebase Options
```bash
cp lib/firebase_options.dart.template lib/firebase_options.dart
```

### 2. Create Local Config Files
Create these files with the Firebase configuration:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`  
- `macos/Runner/GoogleService-Info.plist`

You can download these from the Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your `hand-foot-game-flutter` project
3. Go to Project Settings > General
4. Download the config files for each platform

### 3. Set Environment Variables
For local testing, you can set environment variables:

```bash
export FIREBASE_WEB_API_KEY="AIzaSyBpzXBxG_5_Fh6JBwqTQ4-K5tQ-SvDI8kE"
export FIREBASE_PROJECT_ID="hand-foot-game-flutter"
# ... add all other variables
```

## GitHub Actions Setup

The repository includes automated CI/CD workflows that properly handle Firebase secrets:

### CI Workflow (`ci.yml`)
- Automatically generates `firebase_options.dart` from template
- Runs tests and analysis with proper Firebase configuration
- Triggered on all pushes and pull requests

### Firebase Build Workflow (`firebase-build.yml`)
- Comprehensive build pipeline for all platforms
- Generates Firebase config for Android, Web, iOS, macOS, Linux
- Creates releases with proper Firebase integration
- Deploys to GitHub Pages with Firebase enabled

Both workflows use the GitHub Secrets listed above to generate the Firebase configuration at build time.

## Security Notes

- **DO NOT** commit the actual config files to git
- All sensitive Firebase configuration is excluded via `.gitignore`
- The template uses `String.fromEnvironment()` to read secrets safely
- Client-side Firebase API keys are safe to use in public repositories when properly configured with Firebase Security Rules

## Firebase Console Access

- Project ID: `hand-foot-game-flutter`
- Console: https://console.firebase.google.com/project/hand-foot-game-flutter