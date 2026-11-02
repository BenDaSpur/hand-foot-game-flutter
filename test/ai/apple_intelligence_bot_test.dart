import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:hand_foot_game_flutter/ai/apple_intelligence_bot.dart';
import 'package:hand_foot_game_flutter/ai/apple_situation_brief.dart';
import 'package:hand_foot_game_flutter/ai/bot_decision.dart';
import 'package:hand_foot_game_flutter/ai/bot_strategic_memory.dart';
import 'package:hand_foot_game_flutter/ai/composite_bot_decision_maker.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/planner/competitive_policy.dart';
import 'package:hand_foot_game_flutter/ai/planner/legal_actions.dart';
import 'package:hand_foot_game_flutter/ai/turn_plan.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/services/foundation_models_service.dart';

class _FakeFoundationModelsService implements FoundationModelsService {
  _FakeFoundationModelsService({this.planJson});

  Map<String, dynamic>? planJson;
  bool available = true;
  int planTurnCalls = 0;
  Map<String, dynamic>? lastPrompt;
  Completer<Map<String, dynamic>?>? hang;

  @override
  Future<FoundationModelsAvailability> checkAvailability() async {
    return FoundationModelsAvailability(
      available: available,
      reason: available ? 'available' : 'unavailable for test',
    );
  }

  @override
  Future<Map<String, dynamic>?> planTurn(Map<String, dynamic> prompt) async {
    planTurnCalls++;
    lastPrompt = prompt;
    final pending = hang;
    if (pending != null) {
      return pending.future;
    }
    return planJson;
  }
}

GameController _controllerWithBots() {
  final players = [
    Player(id: '1', name: 'You', type: PlayerType.human),
    Player(id: '2', name: 'Clara', type: PlayerType.bot),
    Player(id: '3', name: 'Bob', type: PlayerType.bot),
  ];
  final controller = GameController(players: players, seed: 42);
  controller.initializeGame();
  return controller;
}

