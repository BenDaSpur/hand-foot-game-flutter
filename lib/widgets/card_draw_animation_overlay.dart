import 'dart:async';

import 'package:flutter/material.dart';
import '../config/game_config.dart';
import '../constants/hand_layout_constants.dart';
import '../models/card.dart';
import '../theme/balatro_theme.dart';
import '../utils/debug_logger.dart';
import '../utils/game_responsive_layout.dart';
import 'card_back_widget.dart';
import 'playing_card_widget.dart';

enum CardDrawAnimationType { deckDraw, discardUnlock }

class CardAnimationRequest {
  final CardDrawAnimationType type;
  final List<PlayingCard> handCards;
  final List<int> handTargetIndices;
  final List<PlayingCard> meldedCards;
  final int meldIndex;

  /// True when another player (bot or opponent) unlocked the pile.
  final bool isSpectator;

  /// Display name for spectator captions.
  final String? actorName;

  /// How many [handCards] came from the face-up discard pile.
  /// `-1` means every pickup card is treated as public.
  final int fromDiscardCount;

  const CardAnimationRequest({
    required this.type,
    required this.handCards,
    required this.handTargetIndices,
    this.meldedCards = const [],
    this.meldIndex = -1,
    this.isSpectator = false,
    this.actorName,
    this.fromDiscardCount = -1,
  });

  int get revealedFromDiscardCount {
    if (fromDiscardCount < 0) {
      return handCards.length;
    }
    return fromDiscardCount;
  }
}

class _FlyingCardVisual {
  final PlayingCard card;
  final Offset position;
  final double scale;
  final double rotation;
  final bool showBack;
  final double opacity;

  const _FlyingCardVisual({
    required this.card,
    required this.position,
    this.scale = 1,
    this.rotation = 0,
    this.showBack = false,
    this.opacity = 1,
  });

  _FlyingCardVisual copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    bool? showBack,
    double? opacity,
  }) {
    return _FlyingCardVisual(
      card: card,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      showBack: showBack ?? this.showBack,
      opacity: opacity ?? this.opacity,
    );
  }
}

typedef CardAnimationCompleteCallback = void Function();

/// Full-screen overlay that animates drawn cards from pile anchors to hand.
class CardDrawAnimationOverlay extends StatefulWidget {
  final CardAnimationRequest? request;
  final GlobalKey deckKey;
  final GlobalKey discardKey;
  final GlobalKey handStackKey;
  final GlobalKey meldAreaKey;
  final ScrollController handScrollController;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const CardDrawAnimationOverlay({
    super.key,
    required this.request,
    required this.deckKey,
    required this.discardKey,
    required this.handStackKey,
    required this.meldAreaKey,
    required this.handScrollController,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<CardDrawAnimationOverlay> createState() =>
      _CardDrawAnimationOverlayState();
}

class _CardDrawAnimationOverlayState extends State<CardDrawAnimationOverlay>
    with TickerProviderStateMixin {
  static const double _revealCenterYFactor = 0.50;
  static const double _revealFanWidthFactor = 0.86;
  static const double _minFanSpread = 28.0;
  static const double _maxFanSpread = 76.0;
  static const double _revealScale = 1.08;

  List<_FlyingCardVisual> _visuals = [];
  bool _showScrim = false;
  bool _showCaption = false;
  bool _skipped = false;
  AnimationController? _activeController;
  Timer? _pauseTimer;
  Completer<void>? _pauseCompleter;

  @override
  void initState() {
    super.initState();
    if (widget.request != null) {
      // Block hand taps immediately — isAnimating flips true before the first
      // frame, but the overlay used to stay shrink until post-frame animation.
      _showScrim = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAnimation(widget.request!);
      });
    }
  }

