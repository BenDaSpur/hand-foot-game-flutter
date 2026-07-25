import 'dart:math' as math;

import 'firebase_constants.dart';

/// Format rules for the short join codes players type by hand.
///
/// Codes are also the Firestore document id of the game, so the size of this
/// code space is what stops someone from simply enumerating every live game.
///
/// Widening the code from 4 to 6 characters is shipping as a **two-stage
/// rollout**, because a Flutter web client keeps its cached bundle across a
/// deploy and validates join codes locally before contacting Firestore. Stage
/// one (this build) teaches every client to *accept* a 6-character code while
/// still *generating* the old 4-character format. See [generatedCodeLength]
/// and `docs/multiplayer_security_notes.md`.
class GameCode {
  const GameCode._();

  /// Longest hand-typed join code the app accepts.
  ///
  /// [alphabet] has 31 characters, so 6 of them give 31^6 = 887,503,681
  /// possible codes once generation is widened.
  static const int maxLength = 6;

  /// Length of the original code format ("2 letters + 2 digits").
  ///
  /// Still accepted as input so games created by an older client remain
  /// joinable while they are in flight.
  static const int legacyLength = 4;

  /// Length of the codes this build creates.
  ///
  /// **Stage one of a two-stage rollout — this is the flip point.** Clients
  /// running the previously deployed bundle validate join codes locally with
  /// the old rule (exactly [legacyLength] characters, or a long Firestore
  /// document id) and reject a 6-character code before it ever reaches the
  /// network. Web bundles are cached across a deploy, so during the rollout
  /// window a new host handing a 6-character code to a not-yet-updated joiner
  /// would fail with a confusing format error. Generating the legacy format
  /// keeps every host/joiner combination working.
  ///
  /// **Stage two**, once cached bundles have rotated and clients that accept
  /// [maxLength] are the only ones in the wild, is to change this to
  /// [maxLength]. That is the entire change: [generate] then draws every
  /// position from the unambiguous [alphabet] on its own, and acceptance,
  /// normalization, and the join-code input field already handle the longer
  /// form. Until then the practical code space is still the legacy 67,600.
  static const int generatedCodeLength = legacyLength;

  /// Characters used when generating a widened code, minus ambiguous glyphs
  /// that are easy to confuse when a code is read aloud or copied off a
  /// screen (`0`/`O` and `1`/`I`/`L`).
  static const String alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Letters used by the legacy "2 letters + 2 digits" format.
  static const String legacyLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// Digits used by the legacy "2 letters + 2 digits" format.
  static const String legacyDigits = '0123456789';

  /// How many leading positions of a legacy code are letters.
  static const int legacyLetterCount = 2;

  /// Whether [gameId] is short enough to be a hand-typed join code rather
  /// than a full Firestore document id.
  static bool isShortCode(String gameId) {
    return gameId.length == maxLength || gameId.length == legacyLength;
  }

  /// Canonical (uppercase) form of a hand-typed join code.
  ///
  /// Longer ids are returned unchanged because they may be case-sensitive
  /// Firestore document ids.
  static String normalize(String gameId) {
    if (isShortCode(gameId)) {
      return gameId.toUpperCase();
    }
    return gameId;
  }

  /// Whether [gameId] is a usable game identifier.
  ///
  /// Accepts both hand-typed join codes and longer Firestore document ids.
  /// Validation is deliberately more permissive than [generate]: a player who
  /// mistypes a character should get "game not found" rather than a confusing
  /// format error, and codes of either length must stay joinable across the
  /// rollout described on [generatedCodeLength].
  static bool isValid(String gameId) {
    final trimmed = gameId.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    if (isShortCode(trimmed)) {
      return RegExp(
        '^[A-Z0-9]{${trimmed.length}}\$',
      ).hasMatch(trimmed.toUpperCase());
    }

    if (trimmed.length < FirebaseConstants.minGameIdLength) {
      return false;
    }
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed);
  }

  /// Generates a single random code. Uniqueness is the caller's concern.
  ///
  /// The format follows [generatedCodeLength]: legacy codes are letters then
  /// digits, anything longer is drawn entirely from [alphabet].
  static String generate({math.Random? random}) {
    final generator = random ?? math.Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < generatedCodeLength; i++) {
      final characters = charactersForPosition(i, generatedCodeLength);
      buffer.write(characters[generator.nextInt(characters.length)]);
    }
    return buffer.toString();
  }

  /// Characters a generated code may use at [index] for a code of
  /// [codeLength] characters.
  ///
  /// A legacy-length code has to stay byte-compatible with what the currently
  /// deployed build produces, so it keeps the "2 letters + 2 digits" shape.
  /// Every other length uses the unambiguous [alphabet] throughout.
  static String charactersForPosition(int index, int codeLength) {
    if (codeLength != legacyLength) {
      return alphabet;
    }
    return index < legacyLetterCount ? legacyLetters : legacyDigits;
  }
}
