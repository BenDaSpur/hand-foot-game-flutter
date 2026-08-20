import '../../config/game_config.dart';
import '../../game/game_controller.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../bot_decision.dart';
import '../bot_discard_analyzer.dart';
import '../bot_end_game_manager.dart';
import '../bot_game_context.dart';
import '../bot_meld_analyzer.dart';
import 'competitive_policy.dart';

/// Kinds of legal actions the planner can score.
enum LegalActionKind {
  drawDeck,
  drawDiscard,
  playDown,
  createMeld,
  maximalBurst,
  addToMeld,
  noMeld,
  goOut,
  endTurn,
  discard,
  error,
}

/// A legal (or skip) action the planner may choose this phase.
class LegalCandidate {
  final BotDecision decision;
  final LegalActionKind kind;

  const LegalCandidate({required this.decision, required this.kind});
}

/// Enumerates legal bot actions for the current turn phase.
class LegalActionGenerator {
  final BotMeldAnalyzer meldAnalyzer;
  final BotDiscardAnalyzer discardAnalyzer;

  LegalActionGenerator({
    required this.meldAnalyzer,
    required this.discardAnalyzer,
  });

  List<LegalCandidate> generate(
    Player bot,
    BotGameContext context, {
    required Set<CardRank> liveKeyRanks,
    required CardRank? liveTop,
    required bool forceSpendKeys,
  }) {
    switch (context.turnPhase) {
      case TurnPhase.draw:
        return _drawActions(bot, context);
      case TurnPhase.meld:
        return _meldActions(
          bot,
          context,
          liveTop: liveTop,
          forceSpendKeys: forceSpendKeys,
        );
      case TurnPhase.discard:
        return _discardActions(bot, context, liveKeyRanks: liveKeyRanks);
    }
  }

  List<LegalCandidate> _drawActions(Player bot, BotGameContext context) {
    final actions = <LegalCandidate>[
      LegalCandidate(
        decision: BotDecision(action: 'drawFromDeck'),
        kind: LegalActionKind.drawDeck,
      ),
    ];
    if (context.canUnlockDiscard()) {
      actions.add(
        LegalCandidate(
          decision: BotDecision(action: 'drawFromDiscard'),
          kind: LegalActionKind.drawDiscard,
        ),
      );
    }
    return actions;
  }

  List<LegalCandidate> _meldActions(
    Player bot,
    BotGameContext context, {
    required CardRank? liveTop,
    required bool forceSpendKeys,
  }) {
    final actions = <LegalCandidate>[
      LegalCandidate(
        decision: BotDecision(action: 'noMeld'),
        kind: LegalActionKind.noMeld,
      ),
    ];
    if (bot.currentHand.isEmpty) {
      return actions;
    }

    final controller = context.controller as GameController?;
    if (controller == null) {
      return actions;
    }

    if (!bot.hasPlayedDown) {
      final combo = _playDownComboPreservingKeys(bot, controller, context);
      if (combo.isNotEmpty &&
          BotEndGameManager.isSafeCreateMultipleMelds(bot, combo)) {
        if (combo.length == 1) {
          actions.add(
            LegalCandidate(
              decision: BotDecision(action: 'createMeld', data: combo.first),
              kind: LegalActionKind.playDown,
            ),
          );
        } else {
          actions.add(
            LegalCandidate(
              decision: BotDecision(action: 'createMultipleMelds', data: combo),
              kind: LegalActionKind.playDown,
            ),
          );
        }
      }
      return actions;
    }

    final additions = meldAnalyzer
        .findCardsToAddToExistingMelds(bot, controller)
        .where((addition) => !BotMeldAnalyzer.isHardBlockedAddition(addition))
        .where((addition) => BotEndGameManager.isSafeAddToMeld(bot, addition))
        .where(
          (addition) =>
              forceSpendKeys ||
              !_burnsLiveKeys(
                bot,
                liveTop,
                usedCards: [addition['card'] as PlayingCard],
                allowBook: false,
              ),
        )
        .toList();
    if (additions.isNotEmpty) {
      actions.add(
        LegalCandidate(
          decision: BotDecision(action: 'addToMeld', data: additions.first),
          kind: LegalActionKind.addToMeld,
        ),
      );
    }

    var possible = meldAnalyzer.getPossibleMelds(bot, controller);
    possible = BotMeldAnalyzer.filterCleanLaneMeldCandidates(bot, possible);
    if (!forceSpendKeys) {
      possible = _filterLiveKeyMelds(bot, possible, liveTop);
    }
    if (possible.isNotEmpty) {
      final best = meldAnalyzer.findBestMeld(
        possible,
        bot: bot,
        preferLarger: true,
      );
      if (best.isNotEmpty && BotEndGameManager.isSafeCreateMeld(bot, best)) {
        actions.add(
          LegalCandidate(
            decision: BotDecision(action: 'createMeld', data: best),
            kind: LegalActionKind.createMeld,
          ),
        );
      }
    }

    _addMaximalBurstCandidate(
      actions,
      bot,
      controller,
      liveTop: liveTop,
      forceSpendKeys: forceSpendKeys,
    );

    return actions;
  }

