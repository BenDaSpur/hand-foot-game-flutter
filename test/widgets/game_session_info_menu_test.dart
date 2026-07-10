import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/widgets/game_session_info_menu.dart';

void main() {
  group('GameSessionInfo', () {
    test('clipboardText includes multiplayer game Firestore path', () {
      const info = GameSessionInfo(gameId: 'ABCD', playerId: 'device-123');

      final text = info.clipboardText;

      expect(text, contains('Game ID: ABCD'));
      expect(text, contains('Firestore: games/ABCD'));
      expect(text, contains('Player: device-123'));
      expect(text, contains('App:'));
      expect(text, contains('Bot AI:'));
    });

    test('clipboardText includes solo session and seed', () {
      const info = GameSessionInfo(
        analyticsSessionId: 'session_1234567890',
        gameSeed: '42',
      );

      final text = info.clipboardText;

      expect(text, contains('Session: session_1234567890'));
      expect(text, contains('Firestore: game_sessions/session_1234567890'));
      expect(text, contains('Seed: 42'));
    });

    test('clipboardText omits session when analyticsSessionId is null', () {
      const info = GameSessionInfo(gameSeed: '42');

      final text = info.clipboardText;

      expect(text, isNot(contains('Session:')));
      expect(text, isNot(contains('game_sessions/')));
    });
  });

  group('GameSessionInfoMenu', () {
    String? clipboardText;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      clipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'Clipboard.setData') {
              clipboardText = methodCall.arguments['text'] as String;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('shows session labels and copies clipboardText on Copy IDs', (
      WidgetTester tester,
    ) async {
      const info = GameSessionInfo(
        analyticsSessionId: 'session_test_123',
        gameSeed: '99',
      );
      await tester.pumpWidget(_TestMenuHost(info: info));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('SUPPORT REFERENCE'), findsOneWidget);
      expect(find.text('Analytics session'), findsOneWidget);
      expect(find.text('session_test_123'), findsOneWidget);
      expect(find.text('Versions'), findsOneWidget);
      expect(find.text('Copy IDs'), findsOneWidget);

      await tester.tap(find.text('Copy IDs'));
      await tester.pumpAndSettle();

      expect(clipboardText, info.clipboardText);
    });
  });
}

class _TestMenuHost extends StatefulWidget {
  final GameSessionInfo info;

  const _TestMenuHost({required this.info});

  @override
  State<_TestMenuHost> createState() => _TestMenuHostState();
}

class _TestMenuHostState extends State<_TestMenuHost> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          actions: [
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == GameSessionInfoMenu.copyValue) {
                  final scaffoldContext = _scaffoldKey.currentContext;
                  if (scaffoldContext != null) {
                    GameSessionInfoMenu.copyToClipboard(
                      scaffoldContext,
                      widget.info,
                    );
                  }
                }
              },
              itemBuilder: (BuildContext context) => [
                ...GameSessionInfoMenu.buildItems(widget.info),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
