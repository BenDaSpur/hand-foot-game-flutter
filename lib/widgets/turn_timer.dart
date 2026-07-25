import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/balatro_theme.dart';

/// A visual turn timer that counts down during a player's turn.
/// Shows warning colors as time runs low.
class TurnTimer extends StatefulWidget {
  /// Default turn length in seconds.
  static const int defaultTurnDurationSeconds = 120;

  /// Remaining seconds at which the countdown turns orange.
  static const int lowTimeWarningSeconds = 30;

  /// Remaining seconds at which the countdown turns red.
  static const int criticalTimeWarningSeconds = 10;

  /// Longest a pause may hold the countdown before it resumes on its own.
  ///
  /// Pausing exists so a player thinking through a play-down is not
  /// auto-discarded mid-decision, but an untimed modal must not be able to
  /// stall the table indefinitely.
  static const int defaultMaxPauseSeconds = 60;

  /// Duration of the turn in seconds
  final int turnDurationSeconds;

  /// Whether the timer is active (should count down)
  final bool isActive;

  /// Whether the countdown is temporarily suspended, for example while a
  /// modal has the player's attention. Unlike clearing [isActive], pausing
  /// preserves the remaining time instead of restarting the turn.
  final bool isPaused;

  /// How long [isPaused] may hold the countdown before it resumes anyway.
  final int maxPauseSeconds;

  /// Callback when time runs out
  final VoidCallback? onTimeUp;

  /// Callback with remaining seconds (for warnings)
  final void Function(int remainingSeconds)? onTick;

  const TurnTimer({
    super.key,
    this.turnDurationSeconds = defaultTurnDurationSeconds,
    this.isActive = true,
    this.isPaused = false,
    this.maxPauseSeconds = defaultMaxPauseSeconds,
    this.onTimeUp,
    this.onTick,
  });

  @override
  State<TurnTimer> createState() => _TurnTimerState();
}

class _TurnTimerState extends State<TurnTimer> {
  Timer? _timer;
  Timer? _pauseCapTimer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.turnDurationSeconds;
    if (widget.isActive) {
      if (widget.isPaused) {
        _pauseTimer();
      } else {
        _startTimer();
      }
    }
  }

  @override
  void didUpdateWidget(TurnTimer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset timer when turn changes (isActive toggles off then on)
    if (widget.isActive && !oldWidget.isActive) {
      _remainingSeconds = widget.turnDurationSeconds;
      if (widget.isPaused) {
        _pauseTimer();
      } else {
        _startTimer();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopTimer();
    } else if (widget.isActive && widget.isPaused != oldWidget.isPaused) {
      // Suspend/resume without losing the remaining time.
      if (widget.isPaused) {
        _pauseTimer();
      } else {
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  /// Suspends the countdown, but only for [TurnTimer.maxPauseSeconds] so an
  /// abandoned modal cannot hold the turn open forever.
  void _pauseTimer() {
    _stopTimer();
    _pauseCapTimer = Timer(Duration(seconds: widget.maxPauseSeconds), () {
      if (!mounted || !widget.isActive) {
        return;
      }
      _startTimer();
      // The countdown is running again even though isPaused is still set, so
      // the paused indicator has to be repainted.
      setState(() {});
    });
  }

  /// True while the countdown is genuinely suspended, as opposed to paused for
  /// longer than [TurnTimer.maxPauseSeconds] and resumed by the cap.
  bool get _isCountdownSuspended => widget.isPaused && _timer == null;

  void _startTimer() {
    _stopTimer(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      widget.onTick?.call(_remainingSeconds);

      if (_remainingSeconds <= 0) {
        timer.cancel();
        widget.onTimeUp?.call();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _pauseCapTimer?.cancel();
    _pauseCapTimer = null;
  }

  /// Reset the timer to full duration
  void reset() {
    setState(() {
      _remainingSeconds = widget.turnDurationSeconds;
    });
    if (!widget.isActive) {
      return;
    }
    if (widget.isPaused) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  Color _getTimerColor() {
    if (_remainingSeconds <= TurnTimer.criticalTimeWarningSeconds) {
      return Colors.red;
    } else if (_remainingSeconds <= TurnTimer.lowTimeWarningSeconds) {
      return Colors.orange;
    } else {
      return BalatroTheme.neonGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final progress = _remainingSeconds / widget.turnDurationSeconds;
    final color = _getTimerColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: BalatroTheme.darkPurple.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isCountdownSuspended ? Icons.pause_circle_outline : Icons.timer,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          // Progress indicator
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: BalatroTheme.deepPurple,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeString,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
          // Warning indicator when low on time
          if (_remainingSeconds <= TurnTimer.lowTimeWarningSeconds) ...[
            const SizedBox(width: 4),
            Icon(
              _remainingSeconds <= TurnTimer.criticalTimeWarningSeconds
                  ? Icons.warning
                  : Icons.schedule,
              color: color,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}

/// Provider key for turn timer settings
class TurnTimerSettings {
  final bool enabled;
  final int durationSeconds;
  final bool autoDiscardOnTimeout;

  const TurnTimerSettings({
    this.enabled = false,
    this.durationSeconds = TurnTimer.defaultTurnDurationSeconds,
    this.autoDiscardOnTimeout = true,
  });

  TurnTimerSettings copyWith({
    bool? enabled,
    int? durationSeconds,
    bool? autoDiscardOnTimeout,
  }) {
    return TurnTimerSettings(
      enabled: enabled ?? this.enabled,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      autoDiscardOnTimeout: autoDiscardOnTimeout ?? this.autoDiscardOnTimeout,
    );
  }
}
