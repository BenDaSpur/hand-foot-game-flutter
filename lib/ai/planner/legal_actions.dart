import '../../config/game_config.dart';
import '../../game/game_controller.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/meld.dart';
import '../../models/player.dart';
import '../bot_config.dart';
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
    required bool emptyHandPile,
    bool allowWildFreeze = false,
    Set<CardRank> extraProtectedRanks = const <CardRank>{},
    Set<CardRank> extraFeedRanks = const <CardRank>{},
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
          emptyHandPile: emptyHandPile,
        );
      case TurnPhase.discard:
        return _discardActions(
          bot,
          context,
          liveKeyRanks: liveKeyRanks,
          forceSpendKeys: forceSpendKeys,
          allowWildFreeze: allowWildFreeze,
          extraProtectedRanks: extraProtectedRanks,
          extraFeedRanks: extraFeedRanks,
        );
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
    required bool emptyHandPile,
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
    final onHandPile = bot.hasPlayedDown && !bot.hasPickedUpFoot;
    final additionPool = onHandPile
        ? additions
              .where((addition) => _keepsHandPileAddition(bot, addition))
              .toList()
        : additions;
    if (additionPool.isNotEmpty) {
      actions.add(
        LegalCandidate(
          decision: BotDecision(
            action: 'addToMeld',
            data: _chooseBookBuildingAddition(
              bot,
              additionPool,
              preferFinishedBook: onHandPile,
            ),
          ),
          kind: LegalActionKind.addToMeld,
        ),
      );
    }

    var possible = meldAnalyzer.getPossibleMelds(bot, controller);
    possible = BotMeldAnalyzer.filterCleanLaneMeldCandidates(bot, possible);
    if (!forceSpendKeys) {
      possible = _filterLiveKeyMelds(bot, possible, liveTop);
    }
    List<PlayingCard>? createMeld;
    if (possible.isNotEmpty) {
      final best = meldAnalyzer.findBestMeld(
        possible,
        bot: bot,
        preferLarger: true,
      );
      if (best.isNotEmpty && BotEndGameManager.isSafeCreateMeld(bot, best)) {
        final emptiesHand = best.length >= bot.currentHand.length - 1;
        final capped = _capsNewHandPileMeld(
          bot,
          emptiesHand: emptiesHand,
          emptyHandPile: emptyHandPile,
          incomingMelds: [best],
        );
        final preferExisting = _shouldSkipNewRankForExistingPiles(
          bot,
          newMeld: best,
          hasAdditions: additions.isNotEmpty,
          emptiesHand: emptiesHand,
        );
        if (!capped && !preferExisting) {
          createMeld = best;
        }
      }
    }
    // Stuck hand pile: the rank cap left no legal add, so open one natural
    // pair that is not the live discard top. Analytics: 3,466 leftover
    // noMeld turns at 5–8 cards after compact-books.
    if (createMeld == null && emptyHandPile && additions.isEmpty) {
      final rescue = _unstickNaturalPair(bot, possible, liveTop);
      if (rescue != null && BotEndGameManager.isSafeCreateMeld(bot, rescue)) {
        createMeld = rescue;
      }
    }
    if (createMeld != null) {
      actions.add(
        LegalCandidate(
          decision: BotDecision(action: 'createMeld', data: createMeld),
          kind: LegalActionKind.createMeld,
        ),
      );
    }

    _addMaximalBurstCandidate(
      actions,
      bot,
      controller,
      liveTop: liveTop,
      forceSpendKeys: forceSpendKeys,
      emptyHandPile: emptyHandPile,
    );

    return _filterFootAndOutMelds(
      bot,
      actions,
      playDownRequirement: context.playDownRequirement,
    );
  }

  /// After play-down, stop opening short ranks and stop padding piles that
  /// are not a book, a near-book, or the missing clean/dirty lane. On foot
  /// with both go-out books, do not open another rank unless it leaves at
  /// most one card (the go-out discard).
  ///
  /// Analytics 2026.10-playdown-books: 30% of finished bots were down and
  /// never reached the foot, with ~6.8 melds and 2.1 books. Humans reached
  /// the foot 98% of the time and finished with ~4 books.
  List<LegalCandidate> _filterFootAndOutMelds(
    Player bot,
    List<LegalCandidate> actions, {
    required int playDownRequirement,
  }) {
    final onHandPile = bot.hasPlayedDown && !bot.hasPickedUpFoot;
    final dumpFoot = bot.hasPickedUpFoot && bot.canGoOutWithBooks;
    if (!onHandPile && !dumpFoot) {
      return actions;
    }
    return actions
        .where(
          (candidate) => _keepsFootAndOutMeld(
            bot,
            candidate,
            playDownRequirement: playDownRequirement,
            onHandPile: onHandPile,
            dumpFoot: dumpFoot,
          ),
        )
        .toList();
  }

  bool _keepsFootAndOutMeld(
    Player bot,
    LegalCandidate candidate, {
    required int playDownRequirement,
    required bool onHandPile,
    required bool dumpFoot,
  }) {
    switch (candidate.kind) {
      case LegalActionKind.createMeld:
        return _keepsNewRank(
          bot,
          candidate.decision.data is List<PlayingCard>
              ? candidate.decision.data as List<PlayingCard>
              : const <PlayingCard>[],
          playDownRequirement: playDownRequirement,
          onHandPile: onHandPile,
          dumpFoot: dumpFoot,
        );
      case LegalActionKind.maximalBurst:
        {
          final melds = candidate.decision.data is List<List<PlayingCard>>
              ? candidate.decision.data as List<List<PlayingCard>>
              : const <List<PlayingCard>>[];
          final used = melds.fold<int>(0, (sum, meld) => sum + meld.length);
          if (_leavesAtMostOne(bot, used)) {
            return true;
          }
          if (dumpFoot) {
            return false;
          }
          return melds.every(
            (meld) => _keepsNewRank(
              bot,
              meld,
              playDownRequirement: playDownRequirement,
              onHandPile: onHandPile,
              dumpFoot: dumpFoot,
              cardsUsedOverride: used,
            ),
          );
        }
      case LegalActionKind.addToMeld:
        if (dumpFoot) {
          return true;
        }
        if (!onHandPile) {
          return true;
        }
        return _keepsHandPileAddition(bot, candidate.decision.data);
      case LegalActionKind.noMeld:
      case LegalActionKind.playDown:
      case LegalActionKind.drawDeck:
      case LegalActionKind.drawDiscard:
      case LegalActionKind.goOut:
      case LegalActionKind.endTurn:
      case LegalActionKind.discard:
      case LegalActionKind.error:
        return true;
    }
  }

  bool _keepsNewRank(
    Player bot,
    List<PlayingCard> meld, {
    required int playDownRequirement,
    required bool onHandPile,
    required bool dumpFoot,
    int? cardsUsedOverride,
  }) {
    if (meld.isEmpty) {
      return false;
    }
    final used = cardsUsedOverride ?? meld.length;
    if (_leavesAtMostOne(bot, used)) {
      return true;
    }
    if (dumpFoot) {
      return false;
    }
    if (!onHandPile) {
      return true;
    }
    if (!_isNewRank(bot, meld)) {
      // createMeld of an existing rank is executed as an add. A 3-card
      // group must not pad a short pile that a one-card add would refuse.
      return _keepsSameRankExtension(bot, meld);
    }
    if (meld.length >= GameConfig.bookSize) {
      return true;
    }
    if (!_isMissingLaneCreate(bot, meld)) {
      return false;
    }
    if (playDownRequirement >= BotConfig.lateRoundWidePlayDownRequirement &&
        !_newRankCanReachBook(bot, meld)) {
      return false;
    }
    return true;
  }

  bool _leavesAtMostOne(Player bot, int cardsUsed) {
    return cardsUsed > 0 && bot.currentHand.length - cardsUsed <= 1;
  }

  bool _isNewRank(Player bot, List<PlayingCard> meld) {
    final rank = _naturalRank(meld);
    if (rank == null) {
      return false;
    }
    return !bot.melds.any((existing) => existing.rank == rank);
  }

  bool _isMissingLaneCreate(Player bot, List<PlayingCard> meld) {
    final isClean = !meld.any((card) => card.isWild);
    if (!bot.hasCleanBook && isClean && !_hasIncompleteCleanLane(bot)) {
      return true;
    }
    if (bot.hasCleanBook &&
        !bot.hasDirtyBook &&
        !isClean &&
        !_hasIncompleteDirtyLane(bot)) {
      return true;
    }
    return false;
  }

  /// A new rank can become a book from cards already in hand.
  bool _newRankCanReachBook(Player bot, List<PlayingCard> meld) {
    if (meld.length >= GameConfig.bookSize - 1) {
      return true;
    }
    final rank = _naturalRank(meld);
    if (rank == null) {
      return false;
    }
    final naturals = bot.currentHand
        .where((card) => !card.isWild && !card.isThree && card.rank == rank)
        .length;
    return naturals >= GameConfig.bookSize;
  }

  /// Hand-pile adds: finish a book, feed the missing clean/dirty lane, or
  /// (above the force-foot window) grow a pile that is already 4+ cards.
  /// Short side piles in the 1–8 card window are discarded toward the foot.
  bool _keepsHandPileAddition(Player bot, Object? data) {
    if (data is! Map<String, dynamic>) {
      return false;
    }
    final card = data['card'];
    final index = data['meldIndex'];
    if (card is! PlayingCard || index is! int) {
      return false;
    }
    if (index < 0 || index >= bot.melds.length) {
      return false;
    }
    final meld = bot.melds[index];
    final size = meld.cards.length;
    // Adding this card leaves 0–1, so the discard can empty the hand pile
    // this turn. Two kings on a short dirty pile are that case.
    if (_leavesAtMostOne(bot, 1)) {
      return true;
    }
    if (size < GameConfig.bookSize && size + 1 >= GameConfig.bookSize) {
      return true;
    }
    if (_additionFeedsMissingLane(bot, meld, card)) {
      return true;
    }
    if (bot.currentHand.length > BotConfig.handPileForceFootMaxHand &&
        size >= 4 &&
        size < GameConfig.bookSize) {
      return true;
    }
    return false;
  }

  /// Same keep rules as [_keepsHandPileAddition], using the pile size after
  /// every card in a same-rank create lands on the existing meld.
  bool _keepsSameRankExtension(Player bot, List<PlayingCard> meld) {
    final rank = _naturalRank(meld);
    if (rank == null) {
      return false;
    }
    final index = bot.melds.indexWhere((existing) => existing.rank == rank);
    if (index < 0) {
      return true;
    }
    final existing = bot.melds[index];
    if (!meld.every(existing.canAddCard)) {
      return false;
    }
    final size = existing.cards.length;
    final projected = size + meld.length;
    if (size < GameConfig.bookSize && projected >= GameConfig.bookSize) {
      return true;
    }
    if (meld.any((card) => _additionFeedsMissingLane(bot, existing, card))) {
      return true;
    }
    if (bot.currentHand.length > BotConfig.handPileForceFootMaxHand &&
        size >= 4 &&
        size < GameConfig.bookSize) {
      return true;
    }
    return false;
  }

  bool _additionFeedsMissingLane(Player bot, Meld meld, PlayingCard card) {
    final naturalOnly = !meld.cards.any((held) => held.isWild);
    if (!bot.hasCleanBook && naturalOnly && !card.isWild) {
      return true;
    }
    if (bot.hasCleanBook &&
        !bot.hasDirtyBook &&
        (!naturalOnly || card.isWild)) {
      return true;
    }
    return false;
  }

  void _addMaximalBurstCandidate(
    List<LegalCandidate> actions,
    Player bot,
    GameController controller, {
    required CardRank? liveTop,
    required bool forceSpendKeys,
    bool emptyHandPile = false,
  }) {
    if (bot.hasPickedUpFoot &&
        bot.currentHand.length <
            BotConfig.footPhaseAggressiveMeldingThreshold) {
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
    if (!meldAnalyzer.combinationFitsHand(bot.currentHand, filtered)) {
      return;
    }

    final usedCards = filtered.expand((meld) => meld).toList();
    final emptiesHand = usedCards.length >= bot.currentHand.length - 1;
    if (_capsNewHandPileMeld(
      bot,
      emptiesHand: emptiesHand,
      emptyHandPile: emptyHandPile,
      incomingMelds: filtered,
    )) {
      return;
    }
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
    required bool forceSpendKeys,
    required bool allowWildFreeze,
    Set<CardRank> extraProtectedRanks = const <CardRank>{},
    Set<CardRank> extraFeedRanks = const <CardRank>{},
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
      preserveUnlockKeys: !forceSpendKeys,
      extraProtectedRanks: forceSpendKeys ? null : liveKeyRanks,
      holdRanks: extraProtectedRanks.isEmpty ? null : extraProtectedRanks,
      extraFeedRanks: extraFeedRanks.isEmpty ? null : extraFeedRanks,
      allowWildFreeze: allowWildFreeze,
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
    var combo = meldAnalyzer.findBestPlayDownCombination(
      bot,
      controller,
      context.playDownRequirement,
    );
    if (combo.isNotEmpty &&
        !meldAnalyzer.combinationFitsHand(bot.currentHand, combo)) {
      combo = [];
    }
    if (combo.isEmpty) {
      combo = meldAnalyzer.findGreedyPlayDownCombination(
        bot,
        controller,
        context.playDownRequirement,
      );
    }
    if (combo.isEmpty) {
      return combo;
    }
    if (CompetitivePolicy.shouldSearchGreedyPlayDown(bot, context.gameState)) {
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

  /// Prefer an add that finishes the missing clean or dirty book, then any
  /// add onto a 4–6 card pile, over a leftover card on a short meld.
  Map<String, dynamic> _chooseBookBuildingAddition(
    Player bot,
    List<Map<String, dynamic>> additions, {
    bool preferFinishedBook = false,
  }) {
    Map<String, dynamic>? completesMissing;
    Map<String, dynamic>? finishesBook;
    Map<String, dynamic>? growsNearBook;
    for (final addition in additions) {
      final card = addition['card'] as PlayingCard?;
      final index = addition['meldIndex'] as int?;
      if (card == null ||
          index == null ||
          index < 0 ||
          index >= bot.melds.length) {
        continue;
      }
      final meld = bot.melds[index];
      if (meld.cards.length >= BotConfig.nearBookThreshold - 2 &&
          meld.cards.length < GameConfig.bookSize) {
        growsNearBook ??= addition;
      }
      if (preferFinishedBook && meld.cards.length == GameConfig.bookSize - 1) {
        finishesBook ??= addition;
      }
      if (meld.cards.length == GameConfig.bookSize - 1 &&
          _completesMissingGoOutBook(bot, meld, card)) {
        completesMissing ??= addition;
      }
    }
    return completesMissing ?? finishesBook ?? growsNearBook ?? additions.first;
  }

  /// A wild may finish a dirty book once a clean book exists. Naturals finish
  /// the clean book. Do not dirty a 6-card natural pile while a dirty pile
  /// can still take the wild.
  bool _completesMissingGoOutBook(Player bot, Meld meld, PlayingCard card) {
    final naturalOnly = !meld.cards.any((held) => held.isWild);
    if (!bot.hasCleanBook && naturalOnly && !card.isWild) {
      return true;
    }
    if (!bot.hasCleanBook || bot.hasDirtyBook) {
      return false;
    }
    if (!naturalOnly) {
      return true;
    }
    if (!card.isWild) {
      return false;
    }
    final dirtyLaneCanTakeWild = bot.melds.any(
      (other) =>
          !identical(other, meld) &&
          other.cards.any((held) => held.isWild) &&
          other.cards.length >= 5 &&
          other.cards.length < GameConfig.bookSize &&
          other.canAddCard(card),
    );
    return !dirtyLaneCanTakeWild;
  }

  /// One new natural rank when the hand pile cannot add to anything.
  /// Never spends the live discard top — that pair is the unlock key.
  List<PlayingCard>? _unstickNaturalPair(
    Player bot,
    List<List<PlayingCard>> possibleMelds,
    CardRank? liveTop,
  ) {
    final existingRanks = {for (final meld in bot.melds) meld.rank};
    final candidates = possibleMelds.where((meld) {
      if (meld.any((card) => card.isWild || card.isThree)) {
        return false;
      }
      final rank = _naturalRank(meld);
      if (rank == null || existingRanks.contains(rank)) {
        return false;
      }
      if (liveTop != null && rank == liveTop) {
        return false;
      }
      final naturals = meld.where((card) => card.rank == rank).length;
      return naturals >= GameConfig.minNaturalCardsForMeld;
    }).toList();
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) => b.length.compareTo(a.length));
    return candidates.first;
  }

  /// After play-down, do not open ranks past [BotConfig.handPileNewMeldCap]
  /// unless the play empties, is already a book, or is the missing go-out lane.
  /// Same-rank incoming groups extend an existing pile and do not count.
  ///
  /// On foot without go-out books, apply [BotConfig.onFootMissingBookMeldCap]
  /// so bots finish clean+dirty instead of spreading into 8–9 piles (analytics
  /// 2026.10-force-foot: avg ~1.9 books with ~6–9 melds).
  bool _capsNewHandPileMeld(
    Player bot, {
    required bool emptiesHand,
    bool emptyHandPile = false,
    List<List<PlayingCard>> incomingMelds = const [],
  }) {
    if (emptiesHand) {
      return false;
    }
    if (bot.hasPickedUpFoot) {
      if (bot.canGoOutWithBooks) {
        return false;
      }
      return _projectsPastRankCap(
        bot,
        incomingMelds: incomingMelds,
        cap: BotConfig.onFootMissingBookMeldCap,
      );
    }
    // Force-foot: waive the rank cap so booked leftovers can open a natural
    // pair instead of stalling behind four incomplete piles.
    if (emptyHandPile && bot.bookCount >= 1) {
      return false;
    }
    return _projectsPastRankCap(
      bot,
      incomingMelds: incomingMelds,
      cap: BotConfig.handPileNewMeldCap,
    );
  }

  bool _projectsPastRankCap(
    Player bot, {
    required List<List<PlayingCard>> incomingMelds,
    required int cap,
  }) {
    final existingRanks = {for (final meld in bot.melds) meld.rank};
    final newIncoming = incomingMelds.where((meld) {
      final rank = _naturalRank(meld);
      return rank != null && !existingRanks.contains(rank);
    }).toList();
    final newRanks = {for (final meld in newIncoming) _naturalRank(meld)!};
    final projected = existingRanks.length + newRanks.length;
    if (projected <= cap) {
      return false;
    }
    if (incomingMelds.isEmpty) {
      return existingRanks.length >= cap;
    }
    if (newIncoming.isEmpty) {
      return false;
    }
    return !newIncoming.every((meld) => _isExemptNewMeld(bot, meld));
  }

  /// Prefer growing existing piles to 7 over opening a leftover pair rank.
  bool _shouldSkipNewRankForExistingPiles(
    Player bot, {
    required List<PlayingCard> newMeld,
    required bool hasAdditions,
    required bool emptiesHand,
  }) {
    if (!hasAdditions || emptiesHand) {
      return false;
    }
    final rank = _naturalRank(newMeld);
    if (rank != null && bot.melds.any((meld) => meld.rank == rank)) {
      return false;
    }
    if (_isExemptNewMeld(bot, newMeld)) {
      return false;
    }
    return bot.melds.any((meld) => meld.cards.length < GameConfig.bookSize);
  }

  CardRank? _naturalRank(List<PlayingCard> meld) {
    for (final card in meld) {
      if (!card.isWild && !card.isThree) {
        return card.rank;
      }
    }
    return null;
  }

  bool _isExemptNewMeld(Player bot, List<PlayingCard> meld) {
    if (meld.length >= GameConfig.bookSize) {
      return true;
    }
    if (meld.isEmpty) {
      return false;
    }
    final isClean = !meld.any((card) => card.isWild);
    // On foot without go-out books: allow opening ONE incomplete lane for the
    // missing clean or dirty type at 3+ cards. Requiring six naturals first
    // stranded bots with four dirty ranks and no clean book — but once that
    // lane exists, further short ranks stay capped.
    if (bot.hasPickedUpFoot) {
      if (!bot.hasCleanBook && isClean) {
        return !_hasIncompleteCleanLane(bot);
      }
      if (bot.hasCleanBook && !bot.hasDirtyBook && !isClean) {
        return !_hasIncompleteDirtyLane(bot);
      }
      return false;
    }
    // Hand pile: only a near-complete missing go-out book may open past the
    // rank cap. A 3-card leftover pair is how bots spread into 5–7 dirty piles.
    final nearBook = meld.length >= GameConfig.bookSize - 1;
    if (!nearBook) {
      return false;
    }
    if (!bot.hasCleanBook && isClean) {
      return true;
    }
    if (bot.hasCleanBook && !bot.hasDirtyBook && !isClean) {
      return true;
    }
    return false;
  }

  /// Incomplete natural-only piles (not yet books) count as a started clean lane.
  bool _hasIncompleteCleanLane(Player bot) {
    return bot.melds.any(
      (meld) =>
          meld.cards.length < GameConfig.bookSize &&
          !meld.cards.any((card) => card.isWild),
    );
  }

  /// Incomplete piles that already contain a wild count as a started dirty lane.
  bool _hasIncompleteDirtyLane(Player bot) {
    return bot.melds.any(
      (meld) =>
          meld.cards.length < GameConfig.bookSize &&
          meld.cards.any((card) => card.isWild),
    );
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
