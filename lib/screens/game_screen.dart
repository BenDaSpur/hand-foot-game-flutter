import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';
import '../ai/bot_ai.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/meld_widget.dart';
import '../theme/balatro_theme.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _gameController;
  late BotAI _botAI;

  final List<int> _selectedCardIndices =
      []; // Track card indices instead of card objects
  bool _isInitialized = false;
  String _sortMode = 'rank';
  Player? _viewingPlayerMelds; // null means viewing current player's melds

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    final players = [
      Player(id: '1', name: 'You', type: PlayerType.human),
      Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
      Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
    ];

    _gameController = GameController(players: players);
    _botAI = BotAI();
    _gameController.initializeGame();

    // Sort the human player's initial hand
    final humanPlayer = players.firstWhere((p) => p.type == PlayerType.human);
    humanPlayer.sortHandByRank();

    setState(() {
      _isInitialized = true;
    });

    _processBotTurns();
  }

  void _processBotTurns() {
    if (!_isInitialized) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processBotTurn();
    });
  }

  void _processBotTurn() async {
    // Check if round has ended and automatically start next round
    if (_gameController.gameState.phase == GamePhase.roundEnd) {
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Brief pause to show scores
      _gameController.nextRound();
      setState(() {});
      _processBotTurns(); // Resume game flow
      return;
    }

    final currentPlayer = _gameController.gameState.currentPlayer;

    if (currentPlayer.type == PlayerType.bot) {
      await Future.delayed(const Duration(seconds: 1));

      final decision = _botAI.makeDecision(currentPlayer, _gameController);

      switch (decision.action) {
        case 'drawFromDeck':
          _gameController.drawFromDeck();
          break;
        case 'drawFromDiscard':
          _gameController.drawFromDiscardPile();
          break;
        case 'createMeld':
          final cards = decision.data as List<PlayingCard>;
          _gameController.createMeld(cards);
          break;
        case 'addToMeld':
          final data = decision.data as Map<String, dynamic>;
          _gameController.addCardToMeld(data['meldIndex'], data['card']);
          break;
        case 'discard':
          final card = decision.data as PlayingCard;
          _gameController.discardCard(card);
          break;
      }

      setState(() {});

      if (_gameController.gameState.currentPlayer.type == PlayerType.bot) {
        _processBotTurn();
      }
    }
  }

  void _onCardTap(int cardIndex) {
    if (_gameController.gameState.currentPlayer.type != PlayerType.human) {
      return;
    }

    setState(() {
      if (_selectedCardIndices.contains(cardIndex)) {
        _selectedCardIndices.remove(cardIndex);
      } else {
        _selectedCardIndices.add(cardIndex);
      }
    });
  }

  void _onCardDoubleTap(int cardIndex) {
    if (_gameController.gameState.currentPlayer.type != PlayerType.human) {
      return;
    }

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (cardIndex >= humanPlayer.currentHand.length) return;

    final selectedCard = humanPlayer.currentHand[cardIndex];
    final matchingIndices = <int>[];

    // Find all cards of the same rank (including the tapped one)
    for (int i = 0; i < humanPlayer.currentHand.length; i++) {
      final card = humanPlayer.currentHand[i];
      if (card.rank == selectedCard.rank && !card.isWild) {
        matchingIndices.add(i);
      }
    }

    setState(() {
      // If any matching cards are already selected, deselect all matching cards
      if (matchingIndices.any((i) => _selectedCardIndices.contains(i))) {
        _selectedCardIndices.removeWhere((i) => matchingIndices.contains(i));
      } else {
        // Otherwise, select all matching cards
        for (final i in matchingIndices) {
          if (!_selectedCardIndices.contains(i)) {
            _selectedCardIndices.add(i);
          }
        }
      }
    });
  }

  void _selectAllCardsForMeld(int meldIndex) {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) return;

    final meld = humanPlayer.melds[meldIndex];
    final naturalIndices = <int>[];
    final wildIndices = <int>[];

    // First pass: collect natural cards of the same rank and all wild cards
    for (int i = 0; i < humanPlayer.currentHand.length; i++) {
      final card = humanPlayer.currentHand[i];

      if (card.rank == meld.rank && !card.isWild) {
        // Natural cards of the same rank as the meld
        naturalIndices.add(i);
      } else if (card.isWild) {
        // All wild cards (we'll filter later based on meld type and strategy)
        wildIndices.add(i);
      }
    }

    final selectedIndices = <int>[];

    if (naturalIndices.isNotEmpty) {
      // For natural/mixed melds, select natural cards of the same rank
      selectedIndices.addAll(naturalIndices);

      // Only add wilds if we have natural cards and won't exceed the limit
      if (wildIndices.isNotEmpty) {
        final currentWildsInMeld = meld.cards.where((c) => c.isWild).length;
        final currentNaturalsInMeld = meld.cards.where((c) => !c.isWild).length;
        final maxAdditionalWilds =
            (currentNaturalsInMeld + naturalIndices.length) -
            currentWildsInMeld;

        if (maxAdditionalWilds > 0) {
          final wildsToAdd = wildIndices.take(maxAdditionalWilds).toList();
          selectedIndices.addAll(wildsToAdd);
        }
      }
    }

    setState(() {
      // Clear current selection and select the smart selection
      _selectedCardIndices.clear();
      _selectedCardIndices.addAll(selectedIndices);
    });
  }

  List<PlayingCard> get _selectedCards {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );
    return _selectedCardIndices
        .where((index) => index < humanPlayer.currentHand.length)
        .map((index) => humanPlayer.currentHand[index])
        .toList();
  }

  bool _isCardPlayable(PlayingCard card) {
    if (_gameController.gameState.currentPlayer.type != PlayerType.human) {
      return false;
    }

    if (_gameController.gameState.turnPhase != TurnPhase.meld) {
      return false;
    }

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Check if this card can be added to any existing meld
    for (int i = 0; i < humanPlayer.melds.length; i++) {
      if (humanPlayer.melds[i].canAddCard(card)) {
        return true;
      }
    }

    // Check if this card can form a new meld
    final possibleMelds = _gameController.findPossibleMelds(humanPlayer);
    for (final meld in possibleMelds) {
      if (meld.contains(card)) {
        return true;
      }
    }

    return false;
  }

  bool _isGameStuck() {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );
    final currentPlayer = _gameController.gameState.currentPlayer;

    // Only consider it stuck if:
    // 1. It's the human player's turn
    // 2. They have an empty foot (not just empty hand - that's normal transition)
    // 3. They've already picked up their foot
    // 4. They don't meet the requirements to go out
    return currentPlayer.type == PlayerType.human &&
        humanPlayer.hasPickedUpFoot &&
        humanPlayer.foot.isEmpty &&
        !humanPlayer.canGoOutWithBooks &&
        _gameController.gameState.turnPhase == TurnPhase.meld;
  }

  void _forceNextTurn() {
    _gameController.gameState.nextPlayer();
    setState(() {});
    _processBotTurns();
  }

  void _showNewGameConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Game'),
        content: const Text(
          'Are you sure you want to start a new game? This will reset all progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  void _startNewGame() {
    setState(() {
      _isInitialized = false;
      _selectedCardIndices.clear();
      _viewingPlayerMelds = null;
    });

    _initializeGame();
  }

  void _onDrawFromDeck() {
    if (_gameController.drawFromDeck()) {
      _sortHand(_sortMode);
    }
  }

  void _onUnlockDiscard() {
    if (_gameController.unlockDiscardPile()) {
      _sortHand(_sortMode);
    }
  }

  void _onCreateMeld() {
    if (_selectedCards.length >= 3) {
      final humanPlayer = _gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
      );

      // If player hasn't played down yet, try to create multiple melds for play-down
      if (!humanPlayer.hasPlayedDown) {
        if (_createMultipleMelds()) {
          _sortHand(_sortMode);
          _selectedCardIndices.clear();
        }
        // Error handling is now done inside _createMultipleMelds()
      } else {
        // Player has already played down, create a single meld
        if (_gameController.createMeld(_selectedCards)) {
          _sortHand(_sortMode);
          _selectedCardIndices.clear();
        } else {
          _showErrorDialog(
            'Invalid meld! Cards must be of the same rank or wild cards.',
          );
        }
      }
    }
  }

  void _onAddCardToMeld(int meldIndex) {
    if (_selectedCards.isEmpty) {
      _showErrorDialog(
        'Select at least one card first before clicking on a meld.',
      );
      return;
    }

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) {
      _showErrorDialog('Invalid meld selected.');
      return;
    }

    final meld = humanPlayer.melds[meldIndex];
    final cardsToAdd = <PlayingCard>[];
    final invalidCards = <PlayingCard>[];

    // Check which selected cards can be added to this meld
    for (final card in _selectedCards) {
      if (meld.canAddCard(card)) {
        cardsToAdd.add(card);
      } else {
        invalidCards.add(card);
      }
    }

    if (cardsToAdd.isEmpty) {
      final cardNames = _selectedCards.map((c) => c.displayName).join(', ');
      _showErrorDialog(
        'None of the selected cards ($cardNames) can be added to this meld!',
      );
      return;
    }

    // Add all valid cards one by one
    int addedCount = 0;
    for (final card in cardsToAdd) {
      if (_gameController.addCardToMeld(meldIndex, card)) {
        addedCount++;
      }
    }

    if (addedCount > 0) {
      _sortHand(_sortMode);
      _selectedCardIndices.clear();
      setState(() {});

      if (invalidCards.isNotEmpty) {
        final invalidNames = invalidCards.map((c) => c.displayName).join(', ');
        _showErrorDialog(
          'Added $addedCount cards to meld. Could not add: $invalidNames',
        );
      }
    } else {
      _showErrorDialog('Failed to add any cards to the meld.');
    }
  }

  bool _canAddCardToMeld(int meldIndex) {
    if (_selectedCards.isEmpty) return false;

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) return false;

    final meld = humanPlayer.melds[meldIndex];

    // Return true if at least one selected card can be added
    return _selectedCards.any((card) => meld.canAddCard(card));
  }

  int _getCompatibleCardsCount(int meldIndex) {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) return 0;

    final meld = humanPlayer.melds[meldIndex];
    int naturalCount = 0;
    int wildAsWildCount = 0;

    for (final card in humanPlayer.currentHand) {
      if (card.rank == meld.rank && !card.isWild) {
        // Natural cards of the same rank
        naturalCount++;
      } else if (card.isWild) {
        // Wild cards that could be used as wilds
        wildAsWildCount++;
      }
    }

    // For natural/mixed melds with the same rank
    if (naturalCount > 0) {
      final currentWildsInMeld = meld.cards.where((c) => c.isWild).length;
      final currentNaturalsInMeld = meld.cards.where((c) => !c.isWild).length;
      final maxAdditionalWilds =
          (currentNaturalsInMeld + naturalCount) - currentWildsInMeld;
      final usableWilds = wildAsWildCount > maxAdditionalWilds
          ? maxAdditionalWilds
          : wildAsWildCount;
      return naturalCount + (usableWilds > 0 ? usableWilds : 0);
    }

    // If no natural cards of this rank, don't count wild cards
    return 0;
  }

  bool _createMultipleMelds() {
    final gameState = _gameController.gameState;
    final meldGroups = _findMeldGroupsFromSelectedIndices();

    if (meldGroups.isEmpty) {
      _showErrorDialog(
        'Cannot form any valid melds from selected cards. Each meld needs 3+ cards of the same rank.',
      );
      return false;
    }

    // Calculate total points from all possible melds
    int totalPoints = 0;
    for (final indices in meldGroups) {
      for (final index in indices) {
        if (index <
            _gameController.gameState.currentPlayer.currentHand.length) {
          totalPoints += _gameController
              .gameState
              .currentPlayer
              .currentHand[index]
              .pointValue;
        }
      }
    }

    if (totalPoints < gameState.playDownRequirement) {
      _showErrorDialog(
        'Not enough points! Found $totalPoints points from valid melds, need ${gameState.playDownRequirement}.',
      );
      return false;
    }

    // Create all the melds using indices
    for (final meldIndices in meldGroups) {
      if (!_gameController.createMeldByIndices(meldIndices)) {
        final cards = meldIndices
            .map(
              (i) =>
                  i < _gameController.gameState.currentPlayer.currentHand.length
                  ? _gameController
                        .gameState
                        .currentPlayer
                        .currentHand[i]
                        .displayName
                  : 'Unknown',
            )
            .join(', ');
        _showErrorDialog('Failed to create meld with: $cards');
        return false;
      }
    }

    return true;
  }

  List<List<int>> _findMeldGroupsFromSelectedIndices() {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );
    final hand = humanPlayer.currentHand;
    final meldGroups = <List<int>>[];

    // Group indices by card rank
    final indicesByRank = <CardRank, List<int>>{};
    final wildIndices = <int>[];

    for (final index in _selectedCardIndices) {
      if (index < hand.length) {
        final card = hand[index];
        if (card.isWild) {
          wildIndices.add(index);
        } else {
          indicesByRank.putIfAbsent(card.rank, () => []).add(index);
        }
      }
    }

    // Create meld groups from natural cards of the same rank
    for (final entry in indicesByRank.entries) {
      final naturalIndices = entry.value;
      if (naturalIndices.length >= 3) {
        meldGroups.add(naturalIndices);
      } else if (naturalIndices.length >= 2 && wildIndices.isNotEmpty) {
        // Can create a mixed meld with wilds
        final wildsNeeded = 3 - naturalIndices.length;
        if (wildIndices.length >= wildsNeeded) {
          final meldIndices = List<int>.from(naturalIndices);
          meldIndices.addAll(wildIndices.take(wildsNeeded));
          meldGroups.add(meldIndices);
          // Remove used wild indices
          for (int i = 0; i < wildsNeeded; i++) {
            wildIndices.removeAt(0);
          }
        }
      }
    }

    // Note: Wild-only melds are not allowed in Hand & Foot rules
    // Wild cards can only supplement natural card melds

    return meldGroups;
  }

  int _calculateSelectedPoints() {
    return _selectedCards.fold<int>(0, (sum, card) => sum + card.pointValue);
  }

  void _onDiscard() {
    if (_selectedCards.length == 1) {
      final humanPlayer = _gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
      );

      // Check if discarding this card would empty the hand/foot
      final willBeEmpty = humanPlayer.currentHand.length == 1;

      if (willBeEmpty) {
        // If this would be the last card, validate going out requirements
        if (!humanPlayer.hasPickedUpFoot) {
          // Going from hand to foot is always allowed
          if (_gameController.discardCard(_selectedCards.first)) {
            setState(() {});
            _selectedCardIndices.clear();
            _processBotTurns();
          }
          return;
        }

        // This would end the game - check requirements
        if (!humanPlayer.canGoOutWithBooks) {
          String missingBooks = '';
          final cleanBooks = humanPlayer.melds.where((m) => m.isClean).length;
          final dirtyBooks = humanPlayer.melds.where((m) => m.isDirty).length;
          final totalBooks = humanPlayer.melds.where((m) => m.isBook).length;

          if (!humanPlayer.hasCleanBook && !humanPlayer.hasDirtyBook) {
            missingBooks =
                'You need both a clean book (no wild cards) and a dirty book (with wild cards) to go out.';
          } else if (!humanPlayer.hasCleanBook) {
            missingBooks = 'You need a clean book (no wild cards) to go out.';
          } else if (!humanPlayer.hasDirtyBook) {
            missingBooks = 'You need a dirty book (with wild cards) to go out.';
          }

          _showErrorDialog(
            'Cannot go out! $missingBooks\n\nYou currently have:\n• $totalBooks book(s) total\n• $cleanBooks clean book(s)\n• $dirtyBooks dirty book(s)',
          );
          return;
        }
      }

      if (_gameController.discardCard(_selectedCards.first)) {
        setState(() {});
        _selectedCardIndices.clear();
        _processBotTurns();
      }
    } else {
      // Handle case where player has no cards to discard
      final humanPlayer = _gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
      );

      if (humanPlayer.currentHand.isEmpty) {
        // If hand is empty but foot hasn't been picked up, do it automatically
        if (!humanPlayer.hasPickedUpFoot && humanPlayer.hand.isEmpty) {
          humanPlayer.pickUpFoot();
          // The logAction is private, so the GameState will handle logging internally
        }

        // If both hand and foot are empty, but requirements aren't met
        if (humanPlayer.hasPickedUpFoot &&
            humanPlayer.foot.isEmpty &&
            !humanPlayer.canGoOutWithBooks) {
          _showErrorDialog(
            'Cannot go out! You need both clean and dirty books to win.',
          );
          return;
        }

        // Force advance turn if we're truly stuck
        _gameController.gameState.nextPlayer();
        setState(() {});
        _processBotTurns();
      }
    }
  }

  void _sortHand(String sortType) {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    switch (sortType) {
      case 'rank':
        humanPlayer.sortHandByRank();
        break;
      case 'suit':
        humanPlayer.sortHandBySuit();
        break;
      case 'value':
        humanPlayer.sortHandByValue();
        break;
    }

    setState(() {
      _sortMode = sortType;
    });
    _selectedCardIndices.clear();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final gameState = _gameController.gameState;
    final currentPlayer = gameState.currentPlayer;
    final humanPlayer = gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    return Container(
      decoration: const BoxDecoration(gradient: BalatroTheme.primaryGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [BalatroTheme.neonPink, BalatroTheme.glowColor],
            ).createShader(bounds),
            child: const Text(
              'HAND & FOOT',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BalatroTheme.glowDecoration(
                glowColor: BalatroTheme.neonGreen,
                backgroundColor: BalatroTheme.darkPurple,
              ),
              child: Text(
                'ROUND ${gameState.round}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: BalatroTheme.neonGreen,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (String value) {
                switch (value) {
                  case 'new_game':
                    _showNewGameConfirmation();
                    break;
                  case 'copy_seed':
                    _copySeedToClipboard();
                    break;
                  case 'export_game':
                    _exportGameState();
                    break;
                  case 'load_game':
                    _showLoadGameDialog();
                    break;
                  case 'how_to_play':
                    _showHowToPlayDialog();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'new_game',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.red),
                      SizedBox(width: 8),
                      Text('New Game'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'copy_seed',
                  child: Row(
                    children: [
                      Icon(Icons.copy, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Copy Seed'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'export_game',
                  child: Row(
                    children: [
                      Icon(Icons.download, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Export Game'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'load_game',
                  child: Row(
                    children: [
                      Icon(Icons.upload, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Load Game'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'how_to_play',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('How to Play'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Game status bar
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(16),
              decoration: BalatroTheme.glowDecoration(
                backgroundColor: BalatroTheme.darkPurple,
                glowColor: BalatroTheme.glowColor,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(
                    'Current: ${currentPlayer.name}',
                    BalatroTheme.neonPink,
                  ),
                  _buildStatusChip(
                    'Phase: ${gameState.turnPhase.name.toUpperCase()}',
                    BalatroTheme.neonBlue,
                  ),
                  _buildStatusChip(
                    'Play Down: ${gameState.playDownRequirement}',
                    BalatroTheme.neonOrange,
                  ),
                  _buildStatusChip(
                    'Deck: ${gameState.deck.size}',
                    BalatroTheme.neonYellow,
                  ),
                  if (gameState.topDiscard != null)
                    _buildStatusChip(
                      'Top: ${gameState.topDiscard!.displayName}',
                      BalatroTheme.neonGreen,
                    ),
                ],
              ),
            ),

            // Recent actions
            Container(
              height: 100,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Recent Actions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: gameState.recentActions.length,
                      reverse: true, // Show newest first
                      itemBuilder: (context, index) {
                        final action =
                            gameState.recentActions[gameState
                                    .recentActions
                                    .length -
                                1 -
                                index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            action.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Player scores (clickable to view melds)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tap a player to view their melds:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: gameState.players
                    .map(
                      (player) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _viewingPlayerMelds = player;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _viewingPlayerMelds == player
                                ? Colors.green[100]
                                : player == currentPlayer
                                ? Colors.blue[100]
                                : Colors.white,
                            border: Border.all(
                              color: _viewingPlayerMelds == player
                                  ? Colors.green
                                  : Colors.grey,
                              width: _viewingPlayerMelds == player ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                player.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('${player.score}'),
                              if (player.melds.isNotEmpty)
                                Text(
                                  '${player.melds.length} melds',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            // Melds section
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '${(_viewingPlayerMelds ?? humanPlayer).name}\'s Melds:',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_viewingPlayerMelds != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _viewingPlayerMelds = null;
                                  });
                                },
                                child: const Text('Back to yours'),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if ((_viewingPlayerMelds ?? humanPlayer).melds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No melds yet'),
                      )
                    else
                      ...(() {
                        // Sort melds by face value (CardRank)
                        final player = _viewingPlayerMelds ?? humanPlayer;
                        final indexedMelds = player.melds
                            .asMap()
                            .entries
                            .toList();
                        indexedMelds.sort(
                          (a, b) =>
                              a.value.rank.index.compareTo(b.value.rank.index),
                        );

                        return indexedMelds.map((entry) {
                          final canAdd =
                              _viewingPlayerMelds == null &&
                              currentPlayer.type == PlayerType.human &&
                              gameState.turnPhase == TurnPhase.meld;

                          return MeldWidget(
                            meld: entry.value,
                            meldIndex: entry.key,
                            canAddCards: canAdd,
                            onTap: canAdd ? _onAddCardToMeld : null,
                            onSelectAllCards: canAdd
                                ? _selectAllCardsForMeld
                                : null,
                            canAcceptSelectedCard:
                                canAdd && _canAddCardToMeld(entry.key),
                            compatibleCardsInHand: canAdd
                                ? _getCompatibleCardsCount(entry.key)
                                : 0,
                          );
                        });
                      })(),
                  ],
                ),
              ),
            ),

            // Action buttons
            if (currentPlayer.type == PlayerType.human) ...[
              // Emergency recovery for stuck game
              if (_isGameStuck())
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red[100],
                  child: Column(
                    children: [
                      const Text(
                        'Game is stuck! You went out without meeting book requirements.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _forceNextTurn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Skip Turn (Emergency Recovery)'),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (gameState.turnPhase == TurnPhase.draw) ...[
                      ElevatedButton(
                        onPressed: _onDrawFromDeck,
                        child: const Text('Draw from Deck'),
                      ),
                      if (_gameController.canUnlockDiscard())
                        ElevatedButton(
                          onPressed: _onUnlockDiscard,
                          child: const Text('Take Discard Pile'),
                        ),
                    ],
                    if (gameState.turnPhase == TurnPhase.meld) ...[
                      ElevatedButton(
                        onPressed: _selectedCards.length >= 3
                            ? _onCreateMeld
                            : null,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              humanPlayer.hasPlayedDown
                                  ? 'Create Meld (${_selectedCards.length})'
                                  : 'Play Down (${_selectedCards.length} cards)',
                            ),
                            if (!humanPlayer.hasPlayedDown &&
                                _selectedCards.isNotEmpty)
                              Text(
                                '${_calculateSelectedPoints()}/${gameState.playDownRequirement} pts',
                                style: const TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _selectedCards.length == 1
                            ? _onDiscard
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedCards.length == 1 &&
                                  humanPlayer.currentHand.length == 1
                              ? (humanPlayer.hasPickedUpFoot
                                    ? Colors.orange
                                    : Colors.blue)
                              : null,
                        ),
                        child: Text(
                          _selectedCards.length == 1 &&
                                  humanPlayer.currentHand.length == 1
                              ? (humanPlayer.hasPickedUpFoot
                                    ? 'Go Out'
                                    : 'Go to Foot')
                              : 'Discard',
                        ),
                      ),
                      if (_selectedCardIndices.isNotEmpty)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCardIndices.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                          ),
                          child: const Text('Clear Selection'),
                        ),
                    ],
                  ],
                ),
              ),

              // Sort controls
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Sort by: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    ...['rank', 'suit', 'value'].map(
                      (sortType) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () => _sortHand(sortType),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _sortMode == sortType
                                ? Colors.blue
                                : null,
                            foregroundColor: _sortMode == sortType
                                ? Colors.white
                                : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            sortType[0].toUpperCase() + sortType.substring(1),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Hand
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        'Your Hand (${humanPlayer.currentHand.length} cards)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                          },
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: humanPlayer.currentHand.isNotEmpty
                                ? (humanPlayer.currentHand.length - 1) * 50.0 +
                                      70.0
                                : 70.0,
                            child: Stack(
                              children: humanPlayer.currentHand
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final card = entry.value;

                                    return Positioned(
                                      left: index * 50.0,
                                      child: GestureDetector(
                                        onTap: () => _onCardTap(index),
                                        onDoubleTap: () =>
                                            _onCardDoubleTap(index),
                                        child: PlayingCardWidget(
                                          card: card,
                                          width: 70,
                                          height: 98,
                                          isSelected: _selectedCardIndices
                                              .contains(index),
                                          isPlayable: _isCardPlayable(card),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _copySeedToClipboard() {
    final seed =
        _gameController.gameSeed?.toString() ?? 'No seed (legacy game)';
    Clipboard.setData(ClipboardData(text: seed));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Game seed copied to clipboard: $seed'),
        backgroundColor: BalatroTheme.neonGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _exportGameState() {
    final gameStateJson = _gameController.exportGameState();
    Clipboard.setData(ClipboardData(text: gameStateJson));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Game state exported to clipboard'),
        backgroundColor: BalatroTheme.neonBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            _showExportedGameDialog(gameStateJson);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showExportedGameDialog(String gameStateJson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        title: const Text(
          'Exported Game State',
          style: TextStyle(color: BalatroTheme.neonPink),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              gameStateJson,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: gameStateJson));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Game state copied to clipboard'),
                  backgroundColor: BalatroTheme.neonGreen,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Copy',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoadGameDialog() {
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        title: const Text(
          'Load Game State',
          style: TextStyle(color: BalatroTheme.neonPink),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the exported game state JSON below:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: textController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: BalatroTheme.neonBlue,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: BalatroTheme.neonBlue,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: BalatroTheme.glowColor,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'Paste game state JSON here...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: BalatroTheme.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData(
                        'text/plain',
                      );
                      if (clipboardData?.text != null) {
                        textController.text = clipboardData!.text!;
                      }
                    },
                    child: const Text(
                      'Paste from Clipboard',
                      style: TextStyle(color: BalatroTheme.neonYellow),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      textController.clear();
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: BalatroTheme.neonOrange),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              _loadGameFromJson(textController.text);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Load Game',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowToPlayDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        title: const Text(
          'How to Play Hand & Foot',
          style: TextStyle(color: BalatroTheme.neonPink),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '🎯 OBJECTIVE',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first player to "go out" by melding all cards in your hand and foot.',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),

                Text(
                  '🃏 SETUP',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Each player gets 11 cards for their "hand" and 11 for their "foot"\n'
                  '• You play your hand first, then pick up your foot when hand is empty\n'
                  '• Play-down requirements increase each round (60, 90, 120+ points)',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),

                Text(
                  '📝 MELDS',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Melds are sets of 3+ cards of the same rank\n'
                  '• 2s and Jokers are wild cards\n'
                  '• 3s cannot be melded and block the discard pile\n'
                  '• Only one meld per rank allowed\n'
                  '• Books (7+ cards) give bonus points:\n'
                  '  - Clean Book (no wilds): +500 points\n'
                  '  - Dirty Book (with wilds): +300 points\n'
                  '  - Wild Book (all wilds): +1000 points',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),

                Text(
                  '🎮 GAMEPLAY',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '1. DRAW: Take 2 cards from deck OR unlock discard pile\n'
                  '2. MELD: Play cards (first meld must meet point requirement)\n'
                  '3. DISCARD: End your turn by discarding one card\n\n'
                  '• To unlock discard pile: Need 2+ natural cards matching top card\n'
                  '• Must have already played down to unlock discard pile\n'
                  '• Going out requires one clean book AND one dirty book',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),

                Text(
                  '🏆 WINNING',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'First player to reach 8,500 points wins!\n'
                  'Going out gives +100 bonus points.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it!',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _loadGameFromJson(String jsonText) {
    if (jsonText.trim().isEmpty) {
      _showErrorDialog('Please paste a valid game state JSON.');
      return;
    }

    try {
      final newController = GameController.fromExportJson(jsonText);
      if (newController == null) {
        _showErrorDialog(
          'Failed to load game state. The JSON format may be invalid or corrupted.',
        );
        return;
      }

      setState(() {
        _gameController = newController;
        _botAI = BotAI();
        _selectedCardIndices.clear();
        _viewingPlayerMelds = null;
        _isInitialized = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Game loaded successfully! Seed: ${newController.gameSeed ?? "No seed"}',
          ),
          backgroundColor: BalatroTheme.neonGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );

      // Process bot turns if needed
      _processBotTurns();
    } catch (e) {
      _showErrorDialog('Error loading game: ${e.toString()}');
    }
  }
}
