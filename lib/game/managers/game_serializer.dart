import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/card.dart';
import '../../models/deck.dart';
import '../../models/player.dart';
import '../../models/game_state.dart';
import '../../models/meld.dart';

/// Handles serialization and deserialization of game state.
///
/// This class manages the export and import of game states, providing
/// compressed formats for efficient storage and sharing. It supports
/// multiple format versions for backward compatibility.
class GameSerializer {
  static const int currentVersion = 3;

  /// Exports the game state to a compressed string format.
  static String exportGameState(GameState gameState, int? gameSeed) {
    final export = {
      'v': kIsWeb ? currentVersion : 2, // Version 2 = gzip, 3 = web-optimized
      's': gameSeed ?? -1,
      'g': _serializeGameState(gameState),
      'players': _serializePlayers(gameState.players),
      'deck': _serializeDeck(gameState.deck),
      'dp': gameState.discardPile.map(_compactCard).toList(),
      'ra': _serializeRecentActions(gameState.recentActions),
    };

    final jsonString = jsonEncode(export);
    final jsonBytes = utf8.encode(jsonString);

    // Platform-specific compression
    List<int> finalBytes;
    try {
      if (kIsWeb) {
        // Web: No gzip support
        export['v'] = currentVersion;
        finalBytes = utf8.encode(jsonEncode(export));
      } else {
        // Mobile/Desktop: Use gzip
        finalBytes = gzip.encode(jsonBytes);
      }
    } catch (e) {
      // Fallback to uncompressed
      export['v'] = currentVersion;
      finalBytes = utf8.encode(jsonEncode(export));
    }

    return base64Encode(finalBytes);
  }

