# Multiplayer Security Notes

Status: **plan only — not implemented.** This document records a known
confidentiality and integrity weakness in online multiplayer, the partial
mitigation that is mid-rollout, and a concrete remediation plan for the real
fix. Nothing here should be treated as done until it has been implemented
*and* the matching Firestore rules have been deployed.

## The problem

Online games live in a single Firestore document, `games/{gameCode}`.

1. **Every hand is readable by any signed-in user.**
   `FirebaseService._playerToMap` (`lib/services/firebase_service.dart`)
   serializes each player's complete `hand` and `foot` arrays into the shared
   `gameState` map. `firestore.rules` allows `read: if request.auth != null`,
   and the app signs users in anonymously, so anybody who can run the web app
   can read any game document. The UI hides opponents' cards; the data does
   not. A single `getDoc()` in devtools reveals every hand at the table.

2. **Any participant can rewrite the whole game.**
   The `isValidGameUpdate` rule only checks the status transition, that
   `hostId` is unchanged, and that the player count does not exceed
   `maxPlayers`. The entire `gameState` — scores, melds, whose turn it is,
   the deck order — is unvalidated, so a modified client can write anything.

3. **Game codes are enumerable.** Still true in this build — see the
   two-stage rollout below.

## Game code widening — staged, and not yet in effect

Game codes are 4 characters ("2 letters + 2 digits", 26·26·10·10 = 67,600
possibilities), small enough to walk end to end in a few minutes of requests.
`lib/services/game_code.dart` widens them to 6 characters drawn from a
31-character alphabet that omits look-alike glyphs (`0`, `O`, `1`, `I`, `L`),
giving 31^6 = 887,503,681 possibilities — but the widening ships in two stages
and **only stage one is in this build**.

**Stage one (this build) is acceptance-only.** Clients now accept, normalize
and join a 6-character code, while `GameCode.generatedCodeLength` is still
`GameCode.legacyLength`, so hosts keep handing out 4-character codes. The split
exists because a Flutter web client keeps its cached bundle across a deploy and
validates the join code locally before it contacts Firestore. A bundle built
before this change accepts only exactly 4 characters or a long Firestore
document id, so it rejects a 6-character code with a format error that never
reaches the network. Generating 6-character codes now would break every "new
host, old joiner" pair for as long as stale bundles survive.

**Stage two is a one-line change:** in `lib/services/game_code.dart`, change

```dart
static const int generatedCodeLength = legacyLength;   // to: = maxLength;
```

Nothing else moves. `GameCode.generate` already draws every position from the
unambiguous alphabet at any non-legacy length, and acceptance, normalization
and the lobby's join-code input field already handle 6 characters.

**Stage two is safe only once all of these hold:**

- The stage-one build has been live in production long enough that no client
  can still be running a bundle that predates it (cache lifetime plus service
  worker rotation, not just "the deploy finished").
- `GameCode.legacyLength` stays in `isShortCode`/`isValid`, so 4-character
  games created before the flip remain joinable while they are in flight.
- Firestore holds no game whose document id would newly collide; ids are
  length-distinct, so this is satisfied by construction.

**Until stage two ships, the practical code space is still the legacy 67,600**,
and problem 3 is *not* mitigated. Even after stage two it only raises the cost
of *discovering* a game; it does nothing for problems 1 and 2, where anyone who
legitimately knows a code — that is, every player at the table — can still read
every hand and overwrite the state.

## Remediation plan

### Step 1 — split private state into per-player subdocuments

Move anything that must stay secret out of the shared document.

```text
games/{gameCode}                      // public: turn, phase, round, discard
                                      //         pile, melds, scores, log
games/{gameCode}/private/{playerId}   // secret: that player's hand and foot
games/{gameCode}/private/_deck        // secret: undealt deck order
```

- The public document keeps `handCount` / `footCount` per player so opponents
  can still render card backs and detect a player going out.
- `_playerToMap` grows a `includePrivateCards` flag; the shared writer passes
  `false`, the private writer passes `true`.
- `EnhancedMultiplayerController` subscribes to the public document plus its
  own private document and stitches them together before handing a `GameState`
  to the UI. `_updateLocalGameState` already replaces collections atomically,
  so this is the natural seam.
- The undealt deck must also move: with the deck order public, any client can
  compute every future draw.

### Step 2 — Firestore rules for the new shape

```text
match /games/{gameId} {
  allow read: if request.auth != null;

  match /private/{playerId} {
    // Only the owning player may read their own hand.
    allow read: if request.auth != null && request.auth.uid == playerId;
    // Only Cloud Functions may write (see step 3); no client writes.
    allow write: if false;
  }
}
```

The `_deck` document has no owning player, so with `read: if false` it is
readable only by the Admin SDK, which is what we want.

### Step 3 — server-side write validation

Client-authoritative writes cannot be validated properly in rules alone: rules
cannot deal cards, cannot check that a meld is legal, and cannot verify that a
drawn card actually came off the top of the deck. Two options, in increasing
order of effort:

**3a. Callable Cloud Functions for state-changing moves** (recommended).
Replace `syncGameState` with `drawFromDeck`, `takeDiscardPile`, `createMelds`,
`addToMeld`, and `discardCard` callables. Each function:

- loads the game and the caller's private document with the Admin SDK,
- rejects the call unless `context.auth.uid` is the current player,
- re-runs the existing rule checks (`GameRulesEngine` logic ported, or a
  minimal server-side equivalent),
- writes the public and private documents in a single transaction.

Then tighten the rules to `allow update: if false` on `games/{gameId}` for
everything except lobby joins, which stay client-side and are already
constrained by `isPlayerJoining`.

**3b. Interim hardening if 3a is too large.** Keep client writes but make
`isValidGameUpdate` far stricter:

- `currentPlayerIndex` may only change to the next seat, and only when the
  writer is the outgoing current player;
- `round` may only increase by one, and only when written by the host;
- `players[i].score` may only change on a round boundary;
- the writer's own uid must equal `players[oldData.currentPlayerIndex].id`.

This stops casual tampering by other players but not by the player whose turn
it legitimately is. Treat it as a stopgap.

### Step 4 — trim the shared action log

`GameAction.privateMessage` (`lib/models/game_state.dart`) already keeps drawn
card names out of the synced log; the shared `message` only records counts.
When step 1 lands, re-audit every `_logAction` call site for text that names a
card that is not publicly visible.

## Testing and deployment notes

- Steps 1 and 3 cannot be verified without Firebase credentials. Use the
  Firestore emulator (`firebase emulators:start`) plus `@firebase/rules-unit-testing`
  for rules coverage, and `MockNetworkAdapter` for the controller-side
  stitching.
- Rules changes require `firebase deploy --only firestore:rules`. Deploy the
  rules **after** clients that write the new shape are live, or in-flight games
  will break.
- The subdocument split is a breaking wire-format change. Either version the
  document (`schemaVersion` field, clients refuse unknown versions) or accept
  that games created before the rollout cannot be resumed.