void main() {
  group('BotStrategicMemory', () {
    test('mergeUpdate replaces non-empty fields and keeps others', () {
      final memory = BotStrategicMemory(
        goals: ['finish clean aces'],
        holdRanks: ['ace'],
        plannedUnlock: 'queens',
      );

      memory.mergeUpdate(
        const BotStrategicMemoryUpdate(
          holdRanks: ['king', 'queen'],
          safeDiscards: ['three'],
          thinkingAhead: ['if they discard king, unlock'],
        ),
      );

      expect(memory.goals, ['finish clean aces']);
      expect(memory.holdRanks, ['king', 'queen']);
      expect(memory.safeDiscards, ['three']);
      expect(memory.plannedUnlock, 'queens');
      expect(memory.thinkingAhead, ['if they discard king, unlock']);
    });

    test('mergeUpdate stores avoid-feed ranks and a posture', () {
      final memory = BotStrategicMemory(posture: 'holdKeys');
      memory.mergeUpdate(
        const BotStrategicMemoryUpdate(
          avoidFeedRanks: ['king', 'nope'],
          posture: 'buildBooks',
        ),
      );
      expect(memory.avoidFeedRanks, ['king']);
      expect(memory.posture, 'buildBooks');
      expect(BotStrategicMemory.parseRanks(memory.avoidFeedRanks), {
        CardRank.king,
      });
    });

    test('toJson/fromJson round-trip', () {
      final memory = BotStrategicMemory(
        goals: ['g1'],
        holdRanks: ['ace'],
        safeDiscards: ['four'],
        avoidFeedRanks: ['king'],
        posture: 'denyPile',
        plannedUnlock: 'unlock aces',
        opponentNotes: ['human has foot'],
        lastTurnSummary: 'drew deck',
        thinkingAhead: ['hold wilds'],
        updatedAtRound: 2,
        updatedAtTurn: 1,
      );

      final restored = BotStrategicMemory.fromJson(memory.toJson());
      expect(restored.goals, memory.goals);
      expect(restored.holdRanks, memory.holdRanks);
      expect(restored.safeDiscards, memory.safeDiscards);
      expect(restored.avoidFeedRanks, memory.avoidFeedRanks);
      expect(restored.posture, memory.posture);
      expect(restored.plannedUnlock, memory.plannedUnlock);
      expect(restored.opponentNotes, memory.opponentNotes);
      expect(restored.lastTurnSummary, memory.lastTurnSummary);
      expect(restored.thinkingAhead, memory.thinkingAhead);
      expect(restored.updatedAtRound, 2);
      expect(restored.updatedAtTurn, 1);
    });
  });

  group('ActiveTurnPlan', () {
    test('takeNextForPhase walks draw then stops before meld', () {
      final draw = LabeledLegalCandidate(
        id: 'c0',
        label: 'Draw from deck',
        kind: LegalActionKind.drawDeck,
        decision: BotDecision(action: 'drawFromDeck'),
      );
      final meld = LabeledLegalCandidate(
        id: 'c1',
        label: 'Stop melding',
        kind: LegalActionKind.noMeld,
        decision: BotDecision(action: 'noMeld'),
      );
      final active = ActiveTurnPlan(
        plan: BotTurnPlan(
          intent: 'draw then stop',
          stepCandidateIds: ['c0', 'c1'],
          thinkingAhead: const [],
          memoryUpdate: const BotStrategicMemoryUpdate(),
        ),
        candidatesById: {'c0': draw, 'c1': meld},
      );

      final first = active.takeNextForPhase({
        LegalActionKind.drawDeck,
        LegalActionKind.drawDiscard,
      });
      expect(first?.id, 'c0');

      final stillDraw = active.takeNextForPhase({
        LegalActionKind.drawDeck,
        LegalActionKind.drawDiscard,
      });
      expect(stillDraw, isNull);

      final nextMeld = active.takeNextForPhase({LegalActionKind.noMeld});
      expect(nextMeld?.id, 'c1');
    });
  });

  group('ApplePosture', () {
    test('buildBooks raises book weights and stall is ignored', () {
      const base = ScorerWeights(
        takePile: 1,
        playDown: 1,
        bookProgress: 1,
        cleanBook: 1,
        points: 1,
        footTransition: 1,
        goOut: 1,
        keyHold: 1,
        denial: 1,
      );
      final adjusted = ApplePosture.buildBooks.adjust(base);
      expect(adjusted.bookProgress, greaterThan(base.bookProgress));
      expect(adjusted.cleanBook, greaterThan(base.cleanBook));
      expect(adjusted.takePile, base.takePile);

      final race = ApplePosture.raceGoOut.adjust(base);
      expect(race.goOut, greaterThan(base.goOut));
      expect(race.footTransition, greaterThan(base.footTransition));

      final deny = ApplePosture.denyPile.adjust(base);
      expect(deny.takePile, greaterThan(base.takePile));
      expect(deny.denial, greaterThan(base.denial));

      final hold = ApplePosture.holdKeys.adjust(base);
      expect(hold.keyHold, greaterThan(base.keyHold));

      expect(ApplePosture.parse('stall'), isNull);
      expect(ApplePosture.parse('race_go_out'), ApplePosture.raceGoOut);
    });
  });

  group('AppleIntelligenceBot', () {
    test('timeout matches the rule bot and clears the thinking line', () async {
      final fake = _FakeFoundationModelsService(planJson: null);
      final ruleBot = EnhancedBotAI(seed: 7);
      final apple = AppleIntelligenceBot(
        ruleBot: ruleBot,
        foundationModels: fake,
      );
      final controller = _controllerWithBots();
      final botIndex = controller.gameState.players.indexWhere(
        (p) => p.type == PlayerType.bot,
      );
      controller.gameState.currentPlayerIndex = botIndex;
      controller.gameState.turnPhase = TurnPhase.draw;
      final bot = controller.gameState.players[botIndex];
      final baseline = EnhancedBotAI(seed: 7).makeDecision(bot, controller);

      await apple.beginTurn(bot, controller);
      await apple.pendingPlanFor(bot.id);
      expect(fake.planTurnCalls, 1);
      expect(apple.lastTurnIntent, isNull);

      final decision = await apple.decide(bot, controller);
      expect(decision.action, baseline.action);
    });

    test('draw takes the pile even if the model says draw the deck', () async {
      final fake = _FakeFoundationModelsService(planJson: null);
      fake.hang = Completer<Map<String, dynamic>?>();
      final apple = AppleIntelligenceBot(
        ruleBot: EnhancedBotAI(seed: 11),
        foundationModels: fake,
      );
      final controller = _controllerWithBots();
      final botIndex = controller.gameState.players.indexWhere(
        (p) => p.type == PlayerType.bot,
      );
      controller.gameState.currentPlayerIndex = botIndex;
      final bot = controller.gameState.players[botIndex];
      _armUnlock(bot, controller);

      await apple.beginTurn(bot, controller);
      try {
        final decision = await apple
            .decide(bot, controller)
            .timeout(const Duration(milliseconds: 300));
        expect(decision.action, 'drawFromDiscard');
      } finally {
        if (!fake.hang!.isCompleted) {
          fake.hang!.complete({
            'intent': 'Draw from deck and stay flexible',
            'stepCandidateIds': ['c0'],
            'posture': 'stall',
          });
        }
      }
    });

    test('plays down when the model answers noMeld', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Stop melding',
          'stepCandidateIds': ['c0'],
          'posture': 'stall',
          'thinkingAhead': <String>[],
          'goals': <String>['wait'],
          'holdRanks': <String>[],
          'safeDiscards': <String>[],
          'avoidFeedRanks': <String>[],
          'plannedUnlock': '',
          'opponentNotes': <String>[],
          'lastTurnSummary': '',
        },
      );
      final apple = AppleIntelligenceBot(
        ruleBot: EnhancedBotAI(seed: 9),
        foundationModels: fake,
      );
      final controller = _controllerWithBots();
      final botIndex = controller.gameState.players.indexWhere(
        (p) => p.type == PlayerType.bot,
      );
      controller.gameState.currentPlayerIndex = botIndex;
      final bot = controller.gameState.players[botIndex];
      bot.hasPlayedDown = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        ]);
      controller.gameState.round = 1;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      controller.gameState.discardPile.clear();

      await apple.beginTurn(bot, controller);
      final decision = await apple.decide(bot, controller);
      expect(fake.planTurnCalls, 1);
      expect(decision.action, anyOf('createMeld', 'createMultipleMelds'));
    });

    test('holdRanks keeps a pair the rule bot would discard', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Hold the fours',
          'posture': 'holdKeys',
          'holdRanks': ['four'],
          'avoidFeedRanks': ['king'],
          'thinkingAhead': <String>[],
          'goals': <String>['keys'],
          'safeDiscards': <String>[],
          'plannedUnlock': '',
          'opponentNotes': <String>[],
          'lastTurnSummary': '',
        },
      );
      final apple = AppleIntelligenceBot(
        ruleBot: EnhancedBotAI(seed: 4),
        foundationModels: fake,
      );
      final controller = _controllerWithBots();
      final botIndex = controller.gameState.players.indexWhere(
        (p) => p.type == PlayerType.bot,
      );
      controller.gameState.currentPlayerIndex = botIndex;
      final bot = controller.gameState.players[botIndex];
      _armDiscardChoice(bot, controller);

      final baseline = EnhancedBotAI(seed: 4).makeDecision(bot, controller);
      expect(baseline.action, 'discard');
      expect((baseline.data as PlayingCard).rank, CardRank.four);

      await apple.beginTurn(bot, controller);
      await apple.pendingPlanFor(bot.id);
      final decision = await apple.decide(bot, controller);
      expect(decision.action, 'discard');
      expect((decision.data as PlayingCard).rank, CardRank.ace);
    });

    test('prompt includes the expert action, rank counts, and melds', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Build books',
          'posture': 'buildBooks',
          'thinkingAhead': <String>[],
          'goals': <String>['Build books'],
          'holdRanks': <String>['ace'],
          'safeDiscards': <String>[],
          'avoidFeedRanks': <String>[],
          'plannedUnlock': '',
          'opponentNotes': <String>[],
          'lastTurnSummary': '',
        },
      );
      final apple = AppleIntelligenceBot(
        ruleBot: EnhancedBotAI(seed: 11),
        foundationModels: fake,
      );
      final controller = _controllerWithBots();
      final human = controller.gameState.players.firstWhere(
        (player) => player.type == PlayerType.human,
      );
      human.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ])!,
      );
      final botIndex = controller.gameState.players.indexWhere(
        (p) => p.type == PlayerType.bot,
      );
      controller.gameState.currentPlayerIndex = botIndex;
      controller.gameState.turnPhase = TurnPhase.draw;
      final bot = controller.gameState.players[botIndex];

      await apple.beginTurn(bot, controller);
      await apple.pendingPlanFor(bot.id);

      final prompt = fake.lastPrompt!;
      expect(prompt['rules'], AppleSituationBrief.rules);
      final expert = prompt['expert'] as Map<String, dynamic>;
      expect(expert['action'], isNotEmpty);
      expect(expert['reason'], isA<String>());
      expect(expert['reason'], isNotEmpty);
      final self = prompt['self'] as Map<String, dynamic>;
      expect(self['handCounts'], contains('×'));
      final opponents = prompt['opponents'] as List<dynamic>;
      expect(
        opponents.any((opponent) {
          final melds = (opponent as Map)['melds'] as List<dynamic>;
          return melds.any((meld) => meld.toString().contains('king'));
        }),
        isTrue,
      );

      apple.endTurn(bot);
      fake.planJson = null;
      await apple.beginTurn(bot, controller);
      await apple.pendingPlanFor(bot.id);
      final memory = fake.lastPrompt!['memory'] as Map<String, dynamic>;
      expect(memory['goals'], contains('Build books'));
      expect(memory['holdRanks'], contains('ace'));
      expect(memory['posture'], 'buildBooks');
    });

    test('stall clears the previous posture instead of reusing it', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Race out',
          'posture': 'raceGoOut',
          'thinkingAhead': <String>[],
          'goals': <String>['go out'],
          'holdRanks': <String>[],
          'safeDiscards': <String>[],
          'avoidFeedRanks': <String>[],
          'plannedUnlock': '',
          'opponentNotes': <String>[],
          'lastTurnSummary': '',
        },
      );
      final ruleBot = EnhancedBotAI(seed: 8);
      final apple = AppleIntelligenceBot(
        ruleBot: ruleBot,
        foundationModels: fake,
      );
      final controller = _controllerWithBots();
      final botIndex = controller.gameState.players.indexWhere(
        (p) => p.type == PlayerType.bot,
      );
      controller.gameState.currentPlayerIndex = botIndex;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      final bot = controller.gameState.players[botIndex];

      await apple.beginTurn(bot, controller);
      await apple.pendingPlanFor(bot.id);
      apple.endTurn(bot);

      fake.planJson = {
        'intent': 'Stall',
        'posture': 'stall',
        'thinkingAhead': <String>[],
        'goals': <String>['go out'],
        'holdRanks': <String>[],
        'safeDiscards': <String>[],
        'avoidFeedRanks': <String>[],
        'plannedUnlock': '',
        'opponentNotes': <String>[],
        'lastTurnSummary': '',
      };
      await apple.beginTurn(bot, controller);
      await apple.pendingPlanFor(bot.id);
      final baseline = EnhancedBotAI(seed: 8).makeDecision(bot, controller);
      final decision = await apple.decide(bot, controller);
      expect(decision.action, baseline.action);

      apple.endTurn(bot);
      fake.planJson = null;
      await apple.beginTurn(bot, controller);
      await apple.pendingPlanFor(bot.id);
      final memory = fake.lastPrompt!['memory'] as Map<String, dynamic>;
      expect(memory['posture'], isEmpty);
      expect(memory['goals'], contains('go out'));
    });

    test('plans once per turn across phases', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Race the books',
          'posture': 'raceGoOut',
          'thinkingAhead': <String>['go out next'],
          'goals': <String>['books'],
          'holdRanks': <String>[],
          'safeDiscards': <String>[],
          'avoidFeedRanks': <String>[],
          'plannedUnlock': '',
          'opponentNotes': <String>[],
          'lastTurnSummary': '',
        },
      );
      final apple = AppleIntelligenceBot(
        ruleBot: EnhancedBotAI(seed: 9),
        foundationModels: fake,
      );
      final controller = _controllerWithBots();
      final botIndex = controller.gameState.players.indexWhere(
        (p) => p.type == PlayerType.bot,
      );
      controller.gameState.currentPlayerIndex = botIndex;
      controller.gameState.turnPhase = TurnPhase.draw;
      final bot = controller.gameState.players[botIndex];

      await apple.beginTurn(bot, controller);
      await apple.decide(bot, controller);
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      await apple.decide(bot, controller);
      controller.gameState.turnPhase = TurnPhase.discard;
      await apple.decide(bot, controller);
      expect(fake.planTurnCalls, 1);
    });
  });

  group('CompositeBotDecisionMaker', () {
    test('routes only configured apple seats to Apple bot', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Apple plan',
          'posture': 'buildBooks',
          'thinkingAhead': <String>[],
          'goals': <String>['g'],
          'holdRanks': <String>[],
          'safeDiscards': <String>[],
          'avoidFeedRanks': <String>[],
          'plannedUnlock': '',
          'opponentNotes': <String>[],
          'lastTurnSummary': '',
        },
      );
      final ruleBot = EnhancedBotAI(seed: 5);
      final apple = AppleIntelligenceBot(
        ruleBot: ruleBot,
        foundationModels: fake,
      );
      final composite = CompositeBotDecisionMaker(
        ruleBot: ruleBot,
        appleBot: apple,
      );

      final controller = _controllerWithBots();
      final bots = controller.gameState.players
          .where((p) => p.type == PlayerType.bot)
          .toList();
      composite.setApplePlayerIds([bots.first.id]);

      controller.gameState.currentPlayerIndex = controller.gameState.players
          .indexWhere((p) => p.id == bots.first.id);
      controller.gameState.turnPhase = TurnPhase.draw;

      await composite.beginTurn(bots.first, controller);
      await apple.pendingPlanFor(bots.first.id);
      expect(fake.planTurnCalls, 1);
      expect(composite.lastTurnIntent, 'Apple plan');
      expect(composite.lastTurnIntentFor(bots.first.id), 'Apple plan');
      // Shared Apple intent must not surface on a following rule-bot seat.
      expect(composite.lastTurnIntentFor(bots.last.id), isNull);

      await composite.beginTurn(bots.last, controller);
      expect(fake.planTurnCalls, 1);
      expect(composite.lastTurnIntentFor(bots.last.id), isNull);
    });
  });

  group('BotTurnPlan.fromJson', () {
    test('accepts flat memory fields from native Generable payload', () {
      final plan = BotTurnPlan.fromJson({
        'intent': 'Play carefully',
        'posture': 'denyPile',
        'stepCandidateIds': ['c0', 'c2'],
        'thinkingAhead': ['deny queens'],
        'goals': ['clean book'],
        'holdRanks': ['queen'],
        'avoidFeedRanks': ['king'],
        'safeDiscards': ['five'],
        'plannedUnlock': 'queens later',
        'opponentNotes': ['human foot'],
        'lastTurnSummary': 'held keys',
      });

      expect(plan.intent, 'Play carefully');
      expect(plan.posture, ApplePosture.denyPile);
      expect(plan.stepCandidateIds, ['c0', 'c2']);
      expect(plan.memoryUpdate.goals, ['clean book']);
      expect(plan.memoryUpdate.holdRanks, ['queen']);
      expect(plan.memoryUpdate.avoidFeedRanks, ['king']);
      expect(plan.memoryUpdate.posture, 'denyPile');
      expect(plan.memoryUpdate.plannedUnlock, 'queens later');
    });
  });
}

