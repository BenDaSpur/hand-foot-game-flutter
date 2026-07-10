import 'dart:async';

import 'package:flutter/material.dart';
import '../game/events/game_event.dart';
import '../game/events/game_event_bus.dart';
import '../models/card.dart';
import '../models/player.dart';
import 'card_draw_animation_overlay.dart';

/// Inherited scope exposing card draw animation state to descendants.
class CardAnimationScope extends InheritedWidget {
  final bool isAnimating;
  final Set<int> hiddenHandIndices;

  const CardAnimationScope({
    super.key,
    required this.isAnimating,
    required this.hiddenHandIndices,
    required super.child,
  });

  static CardAnimationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CardAnimationScope>();
  }

  static bool animationActive(BuildContext context) {
    return maybeOf(context)?.isAnimating ?? false;
  }

  static bool shouldHideHandCard(BuildContext context, int index) {
    final scope = maybeOf(context);
    if (scope == null) {
      return false;
    }
    return scope.isAnimating && scope.hiddenHandIndices.contains(index);
  }

  @override
  bool updateShouldNotify(CardAnimationScope oldWidget) {
    return isAnimating != oldWidget.isAnimating ||
        hiddenHandIndices != oldWidget.hiddenHandIndices;
  }
}

/// Host widget that listens for draw events and runs overlay animations.
class CardAnimationHost extends StatefulWidget {
  final Widget child;
  final GameEventBus eventBus;
  final Player Function()? localHumanPlayer;
  final GlobalKey deckKey;
  final GlobalKey discardKey;
  final GlobalKey handStackKey;
  final GlobalKey meldAreaKey;
  final ScrollController handScrollController;
  final ValueChanged<bool>? onAnimationStateChanged;

  const CardAnimationHost({
    super.key,
    required this.child,
    required this.eventBus,
    required this.deckKey,
    required this.discardKey,
    required this.handStackKey,
    required this.meldAreaKey,
    required this.handScrollController,
    this.localHumanPlayer,
    this.onAnimationStateChanged,
  });

  @override
  State<CardAnimationHost> createState() => _CardAnimationHostState();
}

class _CardAnimationHostState extends State<CardAnimationHost> {
  StreamSubscription<CardDrawnEvent>? _drawSubscription;
  StreamSubscription<DiscardPileUnlockedEvent>? _unlockSubscription;

  bool _isAnimating = false;
  Set<int> _hiddenHandIndices = {};
  CardAnimationRequest? _activeRequest;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _drawSubscription = widget.eventBus.subscribeToType<CardDrawnEvent>(
      _handleCardDrawn,
    );
    _unlockSubscription = widget.eventBus
        .subscribeToType<DiscardPileUnlockedEvent>(_handleDiscardUnlocked);
  }

  @override
  void dispose() {
    _drawSubscription?.cancel();
    _unlockSubscription?.cancel();
    super.dispose();
  }

  bool _shouldAnimateFor(Player? player) {
    if (player == null || player.type != PlayerType.human) {
      return false;
    }
    final localHuman = widget.localHumanPlayer?.call();
    if (localHuman == null) {
      return true;
    }
    return player.id == localHuman.id;
  }

  void _handleCardDrawn(CardDrawnEvent event) {
    if (!_shouldAnimateFor(event.player) ||
        !event.fromDeck ||
        event.cards.isEmpty) {
      return;
    }
    _startRequest(
      CardAnimationRequest(
        type: CardDrawAnimationType.deckDraw,
        handCards: List<PlayingCard>.from(event.cards),
        handTargetIndices: _indicesForCards(event.player!, event.cards),
      ),
    );
  }

  void _handleDiscardUnlocked(DiscardPileUnlockedEvent event) {
    if (!_shouldAnimateFor(event.player)) {
      return;
    }
    _startRequest(
      CardAnimationRequest(
        type: CardDrawAnimationType.discardUnlock,
        handCards: List<PlayingCard>.from(event.handPickupCards),
        handTargetIndices: _indicesForCards(
          event.player!,
          event.handPickupCards,
        ),
        meldedCards: List<PlayingCard>.from(event.meldedCards),
        meldIndex: event.meldIndex,
      ),
    );
  }

  List<int> _indicesForCards(Player player, List<PlayingCard> cards) {
    final indices = <int>[];
    for (final card in cards) {
      for (
        int cardIndex = 0;
        cardIndex < player.currentHand.length;
        cardIndex++
      ) {
        if (identical(player.currentHand[cardIndex], card)) {
          indices.add(cardIndex);
          break;
        }
      }
    }
    return indices;
  }

  void _notifyAnimationState(bool isAnimating) {
    widget.onAnimationStateChanged?.call(isAnimating);
  }

  void _startRequest(CardAnimationRequest request) {
    if (_isAnimating) {
      _completeAnimation();
    }

    setState(() {
      _isAnimating = true;
      _hiddenHandIndices = request.handTargetIndices.toSet();
      _activeRequest = request;
      _requestVersion++;
    });
    _notifyAnimationState(true);
  }

  void _completeAnimation() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isAnimating = false;
      _hiddenHandIndices = {};
      _activeRequest = null;
    });
    _notifyAnimationState(false);
  }

  void _skipAnimation() {
    _completeAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return CardAnimationScope(
      isAnimating: _isAnimating,
      hiddenHandIndices: _hiddenHandIndices,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          CardDrawAnimationOverlay(
            key: ValueKey(_requestVersion),
            request: _activeRequest,
            deckKey: widget.deckKey,
            discardKey: widget.discardKey,
            handStackKey: widget.handStackKey,
            meldAreaKey: widget.meldAreaKey,
            handScrollController: widget.handScrollController,
            onComplete: _completeAnimation,
            onSkip: _skipAnimation,
          ),
        ],
      ),
    );
  }
}
