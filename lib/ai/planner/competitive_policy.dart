import '../../config/game_config.dart';
import '../../game/game_controller.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../bot_config.dart';
import '../bot_end_game_manager.dart';
import '../bot_game_context.dart';
import '../bot_meld_analyzer.dart';
import '../bot_personality.dart';

/// Hard constraints and personality weights for the competitive planner.
///
/// Production analytics (2026.08): humans unlock 10–17% of draws; bots ~3%
/// because they play down late and rarely hold the live top pair. These
/// constraints encode that lesson instead of human hand-size mimicry.
class CompetitivePolicy {
  /// Pile size that makes play-down / unlock contest urgent.
  static const int contestablePileSize = 6;

  /// Play down even on a quiet pile once the hand is this large.
  static const int latePlayDownHandSize = 14;

  /// How many recent discard cards (besides the top) seed live key ranks.
  static const int recentDiscardLookback = 8;

  /// Hard-take any eligible unlock unless [canEmptyThisTurn] is true.
  ///
  /// Requires a verified meld/discard path that leaves at most one card.
  /// Hand size alone is not enough — pass [context] and [meldAnalyzer].
  static bool canEmptyThisTurn(
    Player bot, {
    BotGameContext? context,
    BotMeldAnalyzer? meldAnalyzer,
  }) {
    if (!bot.hasPickedUpFoot || !bot.canGoOutWithBooks) {
      return false;
    }
    final handSize = bot.currentHand.length;
    if (handSize > BotConfig.goOutThisTurnMaxHand) {
      return false;
    }
    if (handSize <= 1) {
      return true;
    }
    if (context == null || meldAnalyzer == null) {
      return false;
    }
    return _remainingAfterLegalPlays(bot, context, meldAnalyzer) <= 1;
  }