void _armUnlock(Player bot, GameController controller) {
  bot.hasPlayedDown = true;
  bot.hasPickedUpFoot = true;
  bot.foot
    ..clear()
    ..addAll([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
      const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
    ]);
  bot.melds
    ..clear()
    ..addAll([
      _book(CardRank.ace, dirty: false),
      _book(CardRank.queen, dirty: true),
    ]);
  controller.gameState.discardPile
    ..clear()
    ..addAll(
      List.generate(
        11,
        (index) =>
            PlayingCard(suit: Suit.values[index % 4], rank: CardRank.ace),
      ),
    )
    ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.king));
  controller.gameState.turnPhase = TurnPhase.draw;
  controller.gameState.hasDrawnFromDeck = false;
  controller.gameState.discardPileFrozen = false;
}

void _armDiscardChoice(Player bot, GameController controller) {
  bot.hasPlayedDown = true;
  bot.hasPickedUpFoot = false;
  bot.hand
    ..clear()
    ..addAll([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
      const PlayingCard(suit: Suit.spades, rank: CardRank.four),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
    ]);
  bot.melds.clear();
  controller.gameState.discardPile
    ..clear()
    ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.nine))
    ..add(const PlayingCard(suit: Suit.diamonds, rank: CardRank.king));
  controller.gameState.turnPhase = TurnPhase.discard;
  controller.gameState.hasDrawnFromDeck = true;
  controller.gameState.discardPileFrozen = false;
}

Meld _book(CardRank rank, {required bool dirty}) {
  final cards = <PlayingCard>[];
  final naturalCount = dirty ? 6 : 7;
  for (var i = 0; i < naturalCount; i++) {
    cards.add(PlayingCard(suit: Suit.values[i % 4], rank: rank));
  }
  if (dirty) {
    cards.add(const PlayingCard(suit: Suit.clubs, rank: CardRank.two));
  }
  return Meld.createMeld(cards)!;
}
