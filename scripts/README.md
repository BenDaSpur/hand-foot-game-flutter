# Analytics Export Scripts

These scripts allow you to export bot performance analytics data directly from Firebase for external analysis.

## Quick Export

### Using the Shell Script (Recommended)
```bash
# Export last 14 days of data
./scripts/export_analytics.sh

# Export last 30 days
./scripts/export_analytics.sh 30

# Export to specific file
./scripts/export_analytics.sh 14 my_analytics.json
```

### Using Dart Directly
```bash
# Basic export
dart run scripts/export_analytics.dart

# With options
dart run scripts/export_analytics.dart --days 30 --output analytics.json --include-raw
```

## Command Options

### Dart Script Options
- `--days <number>`: Number of days to export (default: 14)
- `--include-raw`: Include raw session data for detailed analysis
- `--output <file>`: Output filename (default: analytics_export.json)
- `--basic-format`: Export basic format instead of Claude-optimized
- `--help`: Show help message

### Shell Script Parameters
1. **Days** (optional): Number of days to export (default: 14)
2. **Output file** (optional): Filename (default: analytics_export.json)

## Output Format

The scripts export data in a Claude-optimized JSON format containing:

### Context Section
- **Purpose**: Description of what the data is for
- **Game Description**: Explanation of Hand & Foot card game
- **Personalities**: Detailed description of each bot personality type
- **Key Metrics**: Definition of all performance metrics
- **Analysis Questions**: Suggested questions for Claude to address

### Analytics Data Section
- **Summary**: Overall statistics (total sessions, bot instances, readiness)
- **Personality Performance**: Win rates, scores, success rates by personality
- **Challenging Scenarios**: Seeds where each personality struggles most
- **Raw Session Data**: Complete session records (if --include-raw used)

## Example Usage

### Check if Data is Ready
```bash
# Quick check - if you get "Ready for Analysis: ✅ YES", you have enough data
./scripts/export_analytics.sh 7 quick_check.json
```

### Export for Claude Analysis
```bash
# Export 2 weeks of data for comprehensive analysis
./scripts/export_analytics.sh 14 claude_analysis.json

# Then copy the contents of claude_analysis.json and share with Claude
```

### Debug Specific Issues
```bash
# Include raw data for deep debugging
dart run scripts/export_analytics.dart --days 7 --include-raw --output debug_data.json
```

## Data Requirements

For meaningful analysis, the system needs:
- **Minimum 20 game sessions**
- **Minimum 50 bot instances** across all personalities
- **Multiple examples** of each personality type

The export will show "Ready for Analysis: ✅ YES" when you have enough data.

## Sharing with Claude

1. **Run the export**: `./scripts/export_analytics.sh`
2. **Open the JSON file** in a text editor
3. **Copy all contents** 
4. **Paste in Claude Code** with a message like:

> "Here's my bot performance analytics data. Can you analyze which personalities are performing best and suggest improvements?"

## Troubleshooting

### "Dart not found"
Make sure Flutter is installed and in your PATH:
```bash
flutter doctor
```

### "Permission denied"
Make the script executable:
```bash
chmod +x scripts/export_analytics.sh
```

### "Firebase connection failed"
Ensure your Firebase configuration is correct in `lib/firebase_options.dart`

### "No data found"
- Check that analytics are enabled in your app
- Verify you've played enough games to generate data
- Try increasing the days parameter

## File Structure

```
scripts/
├── README.md                 # This file
├── export_analytics.dart     # Main export logic
└── export_analytics.sh       # Simple shell wrapper
```