import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';
import '../ai/bot_ai.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/meld_widget.dart';
import '../widgets/mobile_status_bar.dart';
import '../widgets/collapsible_recent_actions.dart';
import '../widgets/compact_player_scores.dart';
import '../theme/balatro_theme.dart';
import '../widgets/advanced_meld_selector.dart';
import 'main_menu_screen.dart';

class GameScreen extends StatefulWidget {
  final int? testSeed; // For deterministic testing
  final GameController? gameController; // For continuing saved games

  const GameScreen({super.key, this.testSeed, this.gameController});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _gameController;
  late BotAI _botAI;

  final List<int> _selectedCardIndices =
      []; // Track card indices instead of card objects
  bool _isInitialized = false;
  Player? _viewingPlayerMelds; // null means viewing current player's melds
  bool _statusExpanded = false;
  bool _actionsExpanded = false;
  bool _disposed = false; // Track disposal state

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _initializeGame() async {
    // If a gameController was provided (continuing saved game), use it
    if (widget.gameController != null) {
      _gameController = widget.gameController!;
      _botAI = BotAI();

      setState(() {
        _isInitialized = true;
      });

      // Start bot turns if needed
      _processBotTurns();
      return;
    }

    // Check if there's a saved game
    final hasSaved = await GameController.hasSavedGame();

    if (hasSaved) {
      _showRestoreGameDialog();
      return;
    }

    _startFreshGame();
  }

  void _startFreshGame() {
    final players = [
      Player(id: '1', name: 'You', type: PlayerType.human),
      Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
      Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
    ];

    _gameController = GameController(players: players, seed: widget.testSeed);
    _botAI = BotAI();
    _gameController.initializeGame();

    // Sort the human player's initial hand
    final humanPlayer = players.firstWhere((p) => p.type == PlayerType.human);
    humanPlayer.sortHandByRank();

    setState(() {
      _isInitialized = true;
    });

    // If the first player is human, save the initial game state
    if (_gameController.gameState.currentPlayer.type == PlayerType.human) {
      _saveGameState();
    }

    _processBotTurns();
  }

