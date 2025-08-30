# Game Analytics System

This document explains the comprehensive analytics system for tracking bot performance and game metrics.

## Overview

The analytics system consists of three main components:

1. **GameAnalyticsLogger** - Core logging service that writes to Firebase
2. **AnalyticsConfigService** - Privacy controls and configuration management  
3. **Integration Points** - Hooks in the game controllers and AI systems

## Data Collection

### Basic Analytics (Default: Enabled)
- **Game Sessions**: Duration, player counts, game modes, outcomes
- **Bot Performance**: Personality types, win rates, decision efficiency
- **Game Statistics**: Rounds played, score distributions, completion rates
- **Technical Metrics**: Device type, app version, error rates

### Detailed Logging (Default: Disabled, Opt-in Only)
- **Bot Decisions**: Detailed reasoning, context, alternative actions considered
- **Game State Analysis**: Turn-by-turn progression, decision outcomes
- **Performance Profiling**: Execution times, memory usage, optimization metrics

## Privacy Controls

### User Configuration
```dart
// Check current settings
bool basicEnabled = AnalyticsConfigService.isAnalyticsEnabled();
bool detailedEnabled = AnalyticsConfigService.isDetailedLoggingEnabled();

// Enable/disable analytics
await AnalyticsConfigService.setAnalyticsEnabled(true);
await AnalyticsConfigService.setDetailedLoggingEnabled(false);

// Get privacy information
Map<String, dynamic> privacyInfo = AnalyticsConfigService.getPrivacyInfo();
```

### Data Retention
- **Basic Analytics**: 30 days maximum
- **Detailed Logging**: 7 days maximum  
- **Automatic Cleanup**: Old data is automatically purged
- **User Deletion**: Users can request complete data deletion

## Firebase Collections

### game_sessions
```firestore
{
  sessionId: "session_1640995200000",
  startTime: timestamp,
  endTime: timestamp,
  gameMode: "singleplayer",
  totalPlayers: 3,
  botPlayers: 2,
  botPersonalities: {
    "aggressive": 1,
    "conservative": 1
  },
  gameSeed: 123456, // For reproducible game analysis
  finalScores: [1250, 980, 750],
  winnerId: "player_1",
  sessionDuration: 1800,
  botPerformance: {
    "bot_1": {
      personality: "aggressive",
      finalScore: 980,
      meldCount: 8,
      bookCount: 2,
      // ... more metrics
    }
  }
}
```

### bot_decisions  
```firestore
{
  sessionId: "session_1640995200000",
  timestamp: timestamp,
  botId: "bot_1",
  botPersonality: "aggressive",
  decision: "takePile",
  reasoning: "Pile contains valuable cards for book completion",
  confidence: 0.8,
  gameSeed: 123456, // Same seed for reproducible analysis
  gameContext: {
    round: 2,
    handSize: 12,
    opponentThreat: 0.3
  }
}
```

### game_events
```firestore
{
  sessionId: "session_1640995200000", 
  timestamp: timestamp,
  eventType: "meld_created",
  playerId: "player_1",
  playerType: "human",
  success: true,
  eventData: {
    cardCount: 5,
    pointValue: 150
  }
}
```

## Bot Performance Analysis

### Querying Analytics
```dart
// Get general performance data for a personality
Map<String, dynamic>? analytics = await GameAnalyticsLogger.getBotPerformanceAnalytics(
  personality: BotPersonality.aggressive,
  limitDays: 7,
);

// Analyze performance on a specific game seed
Map<String, dynamic>? seedAnalytics = await GameAnalyticsLogger.getBotPerformanceAnalytics(
  personality: BotPersonality.conservative,
  specificSeed: 123456,
);

// Analyze performance across a range of seeds (for systematic testing)
Map<String, dynamic>? rangeAnalytics = await GameAnalyticsLogger.getBotPerformanceAnalytics(
  personality: BotPersonality.adaptive,
  seedRange: [100000, 200000], // Seeds from 100k to 200k
  limitDays: 14,
);

if (analytics != null) {
  double winRate = analytics['winRate'];
  double avgScore = analytics['averageScore'];
  double bookCompletionRate = analytics['bookCompletionRate'];
  
  print('Aggressive bots win ${(winRate * 100).toStringAsFixed(1)}% of games');
}
```

### Metrics Collected
- **Win Rate**: Percentage of games won by personality type
- **Average Score**: Mean final score across all games
- **Completion Rates**: Play-down success, foot transition, book completion
- **Efficiency Metrics**: Hand size management, meld optimization
- **Strategic Analysis**: Risk tolerance, decision confidence, timing
- **Reproducibility**: Game seeds allow replaying identical scenarios for testing

### Seed-Based Analysis
```dart
// Analyze bot performance on specific game scenarios
final specificGames = await FirebaseFirestore.instance
    .collection('game_sessions')
    .where('gameSeed', isEqualTo: 123456)
    .get();

// Compare how different personalities handle the same starting conditions
for (final doc in specificGames.docs) {
  final data = doc.data();
  print('Seed ${data['gameSeed']}: ${data['botPerformance']}');
}

// Find seeds where a personality struggles (for focused improvement)
final challengingSeeds = await GameAnalyticsLogger.getChallengingSeeds(
  personality: BotPersonality.aggressive,
  limitDays: 14,
  limit: 5, // Top 5 most challenging seeds
);

for (final seedData in challengingSeeds) {
  print('Seed ${seedData['seed']}: ${(seedData['winRate'] * 100).toStringAsFixed(1)}% win rate');
  print('  Average score: ${seedData['averageScore']}');
  print('  Games played: ${seedData['totalGames']}');
}

// Reproduce a challenging game for debugging
final gameController = GameController(
  players: players, 
  seed: challengingSeeds.first['seed'], // Use most challenging seed
);
```

