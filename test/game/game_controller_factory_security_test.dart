import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/network_adapter.dart';

void main() {
  group('GameControllerFactory Security Tests', () {
    late FirebaseNetworkAdapter adapter;

    setUp(() {
      adapter = FirebaseNetworkAdapter();
    });

    tearDown(() {
      adapter.dispose();
    });

    group('Security Validation', () {
      test('should reject actions with missing required fields', () {
        final incompleteAction = {'type': 'drawFromDeck'}; // Missing playerId

        final isValid = adapter.validateGameAction(incompleteAction, 'user123');
        expect(isValid, isFalse);
      });

      test('should reject actions with wrong player ID', () {
        final wrongPlayerAction = {
          'type': 'drawFromDeck',
          'playerId': 'attacker123', // Different from userId
        };

        final isValid = adapter.validateGameAction(
          wrongPlayerAction,
          'victim456',
        );
        expect(isValid, isFalse);
      });

      test('should reject invalid action types', () {
        final invalidActions = [
          {'type': 'hackGame', 'playerId': 'user123'},
          {'type': 'deleteAllPlayers', 'playerId': 'user123'},
          {'type': 'giveMoney', 'playerId': 'user123'},
          {'type': '', 'playerId': 'user123'}, // Empty action
        ];

        for (final action in invalidActions) {
          final isValid = adapter.validateGameAction(action, 'user123');
          expect(
            isValid,
            isFalse,
            reason: 'Action ${action['type']} should be rejected',
          );
        }
      });

      test('should validate action-specific requirements', () {
        // Test meld actions require cards array
        final meldWithoutCards = {
          'type': 'createMeld',
          'playerId': 'user123',
          // Missing cards array
        };
        expect(
          adapter.validateGameAction(meldWithoutCards, 'user123'),
          isFalse,
        );

        final meldWithInvalidCards = {
          'type': 'createMeld',
          'playerId': 'user123',
          'cards': 'not_an_array', // Invalid cards format
        };
        expect(
          adapter.validateGameAction(meldWithInvalidCards, 'user123'),
          isFalse,
        );

        final validMeld = {
          'type': 'createMeld',
          'playerId': 'user123',
          'cards': [
            {'rank': 'ace', 'suit': 'spades'},
          ],
        };
        expect(adapter.validateGameAction(validMeld, 'user123'), isTrue);

        // Test discard actions require card object
        final discardWithoutCard = {
          'type': 'discardCard',
          'playerId': 'user123',
          // Missing card
        };
        expect(
          adapter.validateGameAction(discardWithoutCard, 'user123'),
          isFalse,
        );

        final discardWithInvalidCard = {
          'type': 'discardCard',
          'playerId': 'user123',
          'card': 'not_a_map', // Invalid card format
        };
        expect(
          adapter.validateGameAction(discardWithInvalidCard, 'user123'),
          isFalse,
        );

        final validDiscard = {
          'type': 'discardCard',
          'playerId': 'user123',
          'card': {'rank': 'king', 'suit': 'hearts'},
        };
        expect(adapter.validateGameAction(validDiscard, 'user123'), isTrue);
      });

      test('should allow valid actions', () {
        final validActions = [
          {'type': 'drawFromDeck', 'playerId': 'user123'},
          {'type': 'drawFromDiscard', 'playerId': 'user123'},
          {'type': 'unlockDiscard', 'playerId': 'user123'},
          {'type': 'startGame', 'playerId': 'user123'},
          {'type': 'leaveGame', 'playerId': 'user123'},
        ];

        for (final action in validActions) {
          final isValid = adapter.validateGameAction(action, 'user123');
          expect(
            isValid,
            isTrue,
            reason: 'Action ${action['type']} should be allowed',
          );
        }
      });
    });

    group('Player Authorization', () {
      test('should reject empty parameters', () {
        expect(
          adapter.validatePlayerAuthorization('', 'user123', 'drawFromDeck'),
          isFalse,
        );
        expect(
          adapter.validatePlayerAuthorization('game123', '', 'drawFromDeck'),
          isFalse,
        );
        expect(
          adapter.validatePlayerAuthorization('game123', 'user123', ''),
          isFalse,
        );
      });

      test('should handle host-only actions', () {
        // These should pass authorization (host validation would be done elsewhere)
        expect(
          adapter.validatePlayerAuthorization(
            'game123',
            'host123',
            'startGame',
          ),
          isTrue,
        );
        expect(
          adapter.validatePlayerAuthorization(
            'game123',
            'host123',
            'deleteGame',
          ),
          isTrue,
        );
      });

      test('should allow regular actions for all players', () {
        final regularActions = [
          'drawFromDeck',
          'discardCard',
          'createMeld',
          'leaveGame',
        ];

        for (final action in regularActions) {
          expect(
            adapter.validatePlayerAuthorization('game123', 'user123', action),
            isTrue,
            reason: 'Action $action should be allowed for regular players',
          );
        }
      });
    });

    group('Input Sanitization', () {
      test('should remove dangerous HTML script tags', () {
        final maliciousInput = {
          'playerName': 'User<script>alert("XSS")</script>Name',
          'message': '<script src="http://evil.com/script.js"></script>Hello',
        };

        final sanitized = adapter.sanitizeInput(maliciousInput);

        expect(sanitized['playerName'], equals('UserName'));
        expect(sanitized['message'], equals('Hello'));
      });

      test('should remove dangerous HTML style tags', () {
        final maliciousInput = {
          'playerName': 'User<style>body{display:none}</style>Name',
          'description': '<style>*{background:red}</style>Game description',
        };

        final sanitized = adapter.sanitizeInput(maliciousInput);

        expect(sanitized['playerName'], equals('UserName'));
        expect(sanitized['description'], equals('Game description'));
      });

      test('should remove potentially dangerous keys', () {
        final maliciousInput = {
          'playerName': 'TestPlayer',
          '_privateKey': 'secret123',
          '__internal': 'hidden_value',
          'adminAccess': 'true',
          'ADMIN_PANEL': 'enabled',
          'normalField': 'safe_value',
        };

        final sanitized = adapter.sanitizeInput(maliciousInput);

        expect(sanitized.containsKey('_privateKey'), isFalse);
        expect(sanitized.containsKey('__internal'), isFalse);
        expect(sanitized.containsKey('adminAccess'), isFalse);
        expect(sanitized.containsKey('ADMIN_PANEL'), isFalse);
        expect(sanitized.containsKey('normalField'), isTrue);
        expect(sanitized['normalField'], equals('safe_value'));
      });

      test('should sanitize nested objects and arrays recursively', () {
        final nestedInput = {
          'user': {
            'name': 'Test<script>hack()</script>User',
            '_secret': 'should_be_removed',
            'profile': {
              'bio': 'Hello & "welcome" to my profile',
              'adminRights': 'true',
            },
          },
          'messages': [
            'Normal message',
            'Dangerous<script>alert(1)</script>message',
            {'text': 'Safe<b>bold</b>text', '_internal': 'hidden'},
          ],
        };

        final sanitized = adapter.sanitizeInput(nestedInput);

        // Check nested object sanitization
        final userObj = sanitized['user'] as Map<String, dynamic>;
        expect(userObj['name'], equals('TestUser'));
        expect(userObj.containsKey('_secret'), isFalse);

        final profileObj = userObj['profile'] as Map<String, dynamic>;
        expect(profileObj['bio'], equals('Hello  welcome to my profile'));
        expect(profileObj.containsKey('adminRights'), isFalse);

        // Check array sanitization
        final messages = sanitized['messages'] as List;
        expect(messages[0], equals('Normal message'));
        expect(messages[1], equals('Dangerousmessage'));

        final messageObj = messages[2] as Map<String, dynamic>;
        expect(messageObj['text'], equals('Safeboldtext'));
        expect(messageObj.containsKey('_internal'), isFalse);
      });

      test('should handle edge cases in sanitization', () {
        final edgeCases = {
          'emptyString': '',
          'nullValue': null,
          'numberValue': 123,
          'booleanValue': true,
          'complexScript':
              '<SCRIPT type="text/javascript">alert("XSS")</SCRIPT>',
          'mixedCase': '<ScRiPt>bad()</ScRiPt>content',
          'nestedTags': '<div><script>alert(1)</script></div>',
          'malformedHtml': 'alert<b>nested</b>safe',
        };

        final sanitized = adapter.sanitizeInput(edgeCases);

        expect(sanitized['emptyString'], equals(''));
        expect(sanitized['nullValue'], isNull);
        expect(sanitized['numberValue'], equals(123));
        expect(sanitized['booleanValue'], equals(true));
        expect(sanitized['complexScript'], equals(''));
        expect(sanitized['mixedCase'], equals('content'));
        expect(sanitized['nestedTags'], equals(''));
        expect(sanitized['malformedHtml'], equals('alertnestedsafe'));
      });

      test('should preserve safe content while removing dangerous elements', () {
        final mixedInput = {
          'title': 'Game: Hand & Foot Tournament',
          'description':
              'Join us for a fun game! Rules: <script>steal()</script>No cheating allowed.',
          'playerCount': 4,
          'settings': {
            'difficulty': 'Medium',
            'timer': '30 minutes',
            'notes': 'Have fun! <style>hide</style>Good luck!',
          },
        };

        final sanitized = adapter.sanitizeInput(mixedInput);

        expect(sanitized['title'], equals('Game: Hand  Foot Tournament'));
        expect(
          sanitized['description'],
          equals('Join us for a fun game! Rules: No cheating allowed.'),
        );
        expect(sanitized['playerCount'], equals(4));

        final settings = sanitized['settings'] as Map<String, dynamic>;
        expect(settings['difficulty'], equals('Medium'));
        expect(settings['timer'], equals('30 minutes'));
        expect(settings['notes'], equals('Have fun! Good luck!'));
      });
    });
  });
}
