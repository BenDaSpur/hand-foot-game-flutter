# Apple Intelligence opponent (iOS)

Optional solo opponent that uses Apple’s on-device Foundation Models framework
(iOS 26+, Apple Intelligence enabled). No model download.

## Behavior

1. At the start of the first bot’s turn, Dart builds a compact game summary,
   legal candidates (`LegalActionGenerator`), and prior `BotStrategicMemory`.
2. Native Swift (`FoundationModelsBotService`) asks `LanguageModelSession` for a
   `@Generable` turn plan (`intent`, ordered candidate ids, memory updates,
   thinking-ahead notes).
3. `AppleIntelligenceBot` executes only still-legal planned steps; otherwise it
   falls back to `EnhancedBotAI` for that action.
4. Memory is stored in Dart and re-injected on later turns (native sessions are
   not kept unbounded).

## Enabling

Solo Game Setup → **Apple Intelligence opponent** (shown only when
`FoundationModelsService.checkAvailability()` reports available). When enabled,
only the **first bot seat** uses the Apple path.

## Manual check (Mac + iOS 26 device/simulator with Apple Intelligence)

1. Build/run the iOS app with Xcode 26+.
2. Confirm Solo Setup shows the toggle (not the unavailable note).
3. Enable it, start a game, and watch the first bot’s thinking line show the
   plan `intent` when planning succeeds.
4. Confirm classic bots still play when the toggle is off or unavailable.

## Fallback

Unavailable device/OS, channel errors, timeouts, or stale candidate ids all
fall back silently to the rule planner. Game logic never throws on planning
failure.
