import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/game_config.dart';
import '../models/perfect_grab_deal_profile.dart';
import '../theme/balatro_theme.dart';
import 'card_back_widget.dart';

enum _PerfectGrabPhase { intro, countdown, playing, result }

/// Timing-based mini-game: grab exactly [PerfectGrabDealProfile.target] cards.
///
/// Cards deal automatically at accelerating speed with per-round variance.
/// Tap GRAB when you believe you have the target count for a bonus.
class PerfectGrabMiniGame extends StatefulWidget {
  final int roundNumber;
  final void Function(bool earnedBonus) onComplete;
  final PerfectGrabDealProfile dealProfile;

  /// Fixed deal interval for deterministic widget tests.
  @visibleForTesting
  final Duration? fixedDealInterval;

  const PerfectGrabMiniGame({
    super.key,
    required this.roundNumber,
    required this.onComplete,
    required this.dealProfile,
    this.fixedDealInterval,
  });

  static Future<bool> show(
    BuildContext context, {
    required int roundNumber,
    PerfectGrabDealProfile? dealProfile,
    Duration? fixedDealInterval,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: PerfectGrabMiniGame(
            roundNumber: roundNumber,
            dealProfile: dealProfile ?? PerfectGrabDealProfile.standard(),
            fixedDealInterval: fixedDealInterval,
            onComplete: (earnedBonus) {
              Navigator.of(dialogContext).pop(earnedBonus);
            },
          ),
        );
      },
    ).then((result) => result ?? false);
  }

  @override
  State<PerfectGrabMiniGame> createState() => _PerfectGrabMiniGameState();
}

class _PerfectGrabMiniGameState extends State<PerfectGrabMiniGame>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();

  _PerfectGrabPhase _phase = _PerfectGrabPhase.intro;
  int _cardCount = 0;
  int _countdown = 3;
  bool? _earnedBonus;
  Timer? _timer;
  late final AnimationController _pulseController;

  int get _target => widget.dealProfile.target;

  int get _maxCards => widget.dealProfile.maxCards;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.92,
      upperBound: 1.08,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _phase = _PerfectGrabPhase.countdown;
      _countdown = 3;
    });
    _scheduleCountdownTick();
  }

  void _scheduleCountdownTick() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (!mounted) {
        return;
      }
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
        _scheduleCountdownTick();
      } else {
        _beginDealing();
      }
    });
  }

  void _beginDealing() {
    setState(() {
      _phase = _PerfectGrabPhase.playing;
      _cardCount = 0;
    });
    _scheduleNextCard();
  }

  Duration _dealIntervalForCard(int nextCardIndex) {
    if (widget.fixedDealInterval != null) {
      return widget.fixedDealInterval!;
    }

    var interval = widget.dealProfile.dealIntervalForCard(
      nextCardIndex,
      _random,
    );
    if (widget.dealProfile.stutterBeforeCard.contains(nextCardIndex)) {
      interval += widget.dealProfile.stutterDelay(_random);
    }
    return interval;
  }

  void _scheduleNextCard() {
    if (_phase != _PerfectGrabPhase.playing) {
      return;
    }
    if (_cardCount >= _maxCards) {
      _finishGrab(forced: true);
      return;
    }

    _timer?.cancel();
    _timer = Timer(_dealIntervalForCard(_cardCount + 1), () {
      if (!mounted || _phase != _PerfectGrabPhase.playing) {
        return;
      }
      setState(() {
        _cardCount++;
      });
      HapticFeedback.selectionClick();
      _scheduleNextCard();
    });
  }

  void _finishGrab({bool forced = false}) {
    _timer?.cancel();
    final success = !forced && _cardCount == _target;
    setState(() {
      _phase = _PerfectGrabPhase.result;
      _earnedBonus = success;
    });
    if (success) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        widget.onComplete(success);
      }
    });
  }

  void _skipMiniGame() {
    _timer?.cancel();
    widget.onComplete(false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
      decoration: BalatroTheme.glowDecoration(
        backgroundColor: BalatroTheme.darkPurple,
        glowColor: BalatroTheme.neonGreen,
        borderRadius: 20,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
            const SizedBox(height: 12),
            ...(_phase != _PerfectGrabPhase.result ? [_buildSkipButton()] : []),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Perfect Grab',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: BalatroTheme.neonYellow,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Round ${widget.roundNumber} — grab exactly $_target cards',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: BalatroTheme.secondaryText),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _PerfectGrabPhase.intro:
        return _buildIntro();
      case _PerfectGrabPhase.countdown:
        return _buildCountdown();
      case _PerfectGrabPhase.playing:
        return _buildPlaying();
      case _PerfectGrabPhase.result:
        return _buildResult();
    }
  }

  Widget _buildIntro() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.back_hand, color: BalatroTheme.neonGreen, size: 56),
        const SizedBox(height: 16),
        Text(
          'After shuffling, reach across the table and grab your hand & foot '
          'in one swoop.\n\n'
          'Cards will deal automatically — tap GRAB at exactly $_target cards '
          'to earn +${GameConfig.perfectGrabBonus} bonus points!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: BalatroTheme.primaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startCountdown,
            style: ElevatedButton.styleFrom(
              backgroundColor: BalatroTheme.neonGreen,
              foregroundColor: BalatroTheme.deepPurple,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('GET READY'),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: Text(
        '$_countdown',
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          color: BalatroTheme.neonPink,
          fontWeight: FontWeight.bold,
          fontSize: 96,
        ),
      ),
    );
  }

  Widget _buildPlaying() {
    final isNearTarget = (_cardCount - _target).abs() <= 2 && _cardCount > 0;
    final counterColor = _cardCount == _target
        ? BalatroTheme.neonGreen
        : isNearTarget
        ? BalatroTheme.neonYellow
        : BalatroTheme.primaryText;

    return Column(
      children: [
        Text(
          '$_cardCount',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: counterColor,
            fontWeight: FontWeight.bold,
            fontSize: 72,
          ),
        ),
        Text(
          'cards grabbed',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: BalatroTheme.secondaryText),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackHeight = min(constraints.maxHeight, 220.0);
              final cardWidth = min(constraints.maxWidth * 0.34, 96.0);
              final cardHeight = cardWidth / GameConfig.cardAspectRatio;
              final visibleCards = min(
                _cardCount,
                GameConfig.perfectGrabVisibleCardCap,
              );

              return Center(
                child: SizedBox(
                  width: cardWidth + 24,
                  height: stackHeight,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: List.generate(
                      visibleCards,
                      (i) => Positioned(
                        bottom: i * 6.0,
                        child: CardBackWidget(
                          width: cardWidth,
                          height: cardHeight,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        ScaleTransition(
          scale: _pulseController,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _finishGrab();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BalatroTheme.neonPink,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text(
                'GRAB!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final success = _earnedBonus ?? false;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          success ? Icons.celebration : Icons.close,
          color: success ? BalatroTheme.neonGreen : BalatroTheme.neonOrange,
          size: 64,
        ),
        const SizedBox(height: 16),
        Text(
          success ? 'Perfect Grab!' : 'So Close...',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: success ? BalatroTheme.neonGreen : BalatroTheme.neonOrange,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          success
              ? '+${GameConfig.perfectGrabBonus} bonus points added!'
              : 'You grabbed $_cardCount cards. Need exactly $_target.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: BalatroTheme.primaryText),
        ),
      ],
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: _skipMiniGame,
      child: Text(
        'Skip (no bonus)',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: BalatroTheme.secondaryText),
      ),
    );
  }
}
