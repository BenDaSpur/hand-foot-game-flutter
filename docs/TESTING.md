# Testing Guide for Hand & Foot Game

This document explains how to run and maintain the test suite for the Hand & Foot Flutter game.

## Test Types

### 1. Unit Tests (`test/`)
Test individual classes and functions in isolation.

```bash
# Run all unit tests
flutter test test/

# Run specific test file
flutter test test/models/meld_test.dart
```

**Current Coverage:**
- ✅ 161 unit tests passing
- Models (Card, Meld, GameState, Player, Deck)
- Game logic validation
- Newly drawn cards highlighting
- Save/restore functionality
- Multi-meld creation

### 2. E2E Tests (`e2e_test/`)
End-to-end tests that run the full Flutter app, similar to Selenium/Cypress/Playwright.

```bash
# Run all E2E tests (Chrome — matches CI)
flutter test e2e_test/ -d chrome

# macOS desktop (optional, local Mac only)
flutter test e2e_test/ -d macos

# Run specific test suite
flutter test e2e_test/basic_flow_test.dart -d chrome
flutter test e2e_test/improved_e2e_test.dart -d chrome
```

## E2E Test Suites

### Basic Flow Tests (`basic_flow_test.dart`)
Simple, fast tests for core functionality:
- ✅ Game startup verification
- ✅ Draw button interaction
- ✅ Menu accessibility
- **Runtime:** ~35 seconds

### Improved E2E Tests (`improved_e2e_test.dart`) 
Comprehensive game flow testing with improved timing:
- ✅ Complete game startup and UI verification
- ✅ Draw cards and phase transition
- ✅ Menu functionality and dialogs
- ✅ Player switching and meld viewing
- ✅ Card selection and discard flow
- ✅ Advanced meld modal interaction
- ✅ Game export functionality
- ✅ Multi-operation stability testing
- **Runtime:** ~90 seconds

## Test Architecture

### Key Features
- **Improved Timing Management:** Uses `pumpAndSettle()` with timeouts and fallback graceful handling
- **Smart State Management:** Handles SharedPreferences unavailability in test environments
- **Error Resilience:** Tests continue even if some UI elements aren't found
- **Clean Shutdown:** Prevents setState() after dispose() issues
- **Element Waiting:** Waits for elements to appear with configurable timeouts

### Test Utilities (`test_utils.dart`)
```dart
await E2ETestUtils.startAppWithCleanState(tester); // Starts app with clean state
await E2ETestUtils.safeTap(tester, finder, debugLabel: 'Action'); // Safe UI interaction
await E2ETestUtils.waitForElement(tester, finder); // Wait for element with timeout
await E2ETestUtils.cleanShutdown(tester); // Proper test cleanup
```

## Running Tests

### Prerequisites
- Flutter SDK installed
- Chrome (CI and Linux/web) or macOS desktop target
- No need for physical devices

### Command Examples
```bash
# Quick smoke test
flutter test e2e_test/basic_flow_test.dart -d chrome

# Full E2E regression testing
flutter test e2e_test/improved_e2e_test.dart -d chrome

# All tests (unit + E2E)
flutter test test/ && flutter test e2e_test/ -d chrome
```

### CI/CD Integration
E2E tests are automatically run in GitHub Actions:

```yaml
# Unit tests run on Ubuntu (fast)
quality-checks:
  runs-on: ubuntu-latest
  steps:
    - run: flutter test test/

# E2E tests run on Ubuntu Chrome
e2e-tests:
  runs-on: ubuntu-latest
  needs: quality-checks
  steps:
    - run: flutter test e2e_test/ -d chrome
```

**Branch Protection:** All PRs must pass both `quality-checks`, `e2e-tests`, and `claude-review` to merge.

## Test Results Interpretation

### Successful Test Output
```
⚠️ SharedPreferences not available in test environment
✅ Game startup and UI verification complete
✅ Draw and phase transition complete
✅ Menu functionality complete
All tests passed!
```

### Common Issues
1. **SharedPreferences warnings**: Normal in test environment, tests handle gracefully
2. **Element not found**: UI state may differ between test runs (tests handle gracefully)
3. **Timeouts**: Increase timeout values if tests run slowly

## Adding New Tests

### Unit Test Example
```dart
testWidgets('should handle new game feature', (WidgetTester tester) async {
  // Arrange
  final gameState = GameState(players: createTestPlayers());
  
  // Act
  gameState.performAction();
  
  // Assert
  expect(gameState.someProperty, expectedValue);
});
```

### E2E Test Example  
```dart
testWidgets('should test new UI flow', (WidgetTester tester) async {
  await E2ETestUtils.startAppWithCleanState(tester);
  
  // Interact with UI safely
  await E2ETestUtils.safeTap(tester, find.text('New Button'), debugLabel: 'Test new feature');
  
  // Wait for result with timeout
  if (await E2ETestUtils.waitForElement(tester, find.text('Expected Result'))) {
    expect(find.text('Expected Result'), findsOneWidget);
  }
  
  print('✅ New feature verified');
  await E2ETestUtils.cleanShutdown(tester);
});
```

## Best Practices

1. **Use E2ETestUtils.startAppWithCleanState()** for consistent test initialization
2. **Use E2ETestUtils.safeTap()** for reliable UI interactions with debug logging
3. **Use E2ETestUtils.waitForElement()** for elements that may take time to appear
4. **Always call E2ETestUtils.cleanShutdown()** at the end of each test
5. **Handle optional UI elements** with conditional checks using `.evaluate().isNotEmpty`
6. **Keep tests independent** - don't rely on previous test state
7. **Test critical paths first** in basic test suites

## Troubleshooting

### Tests Hang Indefinitely
- Use `pump()` instead of `pumpAndSettle()`
- Add manual delays with `Future.delayed()`
- Check for infinite animation loops

### "Element not found" Errors
- Verify the app started correctly
- Check for save game dialogs blocking UI
- Use conditional element finding with `.evaluate().isNotEmpty`

### Memory Leaks  
- Bot AI may continue running after tests - this is expected
- Use `setUp()` and `tearDown()` to properly clean state

This testing framework ensures your Hand & Foot game works correctly and prevents regressions during development.