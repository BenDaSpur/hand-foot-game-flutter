import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../config/game_config.dart';
import 'card_animation_host.dart';

/// Bot personality types (simplified for message selection)
enum _BotStyle { conservative, aggressive, bookBuilder, adaptive }

/// Generates personality-based thinking messages for bots
class BotThinkingMessages {
  static final _random = Random();

  /// Map bot names to their personalities
  static const _botPersonalities = {
    'Clara': _BotStyle.conservative,
    'Carl': _BotStyle.conservative,
    'Bob': _BotStyle.aggressive,
    'Rita': _BotStyle.aggressive,
    'Ben': _BotStyle.bookBuilder,
    'Tiana': _BotStyle.bookBuilder,
    'Alex': _BotStyle.adaptive,
    'Sue': _BotStyle.adaptive,
  };

  /// Draw phase messages by personality
  static const _drawMessages = {
    _BotStyle.conservative: [
      'Let me carefully consider my draw...',
      'Drawing cautiously...',
      'What will the deck give me?',
    ],
    _BotStyle.aggressive: [
      'Let\'s go! Drawing!',
      'Gimme those cards!',
      'Time to get lucky!',
    ],
    _BotStyle.bookBuilder: [
      'Looking for cards to build books...',
      'Need more cards for my sets...',
      'Drawing for the collection...',
    ],
    _BotStyle.adaptive: [
      'Hmm, let me draw...',
      'Drawing cards...',
      'Let\'s see what I get...',
    ],
  };

  /// Meld phase messages by personality
  static const _meldMessages = {
    _BotStyle.conservative: [
      'Should I play these yet...?',
      'Maybe I\'ll wait a bit longer...',
      'Is it safe to meld now?',
      'Holding back for now...',
    ],
    _BotStyle.aggressive: [
      'Let\'s slam these down!',
      'I\'m going for it!',
      'No holding back!',
      'Watch this play!',
    ],
    _BotStyle.bookBuilder: [
      'Working on my books...',
      'Building toward that canasta...',
      'Every card counts for the book!',
      'Strategically placing cards...',
    ],
    _BotStyle.adaptive: [
      'Thinking about my options...',
      'Let me see what I can play...',
      'Analyzing the situation...',
      'What\'s the best move here?',
    ],
  };

  /// Near-book messages by personality
  static const _nearBookMessages = {
    _BotStyle.conservative: [
      'Almost have a book... should I risk it?',
      'So close, but I need to be careful...',
    ],
    _BotStyle.aggressive: [
      'YES! Almost got that book!',
      'One more card and it\'s mine!',
    ],
    _BotStyle.bookBuilder: [
      'My book is almost complete!',
      'This is what I\'ve been building toward!',
    ],
    _BotStyle.adaptive: [
      'Almost have a book...',
      'So close to completing this!',
    ],
  };

  /// Discard phase messages by personality
  static const _discardMessages = {
    _BotStyle.conservative: [
      'Carefully choosing a discard...',
      'What\'s safest to throw?',
      'Don\'t want to help anyone...',
    ],
    _BotStyle.aggressive: [
      'Tossing this one!',
      'Boom! Take that!',
      'Here goes nothing!',
    ],
    _BotStyle.bookBuilder: [
      'Getting rid of the non-essentials...',
      'This doesn\'t fit my books...',
      'Trimming the hand...',
    ],
    _BotStyle.adaptive: [
      'What to throw away...',
      'Choosing a discard...',
      'This one can go...',
    ],
  };

  /// Tough discard messages
  static const _discardToughMessages = {
    _BotStyle.conservative: [
      'Oh no, all my cards are valuable!',
      'This is nerve-wracking...',
    ],
    _BotStyle.aggressive: [
      'Ugh, hate throwing away good cards!',
      'Fine, take it!',
    ],
    _BotStyle.bookBuilder: [
      'But I need all of these for books!',
      'Every card is part of a set!',
    ],
    _BotStyle.adaptive: ['Tough choice...', 'All my cards are good...'],
  };

  /// Get the bot's personality style
  static _BotStyle _getStyle(String botName) {
    return _botPersonalities[botName] ?? _BotStyle.adaptive;
  }

  /// Pick a random message from a list
  static String _pick(List<String> messages) {
    return messages[_random.nextInt(messages.length)];
  }

  /// Get a contextual thinking message based on game state and bot personality
  static String getThinkingMessage(Player bot, GameState gameState) {
    final style = _getStyle(bot.name);
    final phase = gameState.turnPhase;
    final handSize = bot.currentHand.length;

    switch (phase) {
      case TurnPhase.draw:
        return _pick(_drawMessages[style]!);

      case TurnPhase.meld:
        // Check if bot is close to completing a book
        final nearBook = bot.melds.any(
          (m) => m.cards.length >= 5 && m.cards.length < 7,
        );
        if (nearBook) {
          return _pick(_nearBookMessages[style]!);
        }
        return _pick(_meldMessages[style]!);

      case TurnPhase.discard:
        // If hand is small, discarding is tough
        if (handSize <= 3) {
          return _pick(_discardToughMessages[style]!);
        }
        return _pick(_discardMessages[style]!);
    }
  }
}

