# Apple Intelligence opponent (iOS)

Optional solo opponent that uses Apple’s on-device Foundation Models framework
(iOS 26+, Apple Intelligence enabled). No model download.

## Behavior

The on-device model is a **posture advisor**. The coded `TurnPlanner` still
plays every action, including its hard constraints (forced discard-pile takes,
forced play-downs, and forced hand-pile empties). A model reply cannot skip
those.

1. At turn start, Dart builds a compact situation brief: rules, rank counts,
   book gaps, discard-pile facts, opponent melds, the expert action, and
   `BotStrategicMemory`. This request is not awaited before the draw.
2. Native Swift (`FoundationModelsBotService`) asks `LanguageModelSession` for
   a `@Generable` posture (`raceGoOut`, `buildBooks`, `denyPile`, or
   `holdKeys`), hold ranks, avoid-feed ranks, and a short intent. Channel
   replies run on the main actor. There is one call per turn.
3. Draw uses the unmodified planner, so a slow or wrong plan cannot donate
   the pile. Meld and discard wait for that same call, then run the planner
   again with the posture applied only as scorer weights and protected ranks.
4. Timeouts, channel errors, and unknown postures (including anything that
   means stall) leave the planner unbiased. Memory from the last successful
   plan is still sent on the next turn. Game logic never throws on planning
   failure.

## Enabling

Solo Game Setup → **Apple Intelligence opponent** (shown only when
`FoundationModelsService.checkAvailability()` reports available). When enabled,
only the **first bot seat** uses the Apple path.

## Manual check (Mac + iOS 26 device/simulator with Apple Intelligence)

1. Build/run the iOS app with Xcode 26+.
2. Confirm Solo Setup shows the toggle (not the unavailable note).
3. Enable it, start a game, and watch the first bot’s thinking line show the
   plan `intent` when planning succeeds.
4. Confirm the seat still takes a legal discard pile and plays down when it
   can, even if the thinking line sounds cautious.
5. Confirm classic bots still play when the toggle is off or unavailable.

## Fallback

Unavailable device/OS, channel errors, or timeouts fall back silently to the
rule planner for that turn. The draw never waits on the model.