  void _addMaximalBurstCandidate(
    List<LegalCandidate> actions,
    Player bot,
    GameController controller, {
    required CardRank? liveTop,
    required bool forceSpendKeys,
  }) {
    if (bot.hasPickedUpFoot) {
      return;
    }
    final combo = meldAnalyzer.findMaximalMeldCombination(bot, controller);
    if (combo.length < 2) {
      return;
    }
    final filtered = BotMeldAnalyzer.filterCleanLaneMeldCandidates(bot, combo);
    if (filtered.length < 2) {
      return;
    }
    if (!BotEndGameManager.isSafeCreateMultipleMelds(bot, filtered)) {
      return;
    }

    final usedCards = filtered.expand((meld) => meld).toList();
    final emptiesHand = usedCards.length >= bot.currentHand.length - 1;
    if (!forceSpendKeys &&
        !emptiesHand &&
        _burnsLiveKeys(bot, liveTop, usedCards: usedCards, allowBook: true)) {
      return;
    }

    actions.add(
      LegalCandidate(
        decision: BotDecision(action: 'createMultipleMelds', data: filtered),
        kind: LegalActionKind.maximalBurst,
      ),
    );
  }

  List<LegalCandidate> _discardActions(
    Player bot,
    BotGameContext context, {
    required Set<CardRank> liveKeyRanks,
  }) {
    if (bot.currentHand.isEmpty) {
      if (bot.canGoOut) {
        return [
          LegalCandidate(
            decision: BotDecision(action: 'goOut'),
            kind: LegalActionKind.goOut,
          ),
        ];
      }
      return [
        LegalCandidate(
          decision: BotDecision(action: 'error'),
          kind: LegalActionKind.error,
        ),
      ];
    }

    if (BotEndGameManager.wouldEmptyFootWithoutGoOut(bot)) {
      return [
        LegalCandidate(
          decision: BotDecision(action: 'endTurn'),
          kind: LegalActionKind.endTurn,
        ),
      ];
    }

    final card = discardAnalyzer.chooseCardToDiscard(
      bot,
      context.gameState,
      extraProtectedRanks: liveKeyRanks,
    );
    return [
      LegalCandidate(
        decision: BotDecision(action: 'discard', data: card),
        kind: LegalActionKind.discard,
      ),
    ];
  }

  List<List<PlayingCard>> _playDownComboPreservingKeys(
    Player bot,
    GameController controller,
    BotGameContext context,
  ) {
    final combo = meldAnalyzer.findBestPlayDownCombination(
      bot,
      controller,
      context.playDownRequirement,
    );
    if (combo.isEmpty) {
      return combo;
    }
    final top = CompetitivePolicy.liveTopRank(context.gameState);
    if (top == null || _leavesUnlockKeys(bot, combo, top)) {
      return combo;
    }

    final possible = meldAnalyzer.getPossibleMelds(bot, controller);
    final preserving = possible
        .where((meld) => _leavesUnlockKeys(bot, [meld], top))
        .toList();
    if (preserving.isEmpty) {
      return combo;
    }

    for (final meld in preserving) {
      if (meldAnalyzer.calculateTotalMeldValue([meld]) >=
          context.playDownRequirement) {
        return [meld];
      }
    }
    for (var i = 0; i < preserving.length; i++) {
      for (var j = i + 1; j < preserving.length; j++) {
        final pair = [preserving[i], preserving[j]];
        if (meldAnalyzer.calculateTotalMeldValue(pair) >=
            context.playDownRequirement) {
          return pair;
        }
      }
    }
    return combo;
  }

  bool _leavesUnlockKeys(
    Player bot,
    List<List<PlayingCard>> combination,
    CardRank unlockRank,
  ) {
    final used = combination
        .expand((meld) => meld)
        .where((card) => !card.isWild && card.rank == unlockRank)
        .length;
    return CompetitivePolicy.keyCount(bot, unlockRank) - used >=
        GameConfig.minNaturalCardsForMeld;
  }

  List<List<PlayingCard>> _filterLiveKeyMelds(
    Player bot,
    List<List<PlayingCard>> possibleMelds,
    CardRank? liveTop,
  ) {
    if (possibleMelds.isEmpty || liveTop == null) {
      return possibleMelds;
    }
    final preserving = possibleMelds
        .where(
          (meld) =>
              !_burnsLiveKeys(bot, liveTop, usedCards: meld, allowBook: true),
        )
        .toList();
    if (preserving.isNotEmpty) {
      return preserving;
    }
    return possibleMelds
        .where((meld) => meld.length >= GameConfig.bookSize)
        .toList();
  }

  bool _burnsLiveKeys(
    Player bot,
    CardRank? protectedRank, {
    required List<PlayingCard> usedCards,
    required bool allowBook,
  }) {
    if (protectedRank == null) {
      return false;
    }
    if (allowBook && usedCards.length >= GameConfig.bookSize) {
      return false;
    }
    final have = CompetitivePolicy.keyCount(bot, protectedRank);
    if (have < GameConfig.minNaturalCardsForMeld) {
      return false;
    }
    final used = usedCards
        .where((c) => !c.isWild && c.rank == protectedRank)
        .length;
    return have - used < GameConfig.minNaturalCardsForMeld;
  }
}
