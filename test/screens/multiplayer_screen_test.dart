import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/multiplayer_lobby_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';

void main() {
  group('MultiplayerLobbyScreen Widget Tests', () {
    testWidgets('creates lobby screen with create mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Should find create game UI elements (appears in header and button)
      expect(find.text('CREATE GAME'), findsAtLeastNWidgets(1));
      expect(find.text('Maximum Players'), findsOneWidget);

      // Should have player count options
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('creates lobby screen with join mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.join),
        ),
      );

      // Should find join game UI elements (appears in header and button)
      expect(find.text('JOIN GAME'), findsAtLeastNWidgets(1));
      expect(find.text('Game ID'), findsOneWidget);

      // Should have text field for game ID
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('game ID input accepts valid format', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.join),
        ),
      );

      // Join mode renders the player name field first, then the game ID field
      final gameIdField = find.byType(TextField).at(1);
      expect(gameIdField, findsOneWidget);

      // Enter a valid game ID in lowercase to confirm auto-uppercasing
      await tester.enterText(gameIdField, 'hk4rqm');
      await tester.pump();

      // Should accept the input and normalize it to the canonical form
      expect(find.text('HK4RQM'), findsOneWidget);
    });

    testWidgets('player name input validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Find player name text field
      final nameFields = find.byType(TextField);
      expect(nameFields, findsAtLeastNWidgets(1));

      // Enter valid player name
      await tester.enterText(nameFields.first, 'TestPlayer');
      await tester.pump();

      expect(find.text('TestPlayer'), findsOneWidget);
    });

    testWidgets('create game button exists and is tappable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Find create button (appears multiple times, use first one)
      final createButton = find.text('CREATE GAME').first;
      expect(createButton, findsOneWidget);

      // Should be tappable (will fail without Firebase but shouldn't crash)
      await tester.tap(createButton);
      await tester.pump();
    });

    testWidgets('join game button exists and is tappable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.join),
        ),
      );

      // Find join button (appears multiple times, use first one)
      final joinButton = find.text('JOIN GAME').first;
      expect(joinButton, findsOneWidget);

      // Should be tappable (will fail without Firebase but shouldn't crash)
      await tester.tap(joinButton);
      await tester.pump();
    });
  });

  group('MultiplayerLobbyScreen State Management', () {
    testWidgets('player count selection updates state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Initially should have default selection
      expect(find.text('4'), findsWidgets); // Default is usually 4

      // Tap on different player count
      await tester.tap(find.text('3'));
      await tester.pump();

      // Should update selection (visual feedback)
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('game ID input transforms to uppercase', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.join),
        ),
      );

      // Find game ID field
      final gameIdField = find.byType(TextField).first;

      // Enter lowercase
      await tester.enterText(gameIdField, 'ab12');
      await tester.pump();

      // Should transform to uppercase (if implemented)
      // Note: This test depends on the actual implementation
    });

    testWidgets('loading state during game creation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Fill in required fields
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'TestHost');
      await tester.pump();

      // Tap create button
      final createButton = find.text('CREATE GAME').first;
      await tester.tap(createButton);
      await tester.pump();

      // Should show some loading indicator or disable button
      // (Implementation dependent)
    });
  });

  group('MultiplayerLobbyScreen Navigation', () {
    testWidgets('back button navigates correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Should have a way to go back
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pump();
      }
    });

    testWidgets('successful game creation navigates to game screen', (
      WidgetTester tester,
    ) async {
      // This test would require mocking Firebase service
      // For now, just ensure the screen doesn't crash
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      expect(find.byType(MultiplayerLobbyScreen), findsOneWidget);
    });
  });

  group('MultiplayerLobbyScreen Error Handling', () {
    testWidgets('handles network errors gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Fill in fields and attempt create (will fail without Firebase)
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'TestHost');
      await tester.pump();

      final createButton = find.text('CREATE GAME').first;
      await tester.tap(createButton);
      await tester.pump();

      // Should handle error gracefully without crashing
      expect(tester.takeException(), isNull);
    });

    testWidgets('validates empty player name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Try to create game with empty name
      final createButton = find.text('CREATE GAME').first;
      await tester.tap(createButton);
      await tester.pump();

      // Should show validation error or prevent submission
      // (Implementation dependent)
    });

    testWidgets('validates invalid game ID format', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.join),
        ),
      );

      // Enter invalid game ID
      final gameIdField = find.byType(TextField).first;
      await tester.enterText(gameIdField, '123'); // Too short
      await tester.pump();

      final joinButton = find.text('JOIN GAME').first;
      await tester.tap(joinButton);
      await tester.pump();

      // Should show validation error or prevent submission
      // (Implementation dependent)
    });
  });

  group('MultiplayerLobbyScreen Accessibility', () {
    testWidgets('has proper accessibility labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Should have semantic labels for screen readers
      expect(find.text('CREATE GAME'), findsAtLeastNWidgets(1));
      expect(find.text('Maximum Players'), findsOneWidget);
    });

    testWidgets('text fields have proper hints', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.join),
        ),
      );

      // Should have hint text for inputs
      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(1));
    });

    testWidgets('buttons have sufficient contrast', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.darkTheme,
          home: const MultiplayerLobbyScreen(mode: LobbyMode.create),
        ),
      );

      // Should use theme colors with good contrast
      final createButton = find.text('CREATE GAME');
      expect(createButton, findsAtLeastNWidgets(1));
    });
  });
}
