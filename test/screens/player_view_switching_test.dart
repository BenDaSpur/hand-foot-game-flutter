import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Helper function to test button visibility logic
/// Simulates the condition from melds_section.dart line 63
bool _shouldShowBackButton(Player? viewingPlayerMelds) {
  return viewingPlayerMelds != null;
}

void main() {
  group('Player View Switching Logic', () {
    late List<Player> players;
    late Player humanPlayer;
    late Player bot1Player;
    late Player bot2Player;

    setUp(() {
      players = [
        Player(id: 'human', name: 'You', type: PlayerType.human),
        Player(id: 'bot1', name: 'Bot 1', type: PlayerType.bot),
        Player(id: 'bot2', name: 'Bot 2', type: PlayerType.bot),
      ];

      humanPlayer = players[0];
      bot1Player = players[1];
      bot2Player = players[2];
    });

    group('Single Player Mode', () {
      test('clicking human player should set viewingPlayerMelds to null', () {
        // Simulate the logic from game_screen.dart onPlayerTap
        Player? viewingPlayerMelds;

        // Simulate clicking on human player
        final tappedPlayer = humanPlayer;
        final foundHumanPlayer = players.firstWhere(
          (p) => p.type == PlayerType.human,
        );

        viewingPlayerMelds = tappedPlayer == foundHumanPlayer
            ? null
            : tappedPlayer;

        expect(viewingPlayerMelds, isNull);
      });

      test('clicking bot player should set viewingPlayerMelds to that bot', () {
        // Simulate the logic from game_screen.dart onPlayerTap
        Player? viewingPlayerMelds;

        // Simulate clicking on bot player
        final tappedPlayer = bot1Player;
        final foundHumanPlayer = players.firstWhere(
          (p) => p.type == PlayerType.human,
        );

        viewingPlayerMelds = tappedPlayer == foundHumanPlayer
            ? null
            : tappedPlayer;

        expect(viewingPlayerMelds, equals(bot1Player));
        expect(viewingPlayerMelds?.name, equals('Bot 1'));
      });

      test(
        'switching from bot view back to human should set viewingPlayerMelds to null',
        () {
          // Start viewing a bot's melds
          Player? viewingPlayerMelds = bot1Player;
          expect(viewingPlayerMelds, equals(bot1Player));

          // Now click on human player
          final tappedPlayer = humanPlayer;
          final foundHumanPlayer = players.firstWhere(
            (p) => p.type == PlayerType.human,
          );

          viewingPlayerMelds = tappedPlayer == foundHumanPlayer
              ? null
              : tappedPlayer;

          expect(viewingPlayerMelds, isNull);
        },
      );

      test(
        'switching from one bot to another bot should update viewingPlayerMelds',
        () {
          // Start viewing bot1's melds
          Player? viewingPlayerMelds = bot1Player;
          expect(viewingPlayerMelds, equals(bot1Player));

          // Now click on bot2 player
          final tappedPlayer = bot2Player;
          final foundHumanPlayer = players.firstWhere(
            (p) => p.type == PlayerType.human,
          );

          viewingPlayerMelds = tappedPlayer == foundHumanPlayer
              ? null
              : tappedPlayer;

          expect(viewingPlayerMelds, equals(bot2Player));
          expect(viewingPlayerMelds?.name, equals('Bot 2'));
        },
      );
    });

    group('Multiplayer Mode', () {
      const String currentUserId = 'human';

      test('clicking current user should set viewingPlayerMelds to null', () {
        // Simulate the logic from multiplayer_game_screen.dart onPlayerTap
        Player? viewingPlayerMelds;

        // Simulate clicking on current user's player
        final tappedPlayer = humanPlayer;
        viewingPlayerMelds = tappedPlayer.id == currentUserId
            ? null
            : tappedPlayer;

        expect(viewingPlayerMelds, isNull);
      });

      test(
        'clicking other player should set viewingPlayerMelds to that player',
        () {
          // Simulate the logic from multiplayer_game_screen.dart onPlayerTap
          Player? viewingPlayerMelds;

          // Simulate clicking on other player
          final tappedPlayer = bot1Player;
          viewingPlayerMelds = tappedPlayer.id == currentUserId
              ? null
              : tappedPlayer;

          expect(viewingPlayerMelds, equals(bot1Player));
          expect(viewingPlayerMelds?.name, equals('Bot 1'));
        },
      );

      test(
        'switching from other player view back to current user should set viewingPlayerMelds to null',
        () {
          // Start viewing another player's melds
          Player? viewingPlayerMelds = bot1Player;
          expect(viewingPlayerMelds, equals(bot1Player));

          // Now click on current user
          final tappedPlayer = humanPlayer;
          viewingPlayerMelds = tappedPlayer.id == currentUserId
              ? null
              : tappedPlayer;

          expect(viewingPlayerMelds, isNull);
        },
      );
    });

    group('Back to Yours Button Visibility Logic', () {
      test('should show Back to yours button when viewing another player', () {
        // Simulate viewing bot's melds (not null)
        expect(_shouldShowBackButton(bot1Player), isTrue);
      });

      test('should hide Back to yours button when viewing own melds', () {
        // Simulate viewing own melds (null)
        expect(_shouldShowBackButton(null), isFalse);
      });
    });

    group('Melds Header Text Logic', () {
      test(
        'should show "Your Melds:" when viewing human player with name "You"',
        () {
          final player = humanPlayer;

          // This simulates the logic in melds_section.dart _getMeldsHeaderText
          String headerText;
          if (player.name == 'You') {
            headerText = 'Your Melds:';
          } else {
            headerText = '${player.name}\'s Melds:';
          }

          expect(headerText, equals('Your Melds:'));
        },
      );

      test('should show "Bot Name\'s Melds:" when viewing bot player', () {
        final player = bot1Player;

        // This simulates the logic in melds_section.dart _getMeldsHeaderText
        String headerText;
        if (player.name == 'You') {
          headerText = 'Your Melds:';
        } else {
          headerText = '${player.name}\'s Melds:';
        }

        expect(headerText, equals('Bot 1\'s Melds:'));
      });
    });

    group('Edge Cases', () {
      test('should handle null player gracefully in single player mode', () {
        Player? viewingPlayerMelds;

        // This shouldn't happen in practice, but testing defensive behavior
        expect(viewingPlayerMelds, isNull);

        // Clicking human when already null should remain null
        final tappedPlayer = humanPlayer;
        final foundHumanPlayer = players.firstWhere(
          (p) => p.type == PlayerType.human,
        );

        viewingPlayerMelds = tappedPlayer == foundHumanPlayer
            ? null
            : tappedPlayer;
        expect(viewingPlayerMelds, isNull);
      });

      test('should handle invalid user ID in multiplayer mode', () {
        const String invalidUserId = 'nonexistent';
        Player? viewingPlayerMelds;

        // Simulate clicking on human player with invalid current user ID
        final tappedPlayer = humanPlayer;
        viewingPlayerMelds = tappedPlayer.id == invalidUserId
            ? null
            : tappedPlayer;

        // Should treat as different player since IDs don't match
        expect(viewingPlayerMelds, equals(humanPlayer));
      });

      test(
        'should handle player list without human player in single player mode',
        () {
          final botsOnlyPlayers = [
            Player(id: 'bot1', name: 'Bot 1', type: PlayerType.bot),
            Player(id: 'bot2', name: 'Bot 2', type: PlayerType.bot),
          ];

          // This would throw in practice, but testing the logic assumption
          expect(
            () => botsOnlyPlayers.firstWhere((p) => p.type == PlayerType.human),
            throwsStateError,
          );
        },
      );
    });

    group('Player View State Consistency', () {
      test(
        'should maintain consistent state through multiple player switches',
        () {
          Player? viewingPlayerMelds;
          final foundHumanPlayer = players.firstWhere(
            (p) => p.type == PlayerType.human,
          );

          // Start with human view (null)
          expect(viewingPlayerMelds, isNull);

          // Switch to bot1
          var tappedPlayer = bot1Player;
          viewingPlayerMelds = tappedPlayer == foundHumanPlayer
              ? null
              : tappedPlayer;
          expect(viewingPlayerMelds, equals(bot1Player));

          // Switch to bot2
          tappedPlayer = bot2Player;
          viewingPlayerMelds = tappedPlayer == foundHumanPlayer
              ? null
              : tappedPlayer;
          expect(viewingPlayerMelds, equals(bot2Player));

          // Switch back to human
          tappedPlayer = humanPlayer;
          viewingPlayerMelds = tappedPlayer == foundHumanPlayer
              ? null
              : tappedPlayer;
          expect(viewingPlayerMelds, isNull);

          // Switch to bot1 again
          tappedPlayer = bot1Player;
          viewingPlayerMelds = tappedPlayer == foundHumanPlayer
              ? null
              : tappedPlayer;
          expect(viewingPlayerMelds, equals(bot1Player));
        },
      );
    });
  });
}
