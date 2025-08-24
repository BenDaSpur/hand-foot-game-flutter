import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../game/enhanced_multiplayer_controller.dart';
import '../widgets/mobile_status_bar.dart';
import '../widgets/collapsible_recent_actions.dart';
import '../widgets/compact_player_scores.dart';
import '../widgets/advanced_meld_selector.dart';
import '../widgets/emergency_round_end_dialog.dart';
import '../widgets/game_app_bar.dart';
import '../widgets/player_hand_widget.dart';
import '../widgets/game_action_buttons.dart';
import '../widgets/melds_section.dart';
import '../widgets/connection_status_widget.dart';
import '../theme/balatro_theme.dart';
import 'main_menu_screen.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final EnhancedMultiplayerController gameController;

  const MultiplayerGameScreen({super.key, required this.gameController});

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  late EnhancedMultiplayerController _gameController;

  final List<int> _selectedCardIndices = [];
  Player? _viewingPlayerMelds;
  bool _statusExpanded = false;
  bool _actionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _gameController = widget.gameController;

    // Note: Do NOT call initializeGame() here for multiplayer games
    // The game state is already initialized by the host and synced via Firebase
    // Calling initializeGame() would overwrite the synced state
  }

  @override
  void dispose() {
    // Safely dispose game controller to prevent memory leaks
    try {
      _gameController.dispose();
    } catch (e) {
      debugPrint('Warning: Error disposing game controller: $e');
    }
    super.dispose();
  }

  void _onCardTap(int cardIndex) {
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

    return false;
  }

  void _onDrawFromDeck() {
    try {
      final success = _gameController.drawFromDeck();
      if (success) {
        setState(() {
          _selectedCardIndices.clear();
        });
      } else {
        // Check if the round ended automatically due to insufficient cards
        if (_gameController.gameState.phase == GamePhase.roundEnd) {
          _showEmergencyRoundEndDialog();
        } else {
          _showErrorDialog(
            'Draw Error',
            'Unable to draw from deck. Deck may be empty or insufficient.',
          );
        }
      }
    } catch (e) {
      _showErrorDialog('Draw Error', e.toString());
    }
  }

  void _onUnlockDiscard() {
    try {
      _gameController.unlockDiscardPile();
      setState(() {
        _selectedCardIndices.clear();
      });
    } catch (e) {
      _showErrorDialog('Unlock Error', e.toString());
    }
  }

  Future<void> _onAddCardToMeld(int meldIndex) async {
    if (_selectedCards.isEmpty) {
      _showErrorDialog(
        'Add Card Error',
        'Select at least one card first before clicking on a meld.',
      );
      return;
    }

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) {
      _showErrorDialog('Add Card Error', 'Invalid meld selected.');
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
        'Add Card Error',
        'None of the selected cards ($cardNames) can be added to this meld!',
      );
      return;
    }

    // Add all valid cards one by one
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
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Safety check: Ensure we're in the correct turn phase
    if (_gameController.gameState.turnPhase != TurnPhase.meld) {
      _showErrorDialog(
        'Meld Error',
        'You can only create melds during the meld phase.',
      );
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
        _showErrorDialog(
          'Advanced Meld Error',
          'Invalid card selection. Please try again.',
        );
        return;
      }
    }

    _performMultiMeldCreation(meldIndices);
  }

  Future<void> _performMultiMeldCreation(List<List<int>> meldIndices) async {
    try {
      // Convert indices to cards for each meld
      final humanPlayer = _gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
      );

      for (final indices in meldIndices) {
        final cards = indices.map((i) => humanPlayer.currentHand[i]).toList();
        _gameController.createMeld(cards);
      }

      setState(() {
        _selectedCardIndices.clear();
      });

      // Show success message
      final message = meldIndices.length == 1
          ? 'Successfully created meld!'
          : 'Successfully created ${meldIndices.length} melds!';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showErrorDialog(
        'Multiple Meld Error',
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
          try {
            _gameController.discardCard(_selectedCards.first);
            setState(() {
              _selectedCardIndices.clear();
            });
          } catch (e) {
            _showErrorDialog('Discard Error', e.toString());
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
            'Cannot Go Out',
            'Cannot go out! $missingBooks\n\nYou currently have:\n• $totalBooks book(s) total\n• $cleanBooks clean book(s)\n• $dirtyBooks dirty book(s)',
          );
          return;
        }
      }

      try {
        _gameController.discardCard(_selectedCards.first);
        setState(() {
          _selectedCardIndices.clear();
        });
      } catch (e) {
        _showErrorDialog('Discard Error', e.toString());
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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
    EmergencyRoundEndDialog.show(
      context,
      autoAdvance: true, // Multiplayer auto-advances
      onContinue: () {
        setState(() {}); // Refresh UI to show round transition
      },
    );
  }

  Future<void> _addCardsToMeld(
    int meldIndex,
    List<PlayingCard> cardsToAdd,
    List<PlayingCard> invalidCards,
  ) async {
    int addedCount = 0;
    final List<String> failureReasons = [];

    for (final card in cardsToAdd) {
      try {
        _gameController.addCardToMeld(meldIndex, card);
        addedCount++;
      } catch (e) {
        // Log specific error for debugging
        debugPrint(
          'Failed to add card ${card.displayName} to meld $meldIndex: $e',
        );
        failureReasons.add('${card.displayName}: ${e.toString()}');
      }
    }

    if (addedCount > 0) {
      _selectedCardIndices.clear();
      setState(() {});

      // Show feedback for any cards that couldn't be added
      final allFailures = <String>[];

      if (invalidCards.isNotEmpty) {
        final invalidNames = invalidCards.map((c) => c.displayName).toList();
        allFailures.addAll(
          invalidNames.map((name) => '$name: Invalid for this meld'),
        );
      }

      if (failureReasons.isNotEmpty) {
        allFailures.addAll(failureReasons);
      }

      if (allFailures.isNotEmpty) {
        _showErrorDialog(
          'Partial Success',
          'Added $addedCount cards to meld.\n\nCould not add:\n${allFailures.join('\n')}',
        );
      }
    } else {
      // Provide specific feedback about why no cards could be added
      final allFailures = <String>[];

      if (invalidCards.isNotEmpty) {
        final invalidNames = invalidCards.map((c) => c.displayName).toList();
        allFailures.addAll(
          invalidNames.map((name) => '$name: Invalid for this meld'),
        );
      }

      if (failureReasons.isNotEmpty) {
        allFailures.addAll(failureReasons);
      }

      final errorDetail = allFailures.isNotEmpty
          ? '\n\nReasons:\n${allFailures.join('\n')}'
          : '';

      _showErrorDialog(
        'Add Card Error',
        'Failed to add any cards to the meld.$errorDetail',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameState>(
      stream: _gameController.gameStateStream,
      initialData: _gameController.gameState,
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? _gameController.gameState;
        final currentPlayer = gameState.currentPlayer;
        final humanPlayer = gameState.players.firstWhere(
          (p) => p.type == PlayerType.human,
        );

        return Container(
          decoration: const BoxDecoration(
            gradient: BalatroTheme.primaryGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: GameAppBar(
              gameState: gameState,
              isMultiplayer: true,
              connectionStream: _gameController.connectionStream,
              isOnline: _gameController.isOnline,
              onLeaveGame: _leaveGame,
            ),
            body: Column(
              children: [
                // Connection status for multiplayer
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ConnectionStatusWidget(
                    controller: _gameController,
                    compact: true,
                  ),
                ),

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
                MeldsSection(
                  gameState: gameState,
                  humanPlayer: humanPlayer,
                  viewingPlayerMelds: _viewingPlayerMelds,
                  onViewPlayerMelds: (player) {
                    setState(() {
                      _viewingPlayerMelds = player;
                    });
                  },
                  onAddCardToMeld: _onAddCardToMeld,
                  onSelectAllCardsForMeld: _selectAllCardsForMeld,
                  canAddCardToMeld: _canAddCardToMeld,
                  getCompatibleCardsInfo: _getCompatibleCardsInfo,
                ),

                // Action buttons and hand
                GameActionButtons(
                  gameState: gameState,
                  humanPlayer: humanPlayer,
                  selectedCardIndices: _selectedCardIndices,
                  onDrawFromDeck: _onDrawFromDeck,
                  onUnlockDiscard: gameState.turnPhase == TurnPhase.draw
                      ? _onUnlockDiscard
                      : null,
                  onShowAdvancedMeldSelector: _showAdvancedMeldSelector,
                  onDiscard: _selectedCards.length == 1 ? _onDiscard : null,
                  onClearSelection: () {
                    setState(() {
                      _selectedCardIndices.clear();
                    });
                  },
                ),

                if (currentPlayer.type == PlayerType.human)
                  PlayerHandWidget(
                    player: humanPlayer,
                    selectedCardIndices: _selectedCardIndices,
                    onCardTap: _onCardTap,
                    onCardDoubleTap: _onCardDoubleTap,
                    isCardPlayable: _isCardPlayable,
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _leaveGame() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Leave Game'),
        content: const Text(
          'Are you sure you want to leave this multiplayer game? Other players will continue without you.',
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Leave'),
            onPressed: () {
              Navigator.of(context).pop();
              // Leave the multiplayer game and return to main menu
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MainMenuScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