## Integration Examples

### Starting Analytics Session
```dart
// In game initialization
final sessionId = await GameAnalyticsLogger.startGameSession(
  players: gameState.players,
  gameState: gameState,
  gameMode: 'singleplayer',
  botPersonalities: botPersonalityMap,
);
```

### Logging Bot Decisions
```dart
// In bot AI processing
await GameAnalyticsLogger.logBotDecision(
  botId: bot.id,
  decision: 'createMeld',
  reasoning: 'Hand size getting large, need to play down',
  personality: BotPersonality.conservative,
  gameState: currentState,
  confidence: 0.9,
);
```

### Ending Analytics Session  
```dart
// When game completes
await GameAnalyticsLogger.endGameSession(
  gameState: finalState,
  winnerId: winner.id,
  totalTurns: turnCount,
  botPersonalities: botPersonalityMap,
);
```

## Security & Privacy

### Data Protection
- All data transmission uses HTTPS encryption
- Firebase security rules prevent unauthorized access
- No personally identifiable information is collected
- Device IDs are hashed for anonymization

### GDPR Compliance
- Clear opt-in/opt-out controls
- Transparent data usage explanation
- User-initiated data deletion
- Minimal data retention periods

### User Rights
- **Access**: View what data is collected via privacy info
- **Rectification**: Disable/enable analytics preferences  
- **Erasure**: Request complete data deletion
- **Portability**: Export configuration settings

## Performance Impact

### Optimizations
- Asynchronous logging to prevent UI blocking
- Batched writes to reduce Firebase calls
- Local caching for offline capability
- Automatic retry with exponential backoff

### Resource Usage
- **Memory**: <5MB additional overhead
- **Network**: ~10KB per game session
- **Storage**: Automatic cleanup prevents accumulation
- **Battery**: Minimal impact due to efficient batching

## Troubleshooting

### Common Issues
1. **Analytics not working**: Check Firebase configuration and network connectivity
2. **Missing data**: Verify user has analytics enabled in settings
3. **Performance slow**: Ensure detailed logging is disabled for production use

### Debug Mode
```dart
// Enable debug logging
Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((record) => print('${record.level}: ${record.message}'));
```

## Development Usage

### Testing Analytics
```dart
// Enable detailed logging for development
await AnalyticsConfigService.setDetailedLoggingEnabled(true);

// Check analytics configuration
Map<String, dynamic> config = AnalyticsConfigService.exportConfiguration();
print('Analytics config: $config');
```

## Sharing Analytics Data for AI Improvement

### Quick Status Check
```dart
import '../utils/analytics_debug_helper.dart';

// Check if you have enough data for meaningful analysis
await AnalyticsDebugHelper.checkAnalyticsStatus();
// Prints status to console including data readiness

// Print summary to console for quick overview
await AnalyticsDebugHelper.printAnalyticsSummary();
```

### Export Data for External Analysis
```dart
// Export comprehensive analytics data as JSON string
String analyticsJson = await GameAnalyticsLogger.exportAnalyticsAsJson(
  limitDays: 14,  // Last 2 weeks
  includeDetailedLogs: false,  // Set true if needed for deeper analysis
  prettyPrint: true,
);

// Or use the helper for Claude-optimized format
String claudeJson = await AnalyticsDebugHelper.exportAnalyticsForClaude(
  limitDays: 14,
  includeRawData: false,
);

// Copy to clipboard for easy sharing
await AnalyticsDebugHelper.copyAnalyticsToClipboard();
```

### Export Personality Comparison
```dart
// Focus on specific metrics for personality balancing
String comparison = await AnalyticsDebugHelper.exportPersonalityComparison(
  focusMetrics: ['winRate', 'averageScore', 'bookCompletionRate'],
  limitDays: 14,
);
print(comparison);
```

### Data Readiness Guidelines
The system considers data ready for meaningful analysis when you have:
- **Minimum 20 game sessions** 
- **Minimum 50 bot instances** across all personalities
- **Multiple examples** of each personality type

Use `AnalyticsDebugHelper.checkAnalyticsStatus()` to see current progress toward these thresholds.

### Performance Monitoring
```dart
// Log performance metrics
await GameAnalyticsLogger.logBotPerformanceMetrics(
  botId: 'bot_1',
  personality: BotPersonality.adaptive,
  gameState: currentState,
  performanceMetrics: {
    'decisionTime': 150.0, // milliseconds
    'memoryUsage': 12.5,   // MB
    'cacheHitRate': 0.85,  // percentage
  },
);
```

## Future Enhancements

### Planned Features
- **Real-time Dashboard**: Live analytics viewing during development
- **A/B Testing**: Compare different bot personality configurations
- **Machine Learning**: Use analytics data to improve bot decision-making
- **Competitive Analysis**: Compare performance across different game modes

### API Extensions
- **Custom Events**: Allow games to log custom analytics events
- **Aggregation Queries**: Built-in analytics aggregation and reporting
- **Export Tools**: CSV/JSON export for external analysis
- **Alerting**: Notifications when performance metrics exceed thresholds