  /// Imports a game state from an exported string.
  static Map<String, dynamic>? importGameState(String input) {
    try {
      String jsonString = input.trim();

      // Handle base64 encoded data
      if (!jsonString.startsWith('{') && !jsonString.startsWith('[')) {
        try {
          final decodedBytes = base64Decode(jsonString);

          // Try gzip decompression first
          if (!kIsWeb) {
            try {
              final decompressedBytes = gzip.decode(decodedBytes);
              jsonString = utf8.decode(decompressedBytes);
            } catch (gzipError) {
              jsonString = utf8.decode(decodedBytes);
            }
          } else {
            jsonString = utf8.decode(decodedBytes);
          }
        } catch (e) {
          // Assume it's already JSON
        }
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = data['v'] ?? 1;

      if (version >= 2) {
        return _parseOptimizedFormat(data);
      } else {
        return _parseLegacyFormat(data);
      }
    } catch (e) {
      print('[GameSerializer] Import error: $e');
      return null;
    }
  }

  /// Creates a compact card representation.
  static String _compactCard(PlayingCard card) {
    final rankIndex = card.rank.index;
    final suitIndex = card.suit?.index;
    return suitIndex != null ? '$rankIndex,$suitIndex' : '$rankIndex,';
  }

  /// Parses a compact card representation.
  static PlayingCard parseCompactCard(String compactCard) {
    final parts = compactCard.split(',');
    final rankIndex = int.parse(parts[0]);
    final suitIndex = parts[1].isNotEmpty ? int.parse(parts[1]) : null;

    return PlayingCard(
      rank: CardRank.values[rankIndex],
      suit: suitIndex != null ? Suit.values[suitIndex] : null,
    );
  }

  /// Serializes the game state metadata.
  static Map<String, dynamic> _serializeGameState(GameState gameState) {
    return {
      'p': gameState.phase.index,
      't': gameState.turnPhase.index,
      'r': gameState.round,
      'c': gameState.currentPlayerIndex,
      'f': gameState.discardPileFrozen,
      'd': gameState.hasDrawnFromDeck,
      'm': gameState.hasMelded,
      'q': gameState.playDownRequirement,
    };
  }

  /// Serializes player data.
  static List<Map<String, dynamic>> _serializePlayers(List<Player> players) {
    return players
        .map(
          (player) => {
            'id': player.id,
            'n': player.name,
            't': player.type.index,
            'sc': player.score,
            'pd': player.hasPlayedDown,
            'ft': player.hasPickedUpFoot,
            'melds': _serializeMelds(player.melds),
            'h': player.hand.map(_compactCard).toList(),
            'f': player.foot.map(_compactCard).toList(),
          },
        )
        .toList();
  }

  /// Serializes meld data.
  static List<Map<String, dynamic>> _serializeMelds(List<Meld> melds) {
    return melds
        .map(
          (meld) => {
            't': meld.type.index,
            'c': meld.cards.map(_compactCard).toList(),
          },
        )
        .toList();
  }

  /// Serializes deck data.
  static Map<String, dynamic> _serializeDeck(Deck deck) {
    return {
      'sz': deck.size,
      's': deck.seed,
      'top': deck.topCard != null ? _compactCard(deck.topCard!) : null,
    };
  }

  /// Serializes recent actions.
  static List<Map<String, dynamic>> _serializeRecentActions(
    List<GameAction> actions,
  ) {
    return actions
        .map(
          (action) => {
            'm': action.message,
            'p': action.playerName,
            't': action.timestamp.millisecondsSinceEpoch,
          },
        )
        .toList();
  }

  /// Parses optimized format (version 2+).
  static Map<String, dynamic> _parseOptimizedFormat(Map<String, dynamic> data) {
    return {
      'gameSeed': data['s'],
      'gameState': _parseGameState(data['g']),
      'players': _parsePlayers(data['players']),
      'discardPile': (data['dp'] as List)
          .map((c) => parseCompactCard(c as String))
          .toList(),
      'deck': data['deck'],
      'recentActions': _parseRecentActions(data['ra']),
    };
  }

  /// Parses legacy format (version 1).
  static Map<String, dynamic> _parseLegacyFormat(Map<String, dynamic> data) {
    // Convert legacy format to standardized format
    return {
      'gameSeed': data['gameSeed'],
      'gameState': data['gameState'],
      'players': _parseLegacyPlayers(data['players']),
      'discardPile': _parseLegacyCards(data['discardPile']),
      'deck': data['deck'],
      'recentActions': data['recentActions'],
    };
  }

  static Map<String, dynamic> _parseGameState(Map<String, dynamic> data) {
    return {
      'phase': GamePhase.values[data['p']].name,
      'turnPhase': TurnPhase.values[data['t']].name,
      'round': data['r'],
      'currentPlayerIndex': data['c'],
      'discardPileFrozen': data['f'],
      'hasDrawnFromDeck': data['d'],
      'hasMelded': data['m'],
      'playDownRequirement':
          data['q'] ?? 60, // Default for backward compatibility
    };
  }

  static List<Map<String, dynamic>> _parsePlayers(List<dynamic> playersData) {
    return playersData.map((playerData) {
      return {
        'id': playerData['id'],
        'name': playerData['n'],
        'type': PlayerType.values[playerData['t']].name,
        'score': playerData['sc'],
        'hasPlayedDown': playerData['pd'],
        'usingFoot': playerData['ft'],
        'melds': _parseMelds(playerData['melds']),
        'hand': (playerData['h'] as List)
            .map((c) => parseCompactCard(c as String))
            .toList(),
        'foot': (playerData['f'] as List)
            .map((c) => parseCompactCard(c as String))
            .toList(),
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _parseMelds(List<dynamic> meldsData) {
    return meldsData.map((meldData) {
      final cards = (meldData['c'] as List)
          .map((c) => parseCompactCard(c as String))
          .toList();
      return {'type': MeldType.values[meldData['t']].name, 'cards': cards};
    }).toList();
  }

  static List<Map<String, dynamic>> _parseRecentActions(
    List<dynamic>? actionsData,
  ) {
    if (actionsData == null) return [];

    return actionsData
        .map(
          (actionData) => {
            'message': actionData['m'],
            'playerName': actionData['p'],
            'timestamp': actionData['t'],
          },
        )
        .toList();
  }

  static List<Map<String, dynamic>> _parseLegacyPlayers(
    List<dynamic> playersData,
  ) {
    return playersData
        .map(
          (playerData) => {
            'id': playerData['id'],
            'name': playerData['name'],
            'type': playerData['type'],
            'score': playerData['score'],
            'hasPlayedDown': playerData['hasPlayedDown'],
            'usingFoot': playerData['usingFoot'],
            'melds': playerData['melds'],
            'hand': playerData['hand'],
            'foot': playerData['foot'],
          },
        )
        .toList();
  }

  static List<PlayingCard> _parseLegacyCards(List<dynamic> cardsData) {
    return cardsData
        .map(
          (cardData) => _createCardFromData(cardData as Map<String, dynamic>),
        )
        .toList();
  }

  static PlayingCard _createCardFromData(Map<String, dynamic> cardData) {
    final rankName = cardData['rank'] as String;
    final suitName = cardData['suit'] as String?;

    final rank = CardRank.values.firstWhere(
      (r) => r.name == rankName,
      orElse: () => CardRank.ace,
    );

    if (rank == CardRank.joker) {
      return const PlayingCard(rank: CardRank.joker);
    }

    final suit = Suit.values.firstWhere(
      (s) => s.name == suitName,
      orElse: () => Suit.clubs,
    );

    return PlayingCard(suit: suit, rank: rank);
  }

  /// Restores deck state from seed and dealt cards.
  static void restoreDeckFromSeed(
    GameState gameState,
    int seed,
    int playerCount,
  ) {
    // Create fresh deck with same seed
    final originalDeck = Deck.createHandAndFootDeck(playerCount, seed: seed);
    originalDeck.shuffle();

    final allOriginalCards = List<PlayingCard>.from(originalDeck.cards);
    final dealtCards = <PlayingCard>[];

    // Collect all dealt cards
    for (final player in gameState.players) {
      dealtCards.addAll(player.hand);
      dealtCards.addAll(player.foot);
      for (final meld in player.melds) {
        dealtCards.addAll(meld.cards);
      }
    }
    dealtCards.addAll(gameState.discardPile);

    // Calculate remaining cards
    final remainingCards = <PlayingCard>[];
    final dealtCardsCopy = List<PlayingCard>.from(dealtCards);

    for (final originalCard in allOriginalCards) {
      bool found = false;
      for (int i = 0; i < dealtCardsCopy.length; i++) {
        if (_cardsEqual(originalCard, dealtCardsCopy[i])) {
          dealtCardsCopy.removeAt(i);
          found = true;
          break;
        }
      }
      if (!found) {
        remainingCards.add(originalCard);
      }
    }

    gameState.deck.replaceCards(remainingCards);
  }

  static bool _cardsEqual(PlayingCard a, PlayingCard b) {
    return a.rank == b.rank && a.suit == b.suit;
  }
}