class GameActionButtons extends StatelessWidget {
  final GameState gameState;
  final Player humanPlayer;
  final List<int> selectedCardIndices;
  final VoidCallback onDrawFromDeck;
  final VoidCallback? onUnlockDiscard;
  final VoidCallback onShowAdvancedMeldSelector;
  final VoidCallback? onDiscard;
  final VoidCallback onClearSelection;
  final String? currentUserId; // For multiplayer turn detection

  const GameActionButtons({
    super.key,
    required this.gameState,
    required this.humanPlayer,
    required this.selectedCardIndices,
    required this.onDrawFromDeck,
    required this.onUnlockDiscard,
    required this.onShowAdvancedMeldSelector,
    required this.onDiscard,
    required this.onClearSelection,
    this.currentUserId, // Optional - for multiplayer
  });

  bool get _hasSelectedCard => selectedCardIndices.length == 1;

  /// Last-card discard can end the round when book requirements are met.
  bool get _canFinishWithLastCard =>
      humanPlayer.hasPickedUpFoot && humanPlayer.canGoOutWithBooks;

  String get _discardButtonText {
    if (_hasSelectedCard && humanPlayer.currentHand.length == 1) {
      if (humanPlayer.hasPickedUpFoot) {
        if (_canFinishWithLastCard) {
          return 'Go Out';
        } else {
          // Show specific requirement that's missing
          if (!humanPlayer.hasCleanBook && !humanPlayer.hasDirtyBook) {
            return 'Need Books';
          } else if (!humanPlayer.hasCleanBook) {
            return 'Need Clean Book';
          } else if (!humanPlayer.hasDirtyBook) {
            return 'Need Dirty Book';
          } else {
            return 'Cannot Go Out';
          }
        }
      } else {
        return 'Go to Foot';
      }
    }
    return 'Discard';
  }

  Color? get _discardButtonColor {
    if (_hasSelectedCard && humanPlayer.currentHand.length == 1) {
      if (humanPlayer.hasPickedUpFoot) {
        return _canFinishWithLastCard ? Colors.green : Colors.red;
      } else {
        return Colors.blue; // Go to foot
      }
    }
    return null;
  }

  /// Check if it's the current user's turn (works for both single-player and multiplayer)
  bool get _isCurrentUserTurn {
    if (currentUserId != null) {
      // Multiplayer: check if current player is this user
      return gameState.currentPlayer.id == currentUserId;
    } else {
      // Single-player: check if current player is human
      return gameState.currentPlayer.type == PlayerType.human;
    }
  }

  /// Get color for the current phase indicator
  Color _getPhaseColor() {
    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return Colors.cyan;
      case TurnPhase.meld:
        return Colors.green;
      case TurnPhase.discard:
        return Colors.orange;
    }
  }

  /// Get label for the current phase
  String _getPhaseLabel() {
    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return '📥 Drawing';
      case TurnPhase.meld:
        return '🃏 Melding';
      case TurnPhase.discard:
        return '📤 Discarding';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCurrentUserTurn) {
      final bot = gameState.currentPlayer;
      final thinkingMessage = BotThinkingMessages.getThinkingMessage(
        bot,
        gameState,
      );

      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bot name and phase
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.amber),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${bot.name}\'s Turn',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Phase indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getPhaseColor().withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getPhaseColor(), width: 1),
              ),
              child: Text(
                _getPhaseLabel(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _getPhaseColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Thinking message with speech bubble style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💭', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '"$thinkingMessage"',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Build buttons based on turn phase with compact sizing for mobile
    final buttons = <Widget>[];
    final isAnimating =
        CardAnimationScope.maybeOf(context)?.isAnimating ?? false;

    if (gameState.turnPhase == TurnPhase.draw) {
      buttons.add(
        _buildCompactButton(
          onPressed: isAnimating ? null : onDrawFromDeck,
          text: 'Draw from deck',
          context: context,
        ),
      );
      if (onUnlockDiscard != null) {
        buttons.add(
          _buildCompactButton(
            onPressed: isAnimating ? null : onUnlockDiscard,
            text: 'Take Discard',
            context: context,
          ),
        );
      }
    }

    if (gameState.turnPhase == TurnPhase.meld) {
      buttons.add(
        _buildCompactButton(
          onPressed: isAnimating ? null : onShowAdvancedMeldSelector,
          text: 'Play Cards',
          backgroundColor: const Color(
            0xFF16c79a,
          ), // Neon green for meld action
          context: context,
        ),
      );
      buttons.add(
        _buildCompactButton(
          onPressed: isAnimating ? null : (_hasSelectedCard ? onDiscard : null),
          text: _discardButtonText,
          backgroundColor:
              _discardButtonColor ??
              const Color(0xFFe94560), // Neon pink for discard
          context: context,
        ),
      );
      if (selectedCardIndices.isNotEmpty) {
        buttons.add(
          _buildCompactButton(
            onPressed: isAnimating ? null : onClearSelection,
            text: 'Clear',
            backgroundColor: Colors.grey,
            context: context,
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons
            .map(
              (button) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: button,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  /// Build a compact button sized appropriately for mobile screens
  Widget _buildCompactButton({
    required VoidCallback? onPressed,
    required String text,
    required BuildContext context,
    Color? backgroundColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < GameConfig.tabletPortraitBreakpoint;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 8 : 12,
          horizontal: isSmallScreen ? 8 : 16,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontSize: isSmallScreen ? 12 : 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
