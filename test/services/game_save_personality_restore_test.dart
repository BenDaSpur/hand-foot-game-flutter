import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/config/bot_configurations.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/screens/managers/bot_turn_manager.dart';
import 'package:hand_foot_game_flutter/services/game_save_service.dart';

void main() {
  group('Continue game personality restore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    SoloGameSettings sueClaraSettings() => SoloGameSettings(
      botCount: 2,
      botPersonalities: [BotPersonality.adaptive, BotPersonality.conservative],
      enableGoingOutBonus: true,
      enableFinalTurnAfterGoingOut: true,
    );

    List<Player> sueClaraPlayers() => [
      Player(id: '1', name: 'You', type: PlayerType.human),
      Player(id: '2', name: 'Sue', type: PlayerType.bot),
      Player(id: '3', name: 'Clara', type: PlayerType.bot),
    ];

    test(
      'autosave includes bot personalities from solo settings order',
      () async {
        final controller = GameController(
          players: sueClaraPlayers(),
          seed: 708121,
          soloSettings: sueClaraSettings(),
        );
        controller.initializeGame();

        await GameSaveService.saveGame(controller.gameState, 708121);

        final saved = await GameSaveService.loadGame();
        expect(saved, isNotNull);
        final bp = Map<String, String>.from(saved!['botPersonalities'] as Map);
        expect(bp['2'], equals('BotPersonality.adaptive'));
        expect(bp['3'], equals('BotPersonality.conservative'));
      },
    );

    test(
      'Continue restore assigns Sue adaptive and Clara conservative',
      () async {
        final controller = GameController(
          players: sueClaraPlayers(),
          seed: 708121,
          soloSettings: sueClaraSettings(),
        );
        controller.initializeGame();
        await GameSaveService.saveGame(controller.gameState, 708121);

        final restored = await GameController.loadSavedGame();
        expect(restored, isNotNull);
        expect(
          restored!.restoredBotPersonalities['2'],
          equals('BotPersonality.adaptive'),
        );
        expect(
          restored.restoredBotPersonalities['3'],
          equals('BotPersonality.conservative'),
        );

        final botAI = EnhancedBotAI();
        final turnManager = BotTurnManager(
          gameController: restored,
          botAI: botAI,
          onStateChanged: () {},
          logHumanAction: (_) {},
          logBotDecision:
              ({
                required String botId,
                required String decision,
                required String reasoning,
                Map<String, dynamic>? context,
                gameStateSnapshot,
              }) {},
        );
        turnManager.restoreBotPersonalities(restored.restoredBotPersonalities);

        expect(
          botAI.personalityManager.getPersonality('2'),
          equals(BotPersonality.adaptive),
        );
        expect(
          botAI.personalityManager.getPersonality('3'),
          equals(BotPersonality.conservative),
        );
      },
    );

    test(
      'legacy saves without botPersonalities derive from settings/names',
      () async {
        final settings = sueClaraSettings();
        final players = sueClaraPlayers();
        final controller = GameController(
          players: players,
          seed: 708121,
          soloSettings: settings,
        );
        controller.initializeGame();
        await GameSaveService.saveGame(controller.gameState, 708121);

        final saved = await GameSaveService.loadGame();
        expect(saved, isNotNull);
        saved!.remove('botPersonalities');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('hand_foot_game_save', jsonEncode(saved));

        final restored = GameSaveService.restoreGameController(saved);
        expect(restored, isNotNull);
        // Derived from soloSettings after missing map removed from payload
        expect(
          restored!.restoredBotPersonalities['2'],
          equals('BotPersonality.adaptive'),
        );
        expect(
          restored.restoredBotPersonalities['3'],
          equals('BotPersonality.conservative'),
        );

        final derived = resolveBotPersonalities(
          players: players,
          settings: settings,
        );
        expect(derived['3'], equals(BotPersonality.conservative));
        expect(kBotPersonalityByName['Clara'], BotPersonality.conservative);
      },
    );

    test(
      'unassigned personalities defaulted to adaptive (regression of bug)',
      () {
        final botAI = EnhancedBotAI();
        // Before fix: Continue never assigned personalities → Clara looked Adaptive
        expect(
          botAI.personalityManager.getPersonality('3'),
          equals(BotPersonality.adaptive),
        );

        botAI.assignPersonality('3', BotPersonality.conservative);
        expect(
          botAI.personalityManager.getPersonality('3'),
          equals(BotPersonality.conservative),
        );
      },
    );
  });
}
