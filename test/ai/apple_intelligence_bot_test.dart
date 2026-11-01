import 'package:flutter_test/flutter_test.dart';

import 'package:hand_foot_game_flutter/ai/apple_intelligence_bot.dart';
import 'package:hand_foot_game_flutter/ai/bot_decision.dart';
import 'package:hand_foot_game_flutter/ai/bot_strategic_memory.dart';
import 'package:hand_foot_game_flutter/ai/composite_bot_decision_maker.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/planner/legal_actions.dart';
import 'package:hand_foot_game_flutter/ai/turn_plan.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/services/foundation_models_service.dart';

class _FakeFoundationModelsService implements FoundationModelsService {
  _FakeFoundationModelsService({this.planJson});

  Map<String, dynamic>? planJson;
  bool available = true;
  int planTurnCalls = 0;
  Map<String, dynamic>? lastPrompt;

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

    test('toJson/fromJson round-trip', () {
      final memory = BotStrategicMemory(
        goals: ['g1'],
        holdRanks: ['ace'],
        safeDiscards: ['four'],
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

  group('AppleIntelligenceBot', () {
    test('falls back to rule bot when planTurn returns null', () async {
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

      await apple.beginTurn(bot, controller);
      expect(fake.planTurnCalls, 1);
      expect(apple.lastTurnIntent, isNull);

      final decision = await apple.decide(bot, controller);
      expect(decision.action, isNotEmpty);
    });

    test('uses planned draw candidate when still legal', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Draw from deck and stay flexible',
          'stepCandidateIds': ['c0'],
          'thinkingAhead': ['Hold unlock keys'],
          'goals': ['Build books'],
          'holdRanks': ['ace'],
          'safeDiscards': ['four'],
          'plannedUnlock': '',
          'opponentNotes': <String>[],
          'lastTurnSummary': 'planning draw',
        },
      );
      final ruleBot = EnhancedBotAI(seed: 11);
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

      await apple.beginTurn(bot, controller);
      expect(apple.lastTurnIntent, contains('Draw'));
      expect(fake.lastPrompt, isNotNull);
      expect(fake.lastPrompt!['candidates'], isA<List>());
      expect(fake.lastPrompt!['memory'], isA<Map>());

      final decision = await apple.decide(bot, controller);
      expect(decision.action, 'drawFromDeck');

      apple.endTurn(bot);
      fake.planJson = null;
      await apple.beginTurn(bot, controller);
      final memory = fake.lastPrompt!['memory'] as Map<String, dynamic>;
      expect(memory['goals'], contains('Build books'));
      expect(memory['holdRanks'], contains('ace'));
    });

    test('replans with live candidates when phase advances', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Draw then stop melding',
          'stepCandidateIds': ['c0'],
          'thinkingAhead': <String>['hold aces'],
          'goals': <String>['books'],
          'holdRanks': <String>['ace'],
          'safeDiscards': <String>[],
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
      expect(fake.planTurnCalls, 1);
      expect((fake.lastPrompt!['game'] as Map)['phase'], 'draw');

      // Advance to meld without consuming the draw plan via decide().
      controller.gameState.turnPhase = TurnPhase.meld;
      fake.planJson = {
        'intent': 'Stop melding',
        'stepCandidateIds': ['c0'],
        'thinkingAhead': <String>[],
        'goals': <String>['books'],
        'holdRanks': <String>['ace'],
        'safeDiscards': <String>['five'],
        'plannedUnlock': '',
        'opponentNotes': <String>[],
        'lastTurnSummary': 'drew',
      };

      final decision = await apple.decide(bot, controller);
      expect(fake.planTurnCalls, 2);
      expect((fake.lastPrompt!['game'] as Map)['phase'], 'meld');
      // c0 is always the generator's leading noMeld candidate in meld phase.
      expect(decision.action, 'noMeld');
      final candidates = fake.lastPrompt!['candidates'] as List<dynamic>;
      expect(candidates, isNotEmpty);
      expect((candidates.first as Map)['kind'], 'noMeld');
    });

    test('stale planned step falls back without throwing', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Impossible step',
          'stepCandidateIds': ['missing-id'],
          'thinkingAhead': <String>[],
          'goals': <String>[],
          'holdRanks': <String>[],
          'safeDiscards': <String>[],
          'plannedUnlock': '',
          'opponentNotes': <String>[],
          'lastTurnSummary': '',
        },
      );
      final apple = AppleIntelligenceBot(
        ruleBot: EnhancedBotAI(seed: 3),
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
      final decision = await apple.decide(bot, controller);
      expect(decision.action, anyOf('drawFromDeck', 'drawFromDiscard'));
    });
  });

  group('CompositeBotDecisionMaker', () {
    test('routes only configured apple seats to Apple bot', () async {
      final fake = _FakeFoundationModelsService(
        planJson: {
          'intent': 'Apple plan',
          'stepCandidateIds': ['c0'],
          'thinkingAhead': <String>[],
          'goals': <String>['g'],
          'holdRanks': <String>[],
          'safeDiscards': <String>[],
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
      expect(fake.planTurnCalls, 1);
      expect(composite.lastTurnIntent, 'Apple plan');

      await composite.beginTurn(bots.last, controller);
      expect(fake.planTurnCalls, 1);
    });
  });

  group('BotTurnPlan.fromJson', () {
    test('accepts flat memory fields from native Generable payload', () {
      final plan = BotTurnPlan.fromJson({
        'intent': 'Play carefully',
        'stepCandidateIds': ['c0', 'c2'],
        'thinkingAhead': ['deny queens'],
        'goals': ['clean book'],
        'holdRanks': ['queen'],
        'safeDiscards': ['five'],
        'plannedUnlock': 'queens later',
        'opponentNotes': ['human foot'],
        'lastTurnSummary': 'held keys',
      });

      expect(plan.intent, 'Play carefully');
      expect(plan.stepCandidateIds, ['c0', 'c2']);
      expect(plan.memoryUpdate.goals, ['clean book']);
      expect(plan.memoryUpdate.holdRanks, ['queen']);
      expect(plan.memoryUpdate.plannedUnlock, 'queens later');
    });
  });
}