  void _processBotTurns() {
    if (!_isInitialized) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processBotTurn();
    });
  }

  Future<void> _checkAndHandleRoundEnd() async {
    if (_gameController.gameState.phase == GamePhase.roundEnd) {
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Brief pause to show scores
      if (_disposed || !mounted) return; // Check again after delay
      _gameController.nextRound();
      setState(() {});
      _processBotTurns(); // Resume game flow
    }
  }

  void _processBotTurn() async {
    // Check if widget has been disposed
    if (_disposed || !mounted) return;

    // Check if game has ended
    if (_gameController.gameState.phase == GamePhase.gameEnd) {
      // Game is over, clear the saved game
      await GameController.clearSavedGame();
      return;
    }

    // Check if round has ended and automatically start next round
    await _checkAndHandleRoundEnd();
    if (_gameController.gameState.phase == GamePhase.roundEnd ||
        _gameController.gameState.phase == GamePhase.gameEnd) {
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
          if (decision.skipPlayDownCheck) {
            // For multi-meld sequences, use the bypass method
            _gameController.createMeldBypass(cards);
          } else {
            _gameController.createMeld(cards);
          }
          break;
        case 'addToMeld':
          final data = decision.data as Map<String, dynamic>;
          _gameController.addCardToMeld(data['meldIndex'], data['card']);
          break;
        case 'discard':
          final card = decision.data as PlayingCard;
          _gameController.discardCard(card);
          break;
        case 'goOut':
          // Bot is going out - they have no cards and meet the requirements
          // The game should automatically end the round
          _gameController.gameState.endRound();
          break;
        case 'error':
          // Bot is stuck - should not happen, but handle gracefully
          print('Bot ${currentPlayer.name} encountered an error state');
          // Use proper logging with privacy controls
          _gameController.gameState.logAction(
            'encountered error state - skipping turn',
            showCardDetails: false,
          );
          _forceNextTurn();
          break;
      }

      if (_disposed || !mounted) return; // Check before setState
      setState(() {});

      if (_gameController.gameState.currentPlayer.type == PlayerType.bot) {
        _processBotTurn();
      } else {
        // It's now the human player's turn - save the game state
        _saveGameState();
      }
    }
  }

  void _onCardTap(int cardIndex) {
    if (_gameController.gameState.currentPlayer.type != PlayerType.human) {
      return;
    }

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Bounds checking
    if (cardIndex < 0 || cardIndex >= humanPlayer.currentHand.length) return;

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

    if (cardIndex < 0 || cardIndex >= humanPlayer.currentHand.length) return;

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
      // For existing melds, prefer natural cards of the same rank over wilds
      // This provides cleaner gameplay - add natural cards first, wilds only if needed
      selectedIndices.addAll(naturalIndices);
    } else if (wildIndices.isNotEmpty) {
      // Only select wilds if no natural cards of this rank are available
      final currentWildsInMeld = meld.cards.where((c) => c.isWild).length;
      final currentNaturalsInMeld = meld.cards.where((c) => !c.isWild).length;
      final maxAdditionalWilds = currentNaturalsInMeld - currentWildsInMeld;

      if (maxAdditionalWilds > 0) {
        final wildsToAdd = wildIndices.take(maxAdditionalWilds).toList();
        selectedIndices.addAll(wildsToAdd);
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

  void _saveGameState() async {
    try {
      await _gameController.saveGame();
    } catch (e) {
      print('Failed to save game state: $e');
    }
  }

  void _showRestoreGameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved Game Found'),
        content: const Text(
          'Would you like to continue your previous game or start a new one?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startFreshGame();
            },
            child: const Text('New Game'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreSavedGame();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _restoreSavedGame() async {
    try {
      final savedController = await GameController.loadSavedGame();

      if (savedController != null) {
        _gameController = savedController;
        _botAI = BotAI();

        // Sort the human player's hand
        final humanPlayer = _gameController.gameState.players.firstWhere(
          (p) => p.type == PlayerType.human,
        );
        humanPlayer.sortHandByRank();

        setState(() {
          _isInitialized = true;
        });

        // Continue game flow
        _processBotTurns();
      } else {
        _showErrorDialog('Failed to load saved game. Starting new game.');
        _startFreshGame();
      }
    } catch (e) {
      _showErrorDialog('Error loading saved game: ${e.toString()}');
      _startFreshGame();
    }
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

  void _startNewGame() async {
    // Clear any saved game when explicitly starting new
    await GameController.clearSavedGame();

    setState(() {
      _isInitialized = false;
      _selectedCardIndices.clear();
      _viewingPlayerMelds = null;
    });

    // Start a fresh game directly (not checking for saves)
    _startFreshGame();
  }

  void _onDrawFromDeck() {
    if (_gameController.drawFromDeck()) {
      _sortHand('rank');
    } else {
      // Check if the round ended automatically due to insufficient cards
      if (_gameController.gameState.phase == GamePhase.roundEnd) {
        _showEmergencyRoundEndDialog();
      } else {
        // Check if deck is empty or insufficient
        if (_gameController.gameState.deck.isEmpty) {
          _showErrorDialog(
            'Cannot draw from deck: The deck is empty!\n\n'
            'The round will continue until a player goes out or all players pass.',
          );
        } else if (_gameController.gameState.deck.size < 2) {
          _showErrorDialog(
            'Cannot draw from deck: Only ${_gameController.gameState.deck.size} card(s) remaining.\n\n'
            'You must draw exactly 2 cards from the deck. Try drawing from the discard pile instead.',
          );
        }
      }
    }
  }

  void _onUnlockDiscard() {
    if (_gameController.unlockDiscardPile()) {
      _sortHand('rank');
    }
  }

  Future<void> _onAddCardToMeld(int meldIndex) async {
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

    // Check if any cards to add are wilds and need confirmation
    final wildsToAdd = cardsToAdd.where((card) => card.isWild).toList();
    if (wildsToAdd.isNotEmpty) {
      _showWildCardConfirmation(meldIndex, cardsToAdd, invalidCards);
      return;
    }

    // Add all valid cards one by one (non-wilds)
    await _addCardsToMeld(meldIndex, cardsToAdd, invalidCards);
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

  ({int count, bool areWilds}) _getCompatibleCardsInfo(int meldIndex) {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) {
      return (count: 0, areWilds: false);
    }

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

    // For existing melds, prioritize natural cards over wilds
    if (naturalCount > 0) {
      // Only count natural cards when they're available for existing melds
      return (count: naturalCount, areWilds: false);
    }

    // If no natural cards available, count wilds that could be added
    if (wildAsWildCount > 0) {
      final currentWildsInMeld = meld.cards.where((c) => c.isWild).length;
      final currentNaturalsInMeld = meld.cards.where((c) => !c.isWild).length;
      final maxAdditionalWilds = currentNaturalsInMeld - currentWildsInMeld;
      final usableWilds = wildAsWildCount > maxAdditionalWilds
          ? maxAdditionalWilds
          : wildAsWildCount;
      return usableWilds > 0
          ? (count: usableWilds, areWilds: true)
          : (count: 0, areWilds: false);
    }

    return (count: 0, areWilds: false);
  }

  void _showAdvancedMeldSelector() {
    // Force a UI refresh first to ensure we have the latest game state
    setState(() {});

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Safety check: Ensure we're in the correct turn phase
    if (_gameController.gameState.turnPhase != TurnPhase.meld) {
      _showErrorDialog('You can only create melds during the meld phase.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdvancedMeldSelector(
        player: humanPlayer,
        playDownRequirement: _gameController.gameState.playDownRequirement,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onConfirm: (meldIndices) {
          Navigator.of(context).pop();
          _executeAdvancedMeldCreation(meldIndices);
        },
      ),
    );
  }

  void _executeAdvancedMeldCreation(List<List<int>> meldIndices) {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Safety check: Validate all indices are valid
    for (final indices in meldIndices) {
      if (indices.any((index) => index >= humanPlayer.currentHand.length)) {
        _showErrorDialog('Invalid card selection. Please try again.');
        return;
      }
    }

    // Check for wild cards across all melds and show warning if needed
    final allWildCards = <PlayingCard>[];
    final allMeldCards = <List<PlayingCard>>[];

    for (final indices in meldIndices) {
      final cards = indices.map((i) => humanPlayer.currentHand[i]).toList();
      allMeldCards.add(cards);
      allWildCards.addAll(cards.where((card) => card.isWild));
    }

    if (allWildCards.isNotEmpty) {
      _showWildCardConfirmationForMultiMeld(
        meldIndices,
        allMeldCards,
        allWildCards,
      );
    } else {
      _performMultiMeldCreation(meldIndices);
    }
  }

  void _showWildCardConfirmationForMultiMeld(
    List<List<int>> meldIndices,
    List<List<PlayingCard>> allMeldCards,
    List<PlayingCard> allWildCards,
  ) {
    final wildNames = allWildCards.map((c) => c.displayName).join(', ');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Create Melds with Wilds?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to create ${meldIndices.length} meld(s) with wild cards:',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                wildNames,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will create "dirty book(s)" from the start. Are you sure?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performMultiMeldCreation(meldIndices);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Melds'),
          ),
        ],
      ),
    );
  }

  Future<void> _performMultiMeldCreation(List<List<int>> meldIndices) async {
    // Use the new atomic multi-meld creation method
    final success = _gameController.createMultipleMeldsFromIndices(
      meldIndices,
      skipPlayDownCheck: true,
    );

    if (success) {
      _sortHand('rank');
      setState(() {});

      // Check if creating melds caused the round to end
      await _checkAndHandleRoundEnd();

      // Show success message
      final message = meldIndices.length == 1
          ? 'Successfully created meld!'
          : 'Successfully created ${meldIndices.length} melds!';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } else {
      _showErrorDialog(
        'Failed to create melds. Please check your selections and try again.',
      );
    }
  }

  void _onDiscard() async {
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
            await _checkAndHandleRoundEnd();
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
        await _checkAndHandleRoundEnd();
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

    setState(() {});
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

  void _showEmergencyRoundEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Round Ended',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'The round has ended early due to insufficient cards in the deck.\n\n'
          'All player scores have been calculated and the next round will begin shortly.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Automatically advance to next round
              _gameController.nextRound();
              setState(() {});
            },
            child: const Text('Continue to Next Round'),
          ),
        ],
      ),
    );
  }

  void _showWildCardConfirmation(
    int meldIndex,
    List<PlayingCard> cardsToAdd,
    List<PlayingCard> invalidCards,
  ) {
    final wildsToAdd = cardsToAdd.where((card) => card.isWild).toList();
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );
    final meld = humanPlayer.melds[meldIndex];

    final wildNames = wildsToAdd.map((c) => c.displayName).join(', ');
    final meldName = '${meld.rank.name.toUpperCase()}s';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              meld.type == MeldType.natural
                  ? 'Make Meld Dirty?'
                  : 'Add Wild Cards?',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to add wild cards to your $meldName meld:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                wildNames,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              meld.type == MeldType.natural
                  ? 'This will make your meld a "dirty book" and you will lose the clean book bonus (500 pts). Are you sure?'
                  : 'This will add more wild cards to your existing dirty meld. Are you sure?',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addCardsToMeld(meldIndex, cardsToAdd, invalidCards);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              meld.type == MeldType.natural ? 'Make Dirty' : 'Add Wilds',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCardsToMeld(
    int meldIndex,
    List<PlayingCard> cardsToAdd,
    List<PlayingCard> invalidCards,
  ) async {
    int addedCount = 0;
    for (final card in cardsToAdd) {
      if (_gameController.addCardToMeld(meldIndex, card)) {
        addedCount++;
      }
    }

    if (addedCount > 0) {
      _sortHand('rank');
      _selectedCardIndices.clear();
      setState(() {});

      // Check if adding cards to meld caused the round to end
      await _checkAndHandleRoundEnd();

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
                  case 'main_menu':
                    _returnToMainMenu();
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
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'main_menu',
                  child: Row(
                    children: [
                      Icon(Icons.home, color: BalatroTheme.neonBlue),
                      SizedBox(width: 8),
                      Text('Main Menu'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Mobile-optimized status bar
            MobileStatusBar(
              gameState: gameState,
              isExpanded: _statusExpanded,
              onToggle: () {
                setState(() {
                  _statusExpanded = !_statusExpanded;
                });
              },
            ),

            // Collapsible recent actions
            CollapsibleRecentActions(
              gameState: gameState,
              isExpanded: _actionsExpanded,
              onToggle: () {
                setState(() {
                  _actionsExpanded = !_actionsExpanded;
                });
              },
            ),

            const SizedBox(height: 8),

            // Compact player scores
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Tap a player to view their melds:',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            CompactPlayerScores(
              gameState: gameState,
              viewingPlayerMelds: _viewingPlayerMelds,
              onPlayerTap: (player) {
                setState(() {
                  _viewingPlayerMelds = player;
                });
              },
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
                            () {
                              final player = _viewingPlayerMelds ?? humanPlayer;
                              final playerName = player.name;
                              if (playerName == 'You') {
                                return 'Your Melds:';
                              } else {
                                return '$playerName\'s Melds:';
                              }
                            }(),
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
                        indexedMelds.sort((a, b) {
                          // Special handling for Aces - put them at the end
                          final aRank = a.value.rank;
                          final bRank = b.value.rank;

                          if (aRank == CardRank.ace && bRank != CardRank.ace) {
                            return 1; // a (ace) comes after b
                          }
                          if (bRank == CardRank.ace && aRank != CardRank.ace) {
                            return -1; // b (ace) comes after a
                          }

                          // For non-ace cards or both aces, use normal index comparison
                          return aRank.index.compareTo(bRank.index);
                        });

                        return indexedMelds.map((entry) {
                          final canAdd =
                              _viewingPlayerMelds == null &&
                              currentPlayer.type == PlayerType.human &&
                              gameState.turnPhase == TurnPhase.meld;

                          final compatibleInfo = canAdd
                              ? _getCompatibleCardsInfo(entry.key)
                              : (count: 0, areWilds: false);

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
                            compatibleCardsInHand: compatibleInfo.count,
                            compatibleCardsAreWilds: compatibleInfo.areWilds,
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
                        onPressed: () => _showAdvancedMeldSelector(),
                        child: const Text('Play Cards'),
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
                                          isNewlyDrawn: humanPlayer
                                              .isCardIndexNewlyDrawn(index),
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

  void _returnToMainMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.neonPink, width: 1),
        ),
        title: const Text(
          'Return to Main Menu',
          style: TextStyle(
            color: BalatroTheme.neonPink,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to return to the main menu? Your current game progress will be lost.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainMenuScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Return to Menu',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }
}
