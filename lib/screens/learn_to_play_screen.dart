import 'package:flutter/material.dart';

import '../config/solo_game_settings.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/learn_to_play_preferences.dart';
import '../theme/balatro_theme.dart';
import '../tutorial/learn_to_play_coordinator.dart';
import '../tutorial/learn_to_play_session.dart';
import '../tutorial/learn_to_play_step.dart';
import '../widgets/learn_to_play_coach_banner.dart';
import '../widgets/playing_card_widget.dart';
import 'game_screen.dart';
import 'main_menu_screen.dart';

/// Guided Learn to Play lesson on a simplified real-board layout.
class LearnToPlayScreen extends StatefulWidget {
  const LearnToPlayScreen({super.key});

  @override
  State<LearnToPlayScreen> createState() => _LearnToPlayScreenState();
}

class _LearnToPlayScreenState extends State<LearnToPlayScreen> {
  late final LearnToPlaySession _session;
  late final LearnToPlayCoordinator _coordinator;
  final List<int> _selectedIndices = [];
  bool _completionShown = false;

  @override
  void initState() {
    super.initState();
    _session = LearnToPlaySession.create();
    _coordinator = LearnToPlayCoordinator();
    LearnToPlayPreferences.dismissOffer();
  }

  Player get _human => _session.human;

