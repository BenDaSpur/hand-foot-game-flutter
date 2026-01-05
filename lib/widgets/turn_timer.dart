import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/balatro_theme.dart';

/// A visual turn timer that counts down during a player's turn.
/// Shows warning colors as time runs low.
class TurnTimer extends StatefulWidget {
  /// Duration of the turn in seconds
  final int turnDurationSeconds;

  /// Whether the timer is active (should count down)
  final bool isActive;

  /// Callback when time runs out
  final VoidCallback? onTimeUp;

  /// Callback with remaining seconds (for warnings)
  final void Function(int remainingSeconds)? onTick;

  const TurnTimer({
    super.key,
    this.turnDurationSeconds = 120, // 2 minutes default
    this.isActive = true,
    this.onTimeUp,
    this.onTick,
  });

  @override
  State<TurnTimer> createState() => _TurnTimerState();
}

class _TurnTimerState extends State<TurnTimer> {
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.turnDurationSeconds;
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(TurnTimer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset timer when turn changes (isActive toggles off then on)
    if (widget.isActive && !oldWidget.isActive) {
      _remainingSeconds = widget.turnDurationSeconds;
      _startTimer();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

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
  }

  /// Reset the timer to full duration
  void reset() {
    setState(() {
      _remainingSeconds = widget.turnDurationSeconds;
    });
    if (widget.isActive) {
      _startTimer();
    }
  }

  Color _getTimerColor() {
    if (_remainingSeconds <= 10) {
      return Colors.red;
    } else if (_remainingSeconds <= 30) {
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
          Icon(Icons.timer, color: color, size: 18),
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
          if (_remainingSeconds <= 30) ...[
            const SizedBox(width: 4),
            Icon(
              _remainingSeconds <= 10 ? Icons.warning : Icons.schedule,
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
    this.durationSeconds = 120,
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
