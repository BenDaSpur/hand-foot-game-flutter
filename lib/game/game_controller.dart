import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/meld.dart';
import '../services/game_save_service.dart';
import 'game_interface.dart';

class GameController implements GameInterface {
  final GameState _gameState;
  @override
  final int? gameSeed;

  factory GameController({required List<Player> players, int? seed}) {
    final actualSeed = seed ?? Random().nextInt(1000000);
    return GameController._internal(
      players: players,
      seed: actualSeed,
      gameState: GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(players.length, seed: actualSeed),
      ),
    );
  }

  GameController._internal({
    required List<Player> players,
    required int seed,
    required GameState gameState,
  }) : gameSeed = seed,
       _gameState = gameState;

  @override
  GameState get gameState => _gameState;

  @override
  void initializeGame() {
    _gameState.deck.shuffle();
    _gameState.startRound();
    _gameState.dealCards();
  }

  @override
  bool drawFromDeck() {
    return _gameState.drawFromDeck();
  }

  @override
  bool drawFromDiscardPile() {
    return _gameState.drawFromDiscard();
  }

  @override
  bool unlockDiscardPile() {
    return _gameState.unlockDiscard();
  }

  @override
  bool canUnlockDiscard() {
    return _gameState.canUnlockDiscard();
  }

  @override
  bool createMeld(List<PlayingCard> cards) {
    final result = _gameState.playMeld(cards);

    // Defensive validation after potentially critical game state change
    _gameState.validateGameState();

    return result;
  }

  @override
  bool createMeldBypass(List<PlayingCard> cards) {
    final result = _gameState.playMeldBypass(cards);

    // Defensive validation after potentially critical game state change
    _gameState.validateGameState();

    return result;
  }

  /// Creates multiple melds atomically from card indices to prevent index shifting issues.
  ///
  /// This method handles multiple meld creation in a single transaction, ensuring that
  /// index references remain valid throughout the operation. It's particularly important
  /// for advanced meld creation where users create multiple melds simultaneously.
  ///
  /// Example usage:
  /// ```dart
  /// // Create three melds: Kings (0,1,2), Queens (3,4,5), Jacks with wild (6,7,8,9)
  /// final meldIndices = [
  ///   [0, 1, 2],       // Kings meld
  ///   [3, 4, 5],       // Queens meld
  ///   [6, 7, 8, 9],    // Jacks + wild meld
  /// ];
  /// final success = controller.createMultipleMeldsFromIndices(meldIndices);
  /// ```
  ///
  /// Parameters:
  /// - [allMeldIndices]: List of meld specifications, each containing card indices from player's hand
  /// - [skipPlayDownCheck]: If true, bypasses play-down point requirement validation
  ///
  /// Returns: true if all melds were successfully created, false otherwise
  ///
  /// The method performs these operations atomically:
  /// 1. Validates all indices are within bounds
  /// 2. Converts indices to actual cards before any removal
  /// 3. Validates all proposed melds are legal
  /// 4. Checks play-down requirements if applicable
  /// 5. Removes all cards from hand in one operation
  /// 6. Creates/adds to melds and handles game state updates
  ///
  /// Throws: No exceptions - returns false for all error conditions
  @override
  bool createMultipleMeldsFromIndices(
    List<List<int>> allMeldIndices, {
    bool skipPlayDownCheck = false,
  }) {
    final humanPlayer = _gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // First validate all indices are within bounds
    for (final meldIndices in allMeldIndices) {
      for (final index in meldIndices) {
        if (index < 0 || index >= humanPlayer.currentHand.length) {
          return false; // Invalid index
        }
      }
    }

    // Convert all indices to actual cards before any removal
    final allMeldCards = <List<PlayingCard>>[];
    final allIndicesSorted = <List<int>>[];

    for (final meldIndices in allMeldIndices) {
      final cards = meldIndices
          .map((index) => humanPlayer.currentHand[index])
          .toList();
      allMeldCards.add(cards);

      // Sort indices in descending order for safe removal
      final sortedIndices = List<int>.from(meldIndices)
        ..sort((a, b) => b.compareTo(a));
      allIndicesSorted.add(sortedIndices);
    }

    // Validate all melds can be created
    for (int i = 0; i < allMeldCards.length; i++) {
      final cards = allMeldCards[i];
      final meld = Meld.createMeld(cards);
      if (meld == null) {
        // Debug logging for development
        final cardNames = cards.map((c) => c.displayName).join(', ');
        _debugLog('Failed to create meld ${i + 1}: $cardNames');
        return false; // Invalid meld
      }
    }

    // Check total play down requirement if needed
    if (!skipPlayDownCheck && !humanPlayer.hasPlayedDown) {
      final totalPoints = allMeldCards
          .expand((cards) => cards)
          .fold<int>(0, (sum, card) => sum + card.pointValue);

      if (totalPoints < _gameState.playDownRequirement) {
        _debugLog(
          'Play-down requirement not met: $totalPoints < ${_gameState.playDownRequirement}',
        );
        return false; // Doesn't meet play down requirement
      }
    }

    // Now remove all cards from hand (sorted indices prevent shifting issues)
    // We need to collect all indices first and sort them in descending order
    final allIndicesToRemove = <int>[];
    for (final meldIndices in allMeldIndices) {
      allIndicesToRemove.addAll(meldIndices);
    }
    allIndicesToRemove.sort((a, b) => b.compareTo(a)); // Sort descending

    // Remove duplicates while preserving order
    final uniqueIndices = <int>[];
    for (final index in allIndicesToRemove) {
      if (!uniqueIndices.contains(index)) {
        uniqueIndices.add(index);
      }
    }

    // Remove cards from hand and handle side effects
    _removeCardsAndHandleSideEffects(humanPlayer, uniqueIndices);

    // Create all melds and add to existing melds where appropriate
    int meldsCreated = 0;
    final cardNamesCreated = <String>[];

    for (int i = 0; i < allMeldCards.length; i++) {
      final cards = allMeldCards[i];
      final naturalCards = cards.where((card) => !card.isWild).toList();

      // Check if we should add to existing meld
      if (naturalCards.isNotEmpty) {
        final rank = naturalCards.first.rank;
        final existingMeldIndex = humanPlayer.findMeldByRank(rank);

        if (existingMeldIndex != -1) {
          // Add to existing meld
          final existingMeld = humanPlayer.melds[existingMeldIndex];
          for (final card in cards) {
            existingMeld.addCard(card);
          }
          cardNamesCreated.add(
            'added to ${rank.name}: ${cards.map((c) => c.displayName).join(', ')}',
          );
        } else {
          // Create new meld
          final meld = Meld.createMeld(cards)!; // We already validated this
          humanPlayer.melds.add(meld);
          cardNamesCreated.add(
            'new ${rank.name}: ${cards.map((c) => c.displayName).join(', ')}',
          );
          meldsCreated++;
        }
      }
    }

    if (meldsCreated > 0 || cardNamesCreated.isNotEmpty) {
      // Log actions
      final wasFirstPlayDown = !humanPlayer.hasPlayedDown;

      // Update game state
      _gameState.hasMelded = true;
      humanPlayer.hasPlayedDown = true;

      if (wasFirstPlayDown) {
        final totalPoints = allMeldCards
            .expand((cards) => cards)
            .fold<int>(0, (sum, card) => sum + card.pointValue);
        _gameState.logAction(
          'played down with $totalPoints points: ${cardNamesCreated.join('; ')}',
        );
      } else {
        _gameState.logAction('created melds: ${cardNamesCreated.join('; ')}');
      }

      _debugLog('Successfully created ${allMeldCards.length} melds atomically');
      return true;
    }

    return false;
  }

  @override
  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  }) {
    final humanPlayer = _gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Validate all indices first - must be within bounds and non-negative
    for (final index in cardIndices) {
      if (index < 0 || index >= humanPlayer.currentHand.length) {
        return false; // Invalid index
      }
    }

    // Get the actual cards at these indices
    final cards = cardIndices
        .map((index) => humanPlayer.currentHand[index])
        .toList();

    // Check play down requirement if player hasn't played down yet
    // Skip this check when creating multiple melds (UI already validated total)
    if (!skipPlayDownCheck && !humanPlayer.hasPlayedDown) {
      final cardPointValue = cards.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (cardPointValue < _gameState.playDownRequirement) {
        return false;
      }
    }

    // First, check if we should add to an existing meld
    final naturalCards = cards.where((card) => !card.isWild).toList();
    if (naturalCards.isNotEmpty) {
      final rank = naturalCards.first.rank;
      final existingMeldIndex = humanPlayer.findMeldByRank(rank);

      if (existingMeldIndex != -1) {
        // Add to existing meld
        final existingMeld = humanPlayer.melds[existingMeldIndex];

        // Validate all cards can be added to existing meld
        for (final card in cards) {
          if (!existingMeld.canAddCard(card)) {
            return false; // Can't add this card to existing meld
          }
        }

        // Remove cards from hand and handle side effects
        _removeCardsAndHandleSideEffects(humanPlayer, cardIndices);

        // Add all cards to existing meld
        for (final card in cards) {
          existingMeld.addCard(card);
        }

        // Update game state
        _gameState.hasMelded = true;

        // Log the action
        final cardNames = cards.map((c) => c.displayName).join(', ');
        _gameState.logAction('added to existing meld: $cardNames');

        humanPlayer.hasPlayedDown = true;
        return true;
      }
    }

    // No existing meld, try to create new meld
    final meld = Meld.createMeld(cards);
    if (meld != null) {
      // Remove cards from hand and handle side effects
      _removeCardsAndHandleSideEffects(humanPlayer, cardIndices);

      // Create new meld
      humanPlayer.melds.add(meld);

      // Update game state
      _gameState.hasMelded = true;

      // Log the action
      final cardNames = cards.map((c) => c.displayName).join(', ');
      final wasFirstMeld = !humanPlayer.hasPlayedDown;
      if (wasFirstMeld) {
        final points = cards.fold<int>(0, (sum, card) => sum + card.pointValue);
        _gameState.logAction('played down with $points points: $cardNames');
      } else {
        _gameState.logAction('created new meld: $cardNames');
      }

      humanPlayer.hasPlayedDown = true;
      return true;
    }
    return false;
  }

  @override
  bool addCardToMeld(int meldIndex, PlayingCard card) {
    final result = _gameState.addToMeld(meldIndex, card);

    // Defensive validation after potentially critical game state change
    _gameState.validateGameState();

    return result;
  }

  @override
  bool discardCard(PlayingCard card) {
    final result = _gameState.discard(card);

    // Defensive validation after potentially critical game state change
    _gameState.validateGameState();

    return result;
  }

  @override
  bool canPlayerGoOut() {
    final player = _gameState.currentPlayer;
    return player.canGoOut && player.hasBook();
  }

  @override
  List<List<PlayingCard>> findPossibleMelds(Player player) {
    final possibleMelds = <List<PlayingCard>>[];
    final hand = List<PlayingCard>.from(player.currentHand);

    final cardsByRank = <CardRank, List<PlayingCard>>{};
    final wildCards = <PlayingCard>[];

    for (final card in hand) {
      if (card.isWild) {
        wildCards.add(card);
      } else {
        cardsByRank.putIfAbsent(card.rank, () => []).add(card);
      }
    }

    for (final entry in cardsByRank.entries) {
      final naturalCards = entry.value;

      // Skip 3s - they cannot be melded in Hand & Foot
      if (entry.key == CardRank.three) {
        _debugLog('Correctly filtering out 3s from meld analysis');
        continue;
      }

      if (naturalCards.length >= 3) {
        possibleMelds.add(naturalCards);
      } else if (naturalCards.length >= 2 && wildCards.isNotEmpty) {
        final meldCards = List<PlayingCard>.from(naturalCards);
        final wildsNeeded = 3 - naturalCards.length;
        final availableWilds = wildCards.take(wildsNeeded).toList();
        if (availableWilds.length == wildsNeeded) {
          meldCards.addAll(availableWilds);
          possibleMelds.add(meldCards);
        }
      }
    }

    // Note: Wild-only melds are not allowed in Hand & Foot rules
    // Wild cards can only supplement natural card melds

    // Debug log the final possible melds to ensure no 3s are included
    for (int i = 0; i < possibleMelds.length; i++) {
      final meld = possibleMelds[i];
      final cardNames = meld.map((c) => c.displayName).join(', ');
      final hasThrees = meld.any((c) => c.rank == CardRank.three);
      if (hasThrees) {
        _debugLog(
          'ERROR: findPossibleMelds returning meld with 3s: $cardNames',
        );
      } else {
        _debugLog('Valid meld found: $cardNames');
      }
    }

    return possibleMelds;
  }

  @override
  List<PlayingCard> getPlayableCards() {
    final player = _gameState.currentPlayer;
    final playableCards = <PlayingCard>[];

    if (_gameState.turnPhase == TurnPhase.meld) {
      final possibleMelds = findPossibleMelds(player);
      for (final meld in possibleMelds) {
        playableCards.addAll(meld);
      }

      for (int i = 0; i < player.melds.length; i++) {
        for (final card in player.currentHand) {
          if (player.melds[i].canAddCard(card)) {
            playableCards.add(card);
          }
        }
      }
    }

    return playableCards.toSet().toList();
  }

  @override
  void nextRound() {
    if (_gameState.phase == GamePhase.roundEnd) {
      _gameState.resetForNewRound();
    }
  }

  @override
  bool get isGameOver => _gameState.phase == GamePhase.gameEnd;

  @override
  Player? get winner => _gameState.winner;

  @override
  int get currentRound => _gameState.round;

  @override
  List<Player> get leaderboard {
    final sortedPlayers = List<Player>.from(_gameState.players);
    sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
    return sortedPlayers;
  }

  @override
  Map<String, dynamic> getGameStatus() {
    return {
      'phase': _gameState.phase.name,
      'turnPhase': _gameState.turnPhase.name,
      'currentPlayer': _gameState.currentPlayer.name,
      'round': _gameState.round,
      'deckSize': _gameState.deck.size,
      'discardPileSize': _gameState.discardPile.length,
      'topDiscard': _gameState.topDiscard?.displayName,
      'canDrawFromDiscard': _gameState.canDrawFromDiscard,
      'discardPileFrozen': _gameState.discardPileFrozen,
    };
  }

  @override
  String exportGameState() {
    // Create compact data structure with minimal redundancy
    final export = {
      'v': 2, // Version 2 = gzip + optimized format
      's': gameSeed ?? -1, // seed
      'g': {
        // gameState
        'p': _gameState.phase.index, // Use indices instead of names
        't': _gameState.turnPhase.index,
        'r': _gameState.round,
        'c': _gameState.currentPlayerIndex,
        'f': _gameState.discardPileFrozen,
        'd': _gameState.hasDrawnFromDeck,
        'm': _gameState.hasMelded,
        'q': _gameState.playDownRequirement,
      },
      'players': _gameState.players
          .map(
            (player) => {
              'id': player.id,
              'n': player.name, // Shorter key names
              't': player.type.index, // Use index instead of name
              'sc': player.score,
              'pd': player.hasPlayedDown,
              'ft': player.hasPickedUpFoot,
              'melds': player.melds
                  .map(
                    (meld) => {
                      't': meld.type.index,
                      'c': meld.cards.map(_compactCard).toList(),
                    },
                  )
                  .toList(),
              'h': player.hand.map(_compactCard).toList(), // hand
              'f': player.foot.map(_compactCard).toList(), // foot
            },
          )
          .toList(),
      'deck': {
        'sz': _gameState.deck.size,
        's': _gameState.deck.seed,
        'top': _gameState.deck.topCard != null
            ? _compactCard(_gameState.deck.topCard!)
            : null,
      },
      'dp': _gameState.discardPile.map(_compactCard).toList(), // discardPile
      'ra': _gameState.recentActions
          .map(
            (action) => {
              'm': action.message,
              'p': action.playerName,
              't': action.timestamp.millisecondsSinceEpoch,
            },
          )
          .toList(), // recentActions
    };

    // Convert to compact JSON
    final jsonString = jsonEncode(export);
    final jsonBytes = utf8.encode(jsonString);

    // Use different compression strategies based on platform
    List<int> finalBytes;
    try {
      if (kIsWeb) {
        // Web: Use optimized format without gzip (gzip not supported in browsers)
        export['v'] = 3; // Version 3 = web-optimized format (no gzip)
        final webJsonString = jsonEncode(export);
        finalBytes = utf8.encode(webJsonString);
      } else {
        // Mobile/Desktop: Use gzip compression for maximum savings
        finalBytes = gzip.encode(jsonBytes);
      }
    } catch (e) {
      // Fallback to uncompressed if gzip fails
      export['v'] = 3; // Use web format as fallback
      final fallbackJsonString = jsonEncode(export);
      finalBytes = utf8.encode(fallbackJsonString);
    }

    // Encode as base64 for text sharing
    return base64Encode(finalBytes);
  }

  /// Create ultra-compact card representation using indices
  String _compactCard(PlayingCard card) {
    // Format: "R,S" where R=rank index, S=suit index (or empty for joker)
    // Example: "12,3" = King of Spades, "1," = Joker (no suit)
    final rankIndex = card.rank.index;
    final suitIndex = card.suit?.index;
    return suitIndex != null ? '$rankIndex,$suitIndex' : '$rankIndex,';
  }

  /// Parse compact card representation back to PlayingCard
  static PlayingCard _parseCompactCard(String compactCard) {
    final parts = compactCard.split(',');
    final rankIndex = int.parse(parts[0]);
    final suitIndex = parts[1].isNotEmpty ? int.parse(parts[1]) : null;

    return PlayingCard(
      rank: CardRank.values[rankIndex],
      suit: suitIndex != null ? Suit.values[suitIndex] : null,
    );
  }

  static GameController? fromExportJson(String input) {
    try {
      String jsonString = input.trim();

      // Check if the input is base64 encoded (compressed or uncompressed)
      if (!jsonString.startsWith('{') && !jsonString.startsWith('[')) {
        try {
          // Attempt to decode from base64
          final decodedBytes = base64Decode(jsonString);

          try {
            // Try to decompress with gzip first (version 2 format)
            if (!kIsWeb) {
              try {
                final decompressedBytes = gzip.decode(decodedBytes);
                jsonString = utf8.decode(decompressedBytes);
              } catch (gzipError) {
                // If gzip fails, try direct UTF-8 decode
                jsonString = utf8.decode(decodedBytes);
              }
            } else {
              // Web platform: try direct UTF-8 decode (version 3 format)
              jsonString = utf8.decode(decodedBytes);
            }
          } catch (e) {
            // If all decoding attempts fail, treat as legacy JSON format
            // This maintains backward compatibility
            rethrow;
          }
        } catch (e) {
          // If base64 decoding fails, treat as legacy JSON format
          // This maintains backward compatibility
        }
      }

      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Check format version
      final version = data['v'] ?? 1; // Default to version 1 for legacy formats

      if (version >= 2) {
        // New optimized format (versions 2 and 3)
        return _fromOptimizedFormat(data);
      } else {
        // Legacy format
        return _fromLegacyFormat(data);
      }
    } catch (e) {
      return null;
    }
  }

  /// Parse legacy export format (version 1)
  static GameController? _fromLegacyFormat(Map<String, dynamic> data) {
    try {
      // Extract basic info
      final gameSeed = data['gameSeed'] as int?;
      final gameStateData = data['gameState'] as Map<String, dynamic>;
      final playersData = data['players'] as List<dynamic>;

      // Recreate players
      final players = <Player>[];
      for (final playerData in playersData) {
        final player = Player(
          id: playerData['id'] as String,
          name: playerData['name'] as String,
          type: PlayerType.values.firstWhere(
            (e) => e.name == playerData['type'],
            orElse: () => PlayerType.bot,
          ),
          score: playerData['score'] as int,
        );

        player.hasPlayedDown = playerData['hasPlayedDown'] as bool;
        player.hasPickedUpFoot = playerData['usingFoot'] as bool;

        // Restore hand
        final handData = playerData['hand'] as List<dynamic>;
        for (final cardData in handData) {
          player.hand.add(
            _createCardFromData(cardData as Map<String, dynamic>),
          );
        }

        // Restore foot
        final footData = playerData['foot'] as List<dynamic>;
        for (final cardData in footData) {
          player.foot.add(
            _createCardFromData(cardData as Map<String, dynamic>),
          );
        }

        // Restore melds
        final meldsData = playerData['melds'] as List<dynamic>;
        for (final meldData in meldsData) {
          final meldCards = <PlayingCard>[];
          final cardsData = meldData['cards'] as List<dynamic>;
          for (final cardData in cardsData) {
            meldCards.add(
              _createCardFromData(cardData as Map<String, dynamic>),
            );
          }
          final meld = Meld.createMeld(meldCards);
          if (meld != null) {
            player.melds.add(meld);
          }
        }

        players.add(player);
      }

      // Create controller with restored state
      final controller = GameController(players: players, seed: gameSeed);

      // Restore game state properties
      final gameState = controller._gameState;
      gameState.currentPlayerIndex = gameStateData['currentPlayerIndex'] as int;
      gameState.round = gameStateData['round'] as int;
      gameState.discardPileFrozen = gameStateData['discardPileFrozen'] as bool;
      gameState.hasDrawnFromDeck = gameStateData['hasDrawnFromDeck'] as bool;
      gameState.hasMelded = gameStateData['hasMelded'] as bool;

      // Set phases
      final phaseName = gameStateData['phase'] as String;
      gameState.phase = GamePhase.values.firstWhere(
        (e) => e.name == phaseName,
        orElse: () => GamePhase.playing,
      );

      final turnPhaseName = gameStateData['turnPhase'] as String;
      gameState.turnPhase = TurnPhase.values.firstWhere(
        (e) => e.name == turnPhaseName,
        orElse: () => TurnPhase.draw,
      );

      // Restore discard pile
      final discardData = data['discardPile'] as List<dynamic>;
      gameState.discardPile.clear();
      for (final cardData in discardData) {
        gameState.discardPile.add(
          _createCardFromData(cardData as Map<String, dynamic>),
        );
      }

      // Restore deck accurately using seed
      if (gameSeed != null) {
        _restoreDeckFromSeed(gameState, gameSeed, players.length);
      }

      // Restore recent actions (if available in legacy format)
      final recentActionsData = data['recentActions'] as List<dynamic>?;
      if (recentActionsData != null) {
        gameState.recentActions.clear();
        for (final actionData in recentActionsData) {
          final message = actionData['message'] as String;
          final playerName = actionData['playerName'] as String;
          final timestampMs = actionData['timestamp'] as int?;
          final timestamp = timestampMs != null
              ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
              : DateTime.now();
          gameState.recentActions.add(
            GameAction.withTimestamp(
              message: message,
              playerName: playerName,
              timestamp: timestamp,
            ),
          );
        }
      }

      return controller;
    } catch (e) {
      // Return null to indicate failure - error handling done in UI
      return null;
    }
  }

  /// Parse optimized export format (version 2+)
  static GameController? _fromOptimizedFormat(Map<String, dynamic> data) {
    try {
      // Extract basic info using compact keys
      final gameSeed = data['s'] as int?;
      final gameStateData = data['g'] as Map<String, dynamic>;
      final playersData = data['players'] as List<dynamic>;

      // Recreate players from optimized format
      final players = <Player>[];
      for (final playerData in playersData) {
        final player = Player(
          id: playerData['id'] as String,
          name: playerData['n'] as String, // 'n' = name
          type: PlayerType.values[playerData['t'] as int], // 't' = type index
          score: playerData['sc'] as int, // 'sc' = score
        );

        player.hasPlayedDown = playerData['pd'] as bool; // 'pd' = playedDown
        player.hasPickedUpFoot = playerData['ft'] as bool; // 'ft' = foot

        // Restore hand from compact format
        final handData = playerData['h'] as List<dynamic>; // 'h' = hand
        for (final compactCard in handData) {
          player.hand.add(_parseCompactCard(compactCard as String));
        }

        // Restore foot from compact format
        final footData = playerData['f'] as List<dynamic>; // 'f' = foot
        for (final compactCard in footData) {
          player.foot.add(_parseCompactCard(compactCard as String));
        }

        // Restore melds from compact format
        final meldsData = playerData['melds'] as List<dynamic>;
        for (final meldData in meldsData) {
          final meldCards = <PlayingCard>[];
          final cardsData = meldData['c'] as List<dynamic>; // 'c' = cards
          for (final compactCard in cardsData) {
            meldCards.add(_parseCompactCard(compactCard as String));
          }

          if (meldCards.isNotEmpty) {
            final meldType =
                MeldType.values[meldData['t'] as int]; // 't' = type
            final meld = Meld(
              rank: meldCards.first.rank,
              cards: meldCards,
              type: meldType,
            );
            player.melds.add(meld);
          }
        }

        players.add(player);
      }

      // Create game controller
      final controller = GameController(players: players, seed: gameSeed);
      final gameState = controller._gameState;

      // Restore game state from compact format
      gameState.phase =
          GamePhase.values[gameStateData['p'] as int]; // 'p' = phase
      gameState.turnPhase =
          TurnPhase.values[gameStateData['t'] as int]; // 't' = turnPhase
      gameState.round = gameStateData['r'] as int; // 'r' = round
      gameState.currentPlayerIndex =
          gameStateData['c'] as int; // 'c' = currentPlayerIndex
      gameState.discardPileFrozen = gameStateData['f'] as bool; // 'f' = frozen
      gameState.hasDrawnFromDeck =
          gameStateData['d'] as bool; // 'd' = drawnFromDeck
      gameState.hasMelded = gameStateData['m'] as bool; // 'm' = melded

      // Restore discard pile from compact format
      final discardData = data['dp'] as List<dynamic>; // 'dp' = discardPile
      gameState.discardPile.clear();
      for (final compactCard in discardData) {
        gameState.discardPile.add(_parseCompactCard(compactCard as String));
      }

      // Restore deck from compact format
      final deckData = data['deck'] as Map<String, dynamic>;
      final deckSeed = deckData['s'] as int?; // 's' = seed
      if (deckSeed != null) {
        _restoreDeckFromSeed(gameState, deckSeed, players.length);
      }

      // Restore recent actions from compact format
      final recentActionsData =
          data['ra'] as List<dynamic>?; // 'ra' = recentActions
      if (recentActionsData != null) {
        gameState.recentActions.clear();
        for (final actionData in recentActionsData) {
          final message = actionData['m'] as String; // 'm' = message
          final playerName = actionData['p'] as String; // 'p' = playerName
          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            actionData['t'] as int, // 't' = timestamp
          );
          gameState.recentActions.add(
            GameAction.withTimestamp(
              message: message,
              playerName: playerName,
              timestamp: timestamp,
            ),
          );
        }
      }

      return controller;
    } catch (e) {
      return null;
    }
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

  static void _restoreDeckFromSeed(
    GameState gameState,
    int seed,
    int playerCount,
  ) {
    // Create a fresh deck with the same seed and shuffle it the same way
    final originalDeck = Deck.createHandAndFootDeck(playerCount, seed: seed);
    originalDeck.shuffle();

    // Get all cards from the original shuffled deck
    final allOriginalCards = List<PlayingCard>.from(originalDeck.cards);

    // Collect all cards that have been dealt out
    final dealtCards = <PlayingCard>[];

    // Add all player hand and foot cards
    for (final player in gameState.players) {
      dealtCards.addAll(player.hand);
      dealtCards.addAll(player.foot);

      // Add all cards from melds
      for (final meld in player.melds) {
        dealtCards.addAll(meld.cards);
      }
    }

    // Add discard pile cards
    dealtCards.addAll(gameState.discardPile);

    // Remove dealt cards from the original deck to get remaining cards
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

    // Replace the deck's cards with the remaining cards in correct order
    gameState.deck.replaceCards(remainingCards);
  }

  static bool _cardsEqual(PlayingCard a, PlayingCard b) {
    return a.rank == b.rank && a.suit == b.suit;
  }

  /// Save the current game state to local storage
  @override
  Future<void> saveGame() async {
    await GameSaveService.saveGame(_gameState, gameSeed);
  }

  /// Load a saved game from local storage
  static Future<GameController?> loadSavedGame() async {
    final savedData = await GameSaveService.loadGame();
    if (savedData != null) {
      return GameSaveService.restoreGameController(savedData);
    }
    return null;
  }

  /// Check if there is a saved game available
  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame();
  }

  /// Clear the saved game from local storage
  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSavedGame();
  }

  /// Clear newly drawn card highlighting for all players
  /// Useful when game state becomes inconsistent after export/import
  @override
  void clearAllNewlyDrawnCards() {
    for (final player in _gameState.players) {
      player.clearNewlyDrawnCards();
    }
  }

  void dispose() {
    // Cleanup resources if needed
  }

  /// Helper method to handle card removal and associated side effects
  /// like foot pickup. Reduces code duplication between single and multi-meld creation.
  void _removeCardsAndHandleSideEffects(Player player, List<int> cardIndices) {
    // Remove cards from hand
    player.removeCardsByIndices(cardIndices);

    // Check for foot pickup after card removal
    if (player.isHandEmpty && !player.hasPickedUpFoot) {
      player.pickUpFoot();
      _gameState.logAction('picked up foot pile');
    }
  }

  /// Debug logging helper for development and testing
  /// Only logs in debug mode to avoid performance impact in production
  void _debugLog(String message) {
    // Only log in debug mode
    assert(() {
      print('[GameController] $message');
      return true;
    }());
  }
}