  Future<void> _exitToMenu() async {
    await LearnToPlayPreferences.dismissOffer();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onContinueInfo() {
    if (!_coordinator.canPerform(LearnToPlayAction.continueInfo)) {
      return;
    }
    _coordinator.advanceOn(LearnToPlayAction.continueInfo);
    _selectedIndices.clear();
    _refresh();
    _maybeShowCompletion();
  }

  void _onDraw() {
    if (!_coordinator.canPerform(LearnToPlayAction.draw)) {
      return;
    }
    if (_session.controller.gameState.turnPhase != TurnPhase.draw) {
      return;
    }
    final ok = _session.controller.drawFromDeck();
    if (!ok) {
      return;
    }
    _session.normalizeHandAfterDraw();
    _coordinator.advanceOn(LearnToPlayAction.draw);
    _selectedIndices.clear();
    _refresh();
  }

  void _onPlayMeld() {
    if (!_coordinator.canPerform(LearnToPlayAction.meld)) {
      return;
    }
    final kings = _session.kingIndicesInHand();
    if (kings.length < 6) {
      return;
    }
    final ok = _session.controller.createMeldByIndices(kings);
    if (!ok) {
      return;
    }
    _coordinator.advanceOn(LearnToPlayAction.meld);
    _selectedIndices.clear();
    _refresh();
  }

  void _onDiscard() {
    if (!_coordinator.canPerform(LearnToPlayAction.discard)) {
      return;
    }
    final target = _session.discardTargetIndex();
    if (target == null) {
      return;
    }
    final hand = _human.currentHand;
    if (target < 0 || target >= hand.length) {
      return;
    }
    final card = hand[target];
    final ok = _session.controller.discardCard(card);
    if (!ok) {
      return;
    }
    _coordinator.advanceOn(LearnToPlayAction.discard);
    _selectedIndices.clear();
    _refresh();
  }

  void _toggleCard(int index) {
    final step = _coordinator.currentStep.requiredAction;
    if (step == LearnToPlayAction.meld) {
      final kings = _session.kingIndicesInHand();
      if (!kings.contains(index)) {
        return;
      }
      setState(() {
        if (_selectedIndices.contains(index)) {
          _selectedIndices.remove(index);
        } else {
          _selectedIndices.add(index);
        }
      });
      return;
    }
    if (step == LearnToPlayAction.discard) {
      final target = _session.discardTargetIndex();
      if (target != index) {
        return;
      }
      setState(() {
        _selectedIndices
          ..clear()
          ..add(index);
      });
    }
  }

  Future<void> _maybeShowCompletion() async {
    if (!_coordinator.isComplete || _completionShown) {
      return;
    }
    _completionShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BalatroTheme.darkPurple,
          title: const Text(
            'You learned enough to win!',
            style: TextStyle(color: BalatroTheme.primaryText),
          ),
          content: const Text(
            'You finished the basics and how-to-win tips. '
            'Try a real solo game next — build books, manage your Foot, and race to go out.',
            style: TextStyle(color: BalatroTheme.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                  (route) => false,
                );
              },
              child: const Text('Main Menu'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) =>
                        GameScreen(settings: SoloGameSettings.defaults),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Play Solo'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _coordinator.currentStep;
    final hand = _human.currentHand;
    final kingIndices = _session.kingIndicesInHand();
    final discardIndex = _session.discardTargetIndex();
    final canDraw = _coordinator.canPerform(LearnToPlayAction.draw);
    final canMeld = _coordinator.canPerform(LearnToPlayAction.meld);
    final canDiscard =
        _coordinator.canPerform(LearnToPlayAction.discard) &&
        _selectedIndices.length == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn to Play'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Exit lesson',
          onPressed: _exitToMenu,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BalatroTheme.deepPurple,
              BalatroTheme.darkPurple,
              BalatroTheme.mediumPurple,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LearnToPlayCoachBanner(
                  step: step,
                  progress: _coordinator.progress,
                  showContinue: _coordinator.isInfoStep,
                  onContinue: _onContinueInfo,
                ),
                const SizedBox(height: 16),
                _buildBoardSummary(),
                const SizedBox(height: 12),
                if (_human.melds.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your melds (${_human.melds.length})',
                      style: const TextStyle(
                        color: BalatroTheme.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 70,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final meld in _human.melds)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: BalatroTheme.darkPurple,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: BalatroTheme.neonGreen.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${meld.cards.length} cards'
                                '${meld.isBook ? (meld.isClean ? ' · Clean book' : ' · Dirty book') : ''}',
                                style: const TextStyle(
                                  color: BalatroTheme.primaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _human.hasPickedUpFoot ? 'Your Foot' : 'Your Hand',
                    style: const TextStyle(
                      color: BalatroTheme.accentText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < hand.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: PlayingCardWidget(
                                card: hand[i],
                                isSelected: _selectedIndices.contains(i),
                                isPlayable:
                                    (canMeld && kingIndices.contains(i)) ||
                                    (canDiscard && discardIndex == i) ||
                                    (_coordinator.canPerform(
                                          LearnToPlayAction.discard,
                                        ) &&
                                        discardIndex == i),
                                onTap: () => _toggleCard(i),
                                width: 54,
                                height: 76,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: canDraw ? _onDraw : null,
                      icon: const Icon(Icons.style),
                      label: const Text('Draw from deck'),
                    ),
                    ElevatedButton.icon(
                      onPressed: canMeld ? _onPlayMeld : null,
                      icon: const Icon(Icons.grid_view),
                      label: const Text('Play Cards'),
                    ),
                    ElevatedButton.icon(
                      onPressed: canDiscard ? _onDiscard : null,
                      icon: const Icon(Icons.outbox),
                      label: Text(
                        _human.currentHand.length == 1 &&
                                !_human.hasPickedUpFoot
                            ? 'Go to Foot'
                            : 'Discard',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardSummary() {
    final state = _session.controller.gameState;
    final opponent = state.players.firstWhere(
      (p) => p.type == PlayerType.bot,
      orElse: () => state.players.last,
    );
    return Row(
      children: [
        Expanded(
          child: _summaryChip(
            'Deck',
            '${state.deck.size}',
            Icons.layers,
            highlight: _coordinator.canPerform(LearnToPlayAction.draw),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryChip(
            'Discard',
            state.discardPile.isEmpty
                ? '—'
                : _shortCard(state.discardPile.last),
            Icons.outbox_outlined,
            highlight: false,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryChip(
            opponent.name,
            'Bot',
            Icons.smart_toy_outlined,
            highlight: false,
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(
    String label,
    String value,
    IconData icon, {
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: BalatroTheme.darkPurple,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? BalatroTheme.neonOrange
              : BalatroTheme.lightPurple.withValues(alpha: 0.4),
          width: highlight ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: BalatroTheme.accentText),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: BalatroTheme.secondaryText,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: BalatroTheme.primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortCard(PlayingCard card) {
    if (card.isJoker) {
      return 'Joker';
    }
    final rank = card.rank.name;
    final suit = card.suit?.name.substring(0, 1).toUpperCase() ?? '';
    return '$rank$suit';
  }
}