  @override
  void didUpdateWidget(CardDrawAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.request == null && oldWidget.request != null) {
      // Host cleared the request (complete/interrupt) — drop any leftover
      // blocker so a stale scrim cannot keep eating hand taps.
      _skipped = true;
      _activeController?.stop();
      _cancelPauseTimer();
      _showScrim = false;
      _showCaption = false;
      _visuals = [];
      return;
    }
    if (widget.request != null && widget.request != oldWidget.request) {
      _skipped = false;
      _showScrim = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAnimation(widget.request!);
      });
    }
  }

  @override
  void dispose() {
    _cancelPauseTimer();
    _activeController?.dispose();
    super.dispose();
  }

  void _cancelPauseTimer() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    final completer = _pauseCompleter;
    _pauseCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _pause(Duration duration) async {
    if (_skipped || !mounted) {
      return;
    }
    _cancelPauseTimer();
    final completer = Completer<void>();
    _pauseCompleter = completer;
    _pauseTimer = Timer(duration, () {
      _pauseTimer = null;
      _pauseCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }

  void _handleSkip() {
    if (_skipped) {
      return;
    }
    _skipped = true;
    _activeController?.stop();
    _cancelPauseTimer();
    setState(() {
      _showScrim = false;
      _showCaption = false;
      _visuals = [];
    });
    // Host wires onSkip -> complete. Avoid also calling onComplete here so a
    // replacement animation started in onSkip is not immediately cleared.
    widget.onSkip();
  }

  Future<void> _startAnimation(CardAnimationRequest request) async {
    if (_skipped || !mounted) {
      return;
    }

    try {
      setState(() {
        _showScrim = true;
        _showCaption = request.isSpectator;
        _visuals = [];
      });

      if (request.isSpectator) {
        await _runOpponentUnlockReveal(request);
        return;
      }

      if (request.type == CardDrawAnimationType.discardUnlock &&
          request.meldedCards.isNotEmpty) {
        await _runMeldBeat(request);
        if (_skipped || !mounted) {
          return;
        }
      }

      if (request.handCards.isEmpty) {
        return;
      }

      await _runRevealAndFly(request);
    } finally {
      // Always clear the animating gate, even if anchors were missing or a
      // mid-animation hand rewrite aborted the fly sequence.
      if (!_skipped && mounted) {
        _finish();
      }
    }
  }

  void _finish() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showScrim = false;
      _showCaption = false;
      _visuals = [];
    });
    widget.onComplete();
  }

  Future<void> _runOpponentUnlockReveal(CardAnimationRequest request) async {
    if (request.handCards.isEmpty) {
      return;
    }

    final source = _anchorCenter(widget.discardKey);
    if (source == null) {
      return;
    }

    final overlaySize = context.size ?? MediaQuery.sizeOf(context);
    final revealCenter = Offset(
      overlaySize.width / 2,
      overlaySize.height * _revealCenterYFactor,
    );
    final handSizes = GameResponsiveLayout.handSizes(context);
    final maxFanWidth = overlaySize.width * _revealFanWidthFactor;
    final spread = request.handCards.length <= 1
        ? 0.0
        : ((maxFanWidth - handSizes.handWidth) / (request.handCards.length - 1))
              .clamp(_minFanSpread, _maxFanSpread);
    final revealPositions = <Offset>[];
    for (int i = 0; i < request.handCards.length; i++) {
      final offset = (i - (request.handCards.length - 1) / 2) * spread;
      revealPositions.add(revealCenter + Offset(offset, 0));
    }

    final visuals = <_FlyingCardVisual>[];
    for (int i = 0; i < request.handCards.length; i++) {
      visuals.add(
        _FlyingCardVisual(
          card: request.handCards[i],
          position: source,
          showBack: i >= request.revealedFromDiscardCount,
        ),
      );
    }
    setState(() {
      _showCaption = true;
      _visuals = visuals;
    });

    await _animateVisualsToTargets(
      visuals: visuals,
      targets: revealPositions,
      duration: GameConfig.cardFlyDuration,
      endScale: _revealScale,
    );
    if (_skipped || !mounted) {
      return;
    }

    setState(() {
      _visuals = [
        for (int i = 0; i < request.handCards.length; i++)
          _FlyingCardVisual(
            card: request.handCards[i],
            position: revealPositions[i],
            scale: _revealScale,
            showBack: i >= request.revealedFromDiscardCount,
          ),
      ];
    });

    await _pause(GameConfig.cardOpponentRevealPause);
    if (_skipped || !mounted) {
      return;
    }

    await _fadeVisuals(duration: GameConfig.animationDuration);
  }

  Future<void> _animateVisualsToTargets({
    required List<_FlyingCardVisual> visuals,
    required List<Offset> targets,
    required Duration duration,
    double endScale = 1,
  }) async {
    final controller = AnimationController(vsync: this, duration: duration);
    _activeController = controller;
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    final starts = visuals.map((visual) => visual.position).toList();

    controller.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _visuals = [
          for (int i = 0; i < visuals.length; i++)
            visuals[i].copyWith(
              position: Offset.lerp(starts[i], targets[i], animation.value)!,
              scale: 1 + (endScale - 1) * animation.value,
              showBack: visuals[i].showBack,
            ),
        ];
      });
    });

    await controller.forward();
    controller.dispose();
    _activeController = null;
  }

  Future<void> _fadeVisuals({required Duration duration}) async {
    if (_visuals.isEmpty) {
      return;
    }
    final controller = AnimationController(vsync: this, duration: duration);
    _activeController = controller;
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );
    final starts = List<_FlyingCardVisual>.from(_visuals);

    controller.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _visuals = [
          for (final visual in starts)
            visual.copyWith(opacity: 1 - animation.value),
        ];
      });
    });

    await controller.forward();
    controller.dispose();
    _activeController = null;
  }

  Future<void> _runMeldBeat(CardAnimationRequest request) async {
    final meldTarget = _meldTargetCenter(request.meldIndex);
    final discardSource = _anchorCenter(widget.discardKey);
    final handSource = _handAreaCenter();

    if (meldTarget == null) {
      return;
    }

    final visuals = <_FlyingCardVisual>[];
    if (request.meldedCards.isNotEmpty && discardSource != null) {
      visuals.add(
        _FlyingCardVisual(
          card: request.meldedCards.last,
          position: discardSource,
        ),
      );
    }
    for (int i = 0; i < request.meldedCards.length - 1; i++) {
      visuals.add(
        _FlyingCardVisual(
          card: request.meldedCards[i],
          position: handSource ?? discardSource ?? meldTarget,
        ),
      );
    }

    setState(() => _visuals = visuals);
    await _animateVisuals(
      visuals: visuals,
      target: meldTarget,
      duration: GameConfig.cardMeldFlyDuration,
      showBack: false,
      endScale: 0.7,
    );
    setState(() => _visuals = []);
  }

  Future<void> _runRevealAndFly(CardAnimationRequest request) async {
    final source = request.type == CardDrawAnimationType.deckDraw
        ? _anchorCenter(widget.deckKey)
        : _anchorCenter(widget.discardKey);
    final overlaySize = context.size ?? MediaQuery.sizeOf(context);
    final revealCenter = Offset(
      overlaySize.width / 2,
      overlaySize.height * 0.42,
    );

    if (source == null) {
      return;
    }

    final handSizes = GameResponsiveLayout.handSizes(context);

    await _scrollHandToIndices(request.handTargetIndices, handSizes);

    final revealPositions = <Offset>[];
    for (int i = 0; i < request.handCards.length; i++) {
      final spread = (i - (request.handCards.length - 1) / 2) * 36;
      revealPositions.add(revealCenter + Offset(spread, 0));
    }

    final visuals = <_FlyingCardVisual>[];
    for (int i = 0; i < request.handCards.length; i++) {
      visuals.add(
        _FlyingCardVisual(
          card: request.handCards[i],
          position: source,
          showBack: request.type == CardDrawAnimationType.deckDraw,
        ),
      );
    }
    setState(() => _visuals = visuals);

    for (int i = 0; i < visuals.length; i++) {
      if (_skipped || !mounted) {
        return;
      }
      await _animateSingleVisual(
        index: i,
        target: revealPositions[i],
        duration: GameConfig.cardFlyDuration,
        showBack: request.type == CardDrawAnimationType.deckDraw,
        endScale: 1.1,
      );
      if (i < visuals.length - 1) {
        await Future<void>.delayed(GameConfig.cardStaggerDelay);
      }
    }

    if (_skipped || !mounted) {
      return;
    }

    setState(() {
      _visuals = [
        for (int i = 0; i < request.handCards.length; i++)
          _FlyingCardVisual(
            card: request.handCards[i],
            position: revealPositions[i],
            scale: 1.1,
          ),
      ];
    });

    await Future<void>.delayed(GameConfig.cardRevealPause);
    if (_skipped || !mounted) {
      return;
    }

    for (int i = 0; i < request.handCards.length; i++) {
      if (_skipped || !mounted) {
        return;
      }
      final handTarget = _handCardCenter(
        request.handTargetIndices[i],
        handSizes,
      );
      if (handTarget == null) {
        continue;
      }
      await _animateSingleVisual(
        index: i,
        target: handTarget,
        duration: GameConfig.cardFlyDuration,
        showBack: false,
        endScale: 1,
      );
      if (i < request.handCards.length - 1) {
        await Future<void>.delayed(GameConfig.cardStaggerDelay);
      }
    }
  }

  Future<void> _animateVisuals({
    required List<_FlyingCardVisual> visuals,
    required Offset target,
    required Duration duration,
    required bool showBack,
    double endScale = 1,
  }) async {
    final controller = AnimationController(vsync: this, duration: duration);
    _activeController = controller;
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );

    final starts = visuals.map((visual) => visual.position).toList();
    controller.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _visuals = [
          for (int i = 0; i < visuals.length; i++)
            visuals[i].copyWith(
              position: Offset.lerp(starts[i], target, animation.value)!,
              scale: 1 + (endScale - 1) * animation.value,
              showBack: showBack && animation.value < 0.5,
            ),
        ];
      });
    });

    await controller.forward();
    controller.dispose();
    _activeController = null;
  }

  Future<void> _animateSingleVisual({
    required int index,
    required Offset target,
    required Duration duration,
    required bool showBack,
    double endScale = 1,
  }) async {
    if (index >= _visuals.length) {
      return;
    }

    final start = _visuals[index].position;
    final card = _visuals[index].card;
    final controller = AnimationController(vsync: this, duration: duration);
    _activeController = controller;
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );

    controller.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        final updated = List<_FlyingCardVisual>.from(_visuals);
        if (index < updated.length) {
          updated[index] = updated[index].copyWith(
            position: Offset.lerp(start, target, animation.value)!,
            scale: 1 + (endScale - 1) * animation.value,
            rotation: (1 - animation.value) * 0.08,
            showBack: showBack && animation.value < 0.55,
          );
          _visuals = updated;
        }
      });
    });

    await controller.forward();
    controller.dispose();
    _activeController = null;

    if (mounted && index < _visuals.length) {
      setState(() {
        final updated = List<_FlyingCardVisual>.from(_visuals);
        updated[index] = _FlyingCardVisual(
          card: card,
          position: target,
          scale: endScale,
        );
        _visuals = updated;
      });
    }
  }

  Future<void> _scrollHandToIndices(
    List<int> indices,
    GameCardSizes handSizes,
  ) async {
    if (indices.isEmpty || !widget.handScrollController.hasClients) {
      return;
    }
    final firstIndex = indices.reduce((a, b) => a < b ? a : b);
    final targetOffset =
        (HandLayoutConstants.handCardLeft(firstIndex, handSizes) - 16).clamp(
          0.0,
          widget.handScrollController.position.maxScrollExtent,
        );
    try {
      await widget.handScrollController
          .animateTo(
            targetOffset,
            duration: GameConfig.cardRevealDuration,
            curve: Curves.easeOut,
          )
          .timeout(GameConfig.cardRevealDuration + const Duration(seconds: 1));
    } catch (error) {
      // Scroll is best-effort — never let a hung animateTo freeze discard.
      DebugLogger.warning('hand scroll during card reveal failed: $error');
    }
  }

  Offset? _anchorCenter(GlobalKey key) {
    return _widgetCenter(key);
  }

  Offset? _handAreaCenter() {
    return _widgetCenter(widget.handStackKey);
  }

  Offset? _handCardCenter(int index, GameCardSizes handSizes) {
    final stackBox =
        widget.handStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) {
      return null;
    }
    final centerInStack = HandLayoutConstants.handCardCenterInStack(
      index,
      handSizes,
      stackBox.size.height,
    );
    return _globalToOverlay(stackBox.localToGlobal(centerInStack));
  }

  Offset? _meldTargetCenter(int meldIndex) {
    final meldBox =
        widget.meldAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (meldBox == null || !meldBox.hasSize) {
      return _anchorCenter(widget.discardKey);
    }
    final verticalOffset = 48.0 + (meldIndex.clamp(0, 4) * 72.0);
    final centerInMeld = Offset(
      meldBox.size.width / 2,
      verticalOffset.clamp(24, meldBox.size.height - 24),
    );
    return _globalToOverlay(meldBox.localToGlobal(centerInMeld));
  }

  Offset? _widgetCenter(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return null;
    }
    final globalCenter = renderBox.localToGlobal(
      Offset(renderBox.size.width / 2, renderBox.size.height / 2),
    );
    return _globalToOverlay(globalCenter);
  }

  /// Overlay [Positioned] coords are relative to this widget, not the screen.
  /// Anchors live under the Scaffold body/AppBar, so convert globals first.
  Offset? _globalToOverlay(Offset global) {
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize) {
      return null;
    }
    return overlayBox.globalToLocal(global);
  }

  @override
  Widget build(BuildContext context) {
    final shouldBlockInput =
        widget.request != null || _showScrim || _visuals.isNotEmpty;
    if (!shouldBlockInput) {
      return const SizedBox.shrink();
    }

    final handSizes = GameResponsiveLayout.handSizes(context);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleSkip,
        child: Stack(
          children: [
            if (_showScrim)
              Container(color: Colors.black.withValues(alpha: 0.35)),
            if (_showCaption) _buildSpectatorCaption(),
            ..._visuals.map((visual) => _buildFlyingCard(visual, handSizes)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpectatorCaption() {
    final actorName = widget.request?.actorName?.trim();
    var name = 'Opponent';
    if (actorName != null && actorName.isNotEmpty) {
      name = actorName;
    }
    return Align(
      alignment: const Alignment(0, -0.42),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BalatroTheme.darkPurple.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BalatroTheme.neonOrange, width: 2),
          boxShadow: [
            BoxShadow(
              color: BalatroTheme.neonOrange.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$name took the discard',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BalatroTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to continue',
                style: TextStyle(
                  color: BalatroTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlyingCard(_FlyingCardVisual visual, GameCardSizes handSizes) {
    final cardWidth = handSizes.handWidth;
    final cardHeight = handSizes.handHeight;
    final widgetWidth = HandLayoutConstants.handCardWidgetWidth(handSizes);
    final widgetHeight = HandLayoutConstants.handCardWidgetHeight(handSizes);
    return Positioned(
      left: visual.position.dx - (widgetWidth / 2),
      top: visual.position.dy - (widgetHeight / 2),
      child: Opacity(
        opacity: visual.opacity,
        child: Transform.rotate(
          angle: visual.rotation,
          child: Transform.scale(
            scale: visual.scale,
            child: visual.showBack
                ? CardBackWidget(width: cardWidth, height: cardHeight)
                : PlayingCardWidget(
                    card: visual.card,
                    width: cardWidth,
                    height: cardHeight,
                    isNewlyDrawn: true,
                  ),
          ),
        ),
      ),
    );
  }
}