  static int _remainingAfterLegalPlays(
    Player bot,
    BotGameContext context,
    BotMeldAnalyzer meldAnalyzer,
  ) {
    final controller = context.controller;
    if (controller is! GameController) {
      return bot.currentHand.length;
    }
    final remaining = List<PlayingCard>.from(bot.currentHand);

    void take(PlayingCard card) {
      final identicalIndex = remaining.indexWhere((c) => identical(c, card));
      if (identicalIndex >= 0) {
        remaining.removeAt(identicalIndex);
        return;
      }
      remaining.remove(card);
    }

    final additions = meldAnalyzer
        .findCardsToAddToExistingMelds(bot, controller)
        .where((addition) => !BotMeldAnalyzer.isHardBlockedAddition(addition))
        .where((addition) => BotEndGameManager.isSafeAddToMeld(bot, addition));
    for (final addition in additions) {
      final card = addition['card'];
      if (card is PlayingCard) {
        take(card);
      }
    }

    var possible = meldAnalyzer.getPossibleMelds(bot, controller);
    possible = BotMeldAnalyzer.filterCleanLaneMeldCandidates(bot, possible)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final meld in possible) {
      if (_canTakeMeld(remaining, meld)) {
        for (final card in meld) {
          take(card);
        }
      }
    }
    return remaining.length;
  }

  /// True when [remaining] has a distinct card for every meld card (by
  /// identity, then value), so duplicates and already-taken cards fail.
  static bool _canTakeMeld(
    List<PlayingCard> remaining,
    List<PlayingCard> meld,
  ) {
    final available = List<PlayingCard>.from(remaining);
    for (final card in meld) {
      final identicalIndex = available.indexWhere((c) => identical(c, card));
      if (identicalIndex >= 0) {
        available.removeAt(identicalIndex);
        continue;
      }
      final valueIndex = available.indexWhere((c) => c == card);
      if (valueIndex < 0) {
        return false;
      }
      available.removeAt(valueIndex);
    }
    return true;
  }

  static int keyCount(Player bot, CardRank? rank) {
    if (rank == null) {
      return 0;
    }
    return bot.currentHand.where((c) => !c.isWild && c.rank == rank).length;
  }

  static CardRank? liveTopRank(GameState gameState) {
    final top = gameState.topDiscard;
    if (top == null || top.isWild || top.isThree) {
      return null;
    }
    return top.rank;
  }

  /// Live top plus recent non-wild, non-three discard ranks.
  static Set<CardRank> liveKeyRanks(GameState gameState) {
    final ranks = <CardRank>{};
    final topRank = liveTopRank(gameState);
    if (topRank != null) {
      ranks.add(topRank);
    }
    final pile = gameState.discardPile;
    if (pile.length < 2) {
      return ranks;
    }
    final start = pile.length - 1 - recentDiscardLookback;
    final from = start < 0 ? 0 : start;
    for (var i = pile.length - 2; i >= from; i--) {
      final card = pile[i];
      if (card.isWild || card.isThree) {
        continue;
      }
      ranks.add(card.rank);
    }
    return ranks;
  }

  static String drawSkipReason({
    required bool hasPlayedDown,
    required bool topUnlockable,
    required int naturalTopCount,
    required bool goOutThisTurn,
  }) {
    if (!hasPlayedDown) {
      return 'notPlayedDown';
    }
    if (!topUnlockable) {
      return 'frozenTop';
    }
    if (naturalTopCount < GameConfig.minNaturalCardsForMeld) {
      return 'noKey';
    }
    if (goOutThisTurn) {
      return 'goOutThisTurn';
    }
    return 'default';
  }

  static bool humanAlreadyPlayedDown(GameState gameState, String botId) {
    return gameState.players.any(
      (p) => p.id != botId && p.type == PlayerType.human && p.hasPlayedDown,
    );
  }

  /// Visible-info guess that a human can contest the current top.
  static bool humanLikelyCanUnlock(GameState gameState, String botId) {
    final topRank = liveTopRank(gameState);
    if (topRank == null) {
      return false;
    }
    final playedDownHumans = gameState.players.where(
      (player) =>
          player.id != botId &&
          player.type == PlayerType.human &&
          player.hasPlayedDown,
    );
    if (playedDownHumans.isEmpty) {
      return false;
    }
    if (gameState.discardPile.length >= contestablePileSize) {
      return true;
    }
    return playedDownHumans.any(
      (player) => player.melds.any((m) => m.rank == topRank),
    );
  }

  static ScorerWeights weightsFor(BotPersonality personality) {
    switch (personality) {
      case BotPersonality.conservative:
        return const ScorerWeights(
          takePile: 1.0,
          playDown: 1.05,
          bookProgress: 1.25,
          cleanBook: 1.35,
          points: 1.0,
          footTransition: 1.0,
          goOut: 1.05,
          keyHold: 1.2,
          denial: 0.95,
        );
      case BotPersonality.aggressive:
        return const ScorerWeights(
          takePile: 1.25,
          playDown: 1.2,
          bookProgress: 0.95,
          cleanBook: 1.0,
          points: 1.05,
          footTransition: 1.2,
          goOut: 1.15,
          keyHold: 0.9,
          denial: 1.25,
        );
      case BotPersonality.bookBuilder:
        return const ScorerWeights(
          takePile: 1.05,
          playDown: 1.0,
          bookProgress: 1.4,
          cleanBook: 1.45,
          points: 1.1,
          footTransition: 0.95,
          goOut: 1.0,
          keyHold: 1.1,
          denial: 1.0,
        );
      case BotPersonality.adaptive:
        return const ScorerWeights(
          takePile: 1.15,
          playDown: 1.15,
          bookProgress: 1.1,
          cleanBook: 1.2,
          points: 1.0,
          footTransition: 1.1,
          goOut: 1.1,
          keyHold: 1.05,
          denial: 1.15,
        );
    }
  }
}

/// Multipliers applied to planner feature scores.
class ScorerWeights {
  final double takePile;
  final double playDown;
  final double bookProgress;
  final double cleanBook;
  final double points;
  final double footTransition;
  final double goOut;
  final double keyHold;
  final double denial;

  const ScorerWeights({
    required this.takePile,
    required this.playDown,
    required this.bookProgress,
    required this.cleanBook,
    required this.points,
    required this.footTransition,
    required this.goOut,
    required this.keyHold,
    required this.denial,
  });
}
