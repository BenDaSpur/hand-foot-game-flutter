import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../constants/keyboard_shortcuts.dart';
import '../services/haptic_service.dart';
import '../theme/balatro_theme.dart';
import '../utils/game_responsive_layout.dart';
import 'card_animation_host.dart';
import 'game_action_rail_scope.dart';

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
  final VoidCallback? onDrawFromDeck;
  final VoidCallback? onUnlockDiscard;
  final VoidCallback? onShowAdvancedMeldSelector;
  final VoidCallback? onDiscard;
  final VoidCallback? onUndoMeld;
  final VoidCallback onClearSelection;
  final String? currentUserId; // For multiplayer turn detection
  final bool showKeyboardHints;
  final bool canUndoMeld;

  /// When set (e.g. Apple Intelligence turn plan), shown instead of a random
  /// personality thinking line.
  final String? botPlanIntent;

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
    this.onUndoMeld,
    this.currentUserId, // Optional - for multiplayer
    this.showKeyboardHints = false,
    this.canUndoMeld = false,
    this.botPlanIntent,
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
    final slimRail = GameActionRailScope.slimOf(context);

    if (!_isCurrentUserTurn) {
      final bot = gameState.currentPlayer;
      final override = botPlanIntent?.trim();
      final thinkingMessage = (override != null && override.isNotEmpty)
          ? override
          : BotThinkingMessages.getThinkingMessage(bot, gameState);
      final mediaSize = MediaQuery.sizeOf(context);
      final width = mediaSize.width;
      final isPhone = GameResponsiveLayout.isPhone(width);
      final isUltraShort = GameResponsiveLayout.isUltraShortHeight(
        mediaSize.height,
      );
      final inWideRail = GameResponsiveLayout.useWideBoardLayout(width);

      final phaseChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _getPhaseColor().withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _getPhaseColor(), width: 1),
        ),
        child: Text(
          _getPhaseLabel(),
          style: TextStyle(
            color: _getPhaseColor(),
            fontSize: inWideRail ? 12 : 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      if (slimRail) {
        return Tooltip(
          message: thinkingMessage,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bot.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getPhaseLabel(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _getPhaseColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (inWideRail) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.amber),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${bot.name}\'s Turn',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  phaseChip,
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '"$thinkingMessage"',
                style: const TextStyle(
                  color: BalatroTheme.primaryText,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  height: 1.25,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isUltraShort
              ? 2
              : isPhone
              ? 6
              : 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.amber),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${bot.name}\'s Turn',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            phaseChip,
            if (!isPhone) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '"$thinkingMessage"',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Build buttons based on turn phase with compact sizing for mobile
    final buttons = <Widget>[];
    final isAnimating =
        CardAnimationScope.maybeOf(context)?.isAnimating ?? false;
    final mediaSize = MediaQuery.sizeOf(context);
    final width = mediaSize.width;
    final isPhone = GameResponsiveLayout.isPhone(width);
    final isUltraShort = GameResponsiveLayout.isUltraShortHeight(
      mediaSize.height,
    );
    final stackInRail = GameResponsiveLayout.useWideBoardLayout(width);

    if (gameState.turnPhase == TurnPhase.draw) {
      buttons.add(
        _buildTurnButton(
          slim: slimRail,
          onPressed: isAnimating ? null : onDrawFromDeck,
          text: 'Draw from deck',
          shortcutHint: showKeyboardHints ? KeyboardShortcuts.drawKey : null,
          isPhone: isPhone,
          isUltraShort: isUltraShort,
        ),
      );
      if (onUnlockDiscard != null) {
        buttons.add(
          _buildTurnButton(
            slim: slimRail,
            onPressed: isAnimating ? null : onUnlockDiscard,
            text: 'Take Discard',
            shortcutHint: showKeyboardHints
                ? KeyboardShortcuts.takeDiscardKey
                : null,
            isPhone: isPhone,
            isUltraShort: isUltraShort,
          ),
        );
      }
    }

    if (gameState.turnPhase == TurnPhase.meld) {
      buttons.add(
        _buildTurnButton(
          slim: slimRail,
          onPressed: isAnimating ? null : onShowAdvancedMeldSelector,
          text: 'Play Cards',
          shortcutHint: showKeyboardHints
              ? KeyboardShortcuts.playCardsKey
              : null,
          isPhone: isPhone,
          isUltraShort: isUltraShort,
          backgroundColor: const Color(
            0xFF16c79a,
          ), // Neon green for meld action
        ),
      );
      if (canUndoMeld && onUndoMeld != null) {
        buttons.add(
          _buildTurnButton(
            slim: slimRail,
            onPressed: isAnimating ? null : onUndoMeld,
            text: 'Undo',
            isPhone: isPhone,
            isUltraShort: isUltraShort,
            backgroundColor: Colors.orange,
          ),
        );
      }
      buttons.add(
        _buildTurnButton(
          slim: slimRail,
          onPressed: isAnimating ? null : (_hasSelectedCard ? onDiscard : null),
          text: _discardButtonText,
          shortcutHint: showKeyboardHints ? KeyboardShortcuts.discardKey : null,
          isPhone: isPhone,
          isUltraShort: isUltraShort,
          backgroundColor:
              _discardButtonColor ??
              const Color(0xFFe94560), // Neon pink for discard
        ),
      );
      if (selectedCardIndices.isNotEmpty) {
        buttons.add(
          _buildTurnButton(
            slim: slimRail,
            onPressed: isAnimating ? null : onClearSelection,
            text: 'Clear',
            shortcutHint: showKeyboardHints ? KeyboardShortcuts.clearKey : null,
            isPhone: isPhone,
            isUltraShort: isUltraShort,
            backgroundColor: Colors.grey,
          ),
        );
      }
    }

    if (slimRail) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              buttons[i],
            ],
          ],
        ),
      );
    }

    if (stackInRail) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              SizedBox(height: 44, child: buttons[i]),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 10 : 16,
        vertical: isUltraShort
            ? 2
            : isPhone
            ? 8
            : 12,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isPhone
                ? double.infinity
                : (buttons.length <= 1
                      ? GameResponsiveLayout.actionDockMaxWidthSingle
                      : GameResponsiveLayout.actionDockMaxWidthMulti),
          ),
          child: Row(
            children: buttons
                .map(
                  (button) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isUltraShort ? 2 : 4,
                      ),
                      child: button,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTurnButton({
    required bool slim,
    required VoidCallback? onPressed,
    required String text,
    required bool isPhone,
    bool isUltraShort = false,
    String? shortcutHint,
    Color? backgroundColor,
  }) {
    if (slim) {
      return _buildSlimButton(
        onPressed: onPressed,
        text: text,
        shortcutHint: shortcutHint,
        backgroundColor: backgroundColor,
      );
    }
    return _buildCompactButton(
      onPressed: onPressed,
      text: text,
      isPhone: isPhone,
      isUltraShort: isUltraShort,
      shortcutHint: shortcutHint,
      backgroundColor: backgroundColor,
    );
  }

  /// Icon plus a short label for the 84pt trailing column.
  ///
  /// The semantics label and tooltip keep the full action name.
  Widget _buildSlimButton({
    required VoidCallback? onPressed,
    required String text,
    String? shortcutHint,
    Color? backgroundColor,
  }) {
    final tooltip = shortcutHint == null
        ? text
        : '$text${KeyboardShortcuts.tooltipSuffix(shortcutHint)}';

    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _withHaptic(onPressed),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              disabledBackgroundColor: Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_slimIcon(text), size: 16),
                const SizedBox(height: 1),
                Text(
                  _shortLabel(text),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortLabel(String text) {
    switch (text) {
      case 'Draw from deck':
        return 'Draw';
      case 'Take Discard':
        return 'Take';
      case 'Play Cards':
        return 'Play';
      case 'Go Out':
        return 'Out';
      case 'Go to Foot':
        return 'Foot';
      case 'Need Books':
        return 'Books';
      case 'Need Clean Book':
        return 'Clean';
      case 'Need Dirty Book':
        return 'Dirty';
      case 'Cannot Go Out':
        return 'Hold';
      default:
        return text;
    }
  }

  IconData _slimIcon(String text) {
    switch (text) {
      case 'Draw from deck':
        return Icons.style;
      case 'Take Discard':
        return Icons.layers;
      case 'Play Cards':
        return Icons.dashboard_customize;
      case 'Undo':
        return Icons.undo;
      case 'Clear':
        return Icons.clear;
      case 'Go Out':
        return Icons.flag;
      case 'Go to Foot':
        return Icons.directions_walk;
      case 'Discard':
        return Icons.south;
      default:
        return Icons.back_hand;
    }
  }

  /// Build a compact button sized appropriately for mobile screens
  Widget _buildCompactButton({
    required VoidCallback? onPressed,
    required String text,
    required bool isPhone,
    bool isUltraShort = false,
    String? shortcutHint,
    Color? backgroundColor,
  }) {
    final label = shortcutHint == null
        ? text
        : '$text${KeyboardShortcuts.tooltipSuffix(shortcutHint)}';

    final button = ElevatedButton(
      onPressed: _withHaptic(onPressed),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        disabledBackgroundColor: Colors.grey.shade800,
        padding: EdgeInsets.symmetric(
          vertical: isUltraShort
              ? 6
              : isPhone
              ? 10
              : 12,
          horizontal: isPhone ? 6 : 16,
        ),
        minimumSize: Size(isPhone ? 0 : 64, isUltraShort ? 36 : 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isPhone ? 2 : 4,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isUltraShort
              ? 12
              : isPhone
              ? 13
              : 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (shortcutHint == null) {
      return button;
    }

    return Tooltip(message: label, child: button);
  }

  /// Tiny vibration on press so mobile taps feel like Perfect Grab card deals.
  VoidCallback? _withHaptic(VoidCallback? callback) {
    if (callback == null) {
      return null;
    }
    return () {
      HapticService().selectionClick();
      callback();
    };
  }
}
