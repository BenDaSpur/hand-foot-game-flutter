# Deployment Guide

## GitHub Pages Automatic Deployment

This project is configured with GitHub Actions to automatically build and deploy the Flutter web app to GitHub Pages.

### Setup Instructions

1. **Enable GitHub Pages** in your repository:
   - Go to your repository on GitHub
   - Navigate to Settings → Pages
   - Under "Source", select "GitHub Actions"
   - Save the settings

2. **Workflow Triggers**:
   - **Automatic**: Triggers on every push or merge to the `main` branch
   - **Manual**: Can be triggered manually from the Actions tab
   - **Pull Requests**: Builds and tests on PRs (but doesn't deploy)

3. **Deployment Process**:
   ```
   Push to main → Run tests → Analyze code → Build web → Deploy to Pages
   ```

### Workflow Features

- ✅ **Automated Testing**: Runs `flutter test` before deployment
- ✅ **Code Analysis**: Runs `flutter analyze` to catch issues
- ✅ **Optimized Build**: Uses CanvasKit renderer for better performance
- ✅ **Proper Base URL**: Configured for GitHub Pages subdirectory
- ✅ **Concurrent Safety**: Prevents multiple deployments at once
- ✅ **PR Safety**: Only deploys from main branch, not PRs

### Accessing Your Deployed App

Once deployed, your app will be available at:
```
https://bendaspur.github.io/hand-foot-game-flutter/
```

### Monitoring Deployments

- Check the **Actions** tab in your GitHub repository to see deployment status
- Failed deployments will show detailed error logs
- Successful deployments will provide the live URL

### Manual Deployment

To trigger a manual deployment:
1. Go to the **Actions** tab in your repository
2. Select "Deploy Flutter Web to GitHub Pages"
3. Click "Run workflow"
4. Choose the `main` branch and click "Run workflow"

### Troubleshooting

**Common Issues:**

1. **GitHub Pages not enabled**: Make sure Pages is set to "GitHub Actions" source
2. **Wrong base URL**: The app assumes it's deployed at `/hand-foot-game-flutter/`
3. **Permissions**: The workflow requires Pages write permissions (automatically granted)

**Build Failures:**
- Check test failures in the Actions log
- Ensure all dependencies are properly listed in `pubspec.yaml`
- Verify the Flutter version is compatible

### Local Testing

To test the web build locally:
```bash
flutter build web --release --web-renderer canvaskit
cd build/web
python -m http.server 8000
# Visit http://localhost:8000
```