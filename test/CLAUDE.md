# Flutter Testing Guide for Claude Code

This file provides guidance for running and debugging Flutter tests in this project.

## Basic Test Commands

- **Run all tests**: `flutter test`
- **Run specific test file**: `flutter test test/specific_test.dart`
- **Run tests with pattern**: `flutter test --name="pattern"`
- **Run unit tests only**: `flutter test test/`
- **Run e2e integration tests**: `flutter test e2e/ -d macos`

## Useful Test Flags

### Finding Failing Tests

- **Show only failures**: `flutter test -r failures-only`
- **Stop on first failure**: `flutter test --fail-fast`
- **Run with verbose output**: `flutter test -v`

### Test Selection

- **Name pattern matching**: `flutter test --name="GameController"`
- **Plain text matching**: `flutter test --plain-name="bot AI"`
- **Tag-based selection**: `flutter test -t integration`
- **Exclude tags**: `flutter test -x slow`

### Performance & Debugging

- **Run with coverage**: `flutter test --coverage`
- **Parallel execution**: `flutter test -j 4` (4 concurrent processes)
- **Update golden files**: `flutter test --update-goldens`
- **Start paused for debugging**: `flutter test --start-paused test/specific_test.dart`

### Output Formatting

- **Compact output**: `flutter test -r compact` (default)
- **Expanded output**: `flutter test -r expanded` (better for logs)
- **Failures only**: `flutter test -r failures-only` (recommended for CI)
- **JSON output**: `flutter test -r json`
- **Silent mode**: `flutter test -r silent` (exit code only)

## Test Sharding (for Large Test Suites)

- **Split tests**: `flutter test --total-shards=4 --shard-index=0`
- **Run shard 1 of 4**: `flutter test --total-shards=4 --shard-index=1`

## Common Testing Scenarios

### Debugging Test Failures

1. Run with failures-only reporter: `flutter test -r failures-only`
2. Run specific failing test: `flutter test test/failing_test.dart -v`
3. Use start-paused for debugging: `flutter test --start-paused test/failing_test.dart`

### Performance Testing

```bash
# Run tests with coverage and branch coverage
flutter test --coverage --branch-coverage

# Run with timeout adjustments
flutter test --timeout=120s

# Ignore timeouts for slow integration tests
flutter test --ignore-timeouts e2e/
```

### Continuous Integration

```bash
# Recommended CI command (failures-only, fail-fast, no pub get)
flutter test -r failures-only --fail-fast --no-pub

# With coverage for CI reporting
flutter test --coverage -r failures-only --file-reporter="json:test-results.json"
```

## Test Organization in This Project

- **Unit Tests**: `test/` - Game logic, AI, models
- **Integration Tests**: `e2e/` - Full game flows
- **Widget Tests**: `test/widgets/` - UI component testing
- **AI Tests**: `test/ai/` - Bot decision-making validation

## Tips for Test Development

1. **Use descriptive test names**: Match with `--name` flag
2. **Tag tests appropriately**: Use `-t` and `-x` for selective runs
3. **Golden file testing**: Use `--update-goldens` when UI changes
4. **Coverage tracking**: Regular `--coverage` runs to maintain quality
5. **Parallel testing**: Use `-j` flag for faster feedback during development

## Troubleshooting

### Common Issues

- **Tests hanging**: Use `--ignore-timeouts` or increase `--timeout`
- **Golden file mismatches**: Run `--update-goldens` after UI changes
- **Memory issues**: Reduce concurrency with `-j 1`
- **Platform-specific failures**: Specify device with `-d` flag

### Mobile Browser Testing Note

When testing web builds, always test on actual mobile browsers, not just desktop responsive mode. Touch events and scroll behavior can differ significantly.
