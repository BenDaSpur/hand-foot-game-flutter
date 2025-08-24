import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/widgets/error_handling_widget.dart';

void main() {
  group('ErrorHandlingWidget Tests', () {
    group('Error Message Sanitization', () {
      test('should sanitize network error messages', () {
        const errorMessage =
            'SocketException: Connection failed on 192.168.1.1:8080';
        final sanitized = ErrorHandlingWidget.sanitizeErrorMessage(
          errorMessage,
        );

        expect(
          sanitized,
          equals(
            'Unable to connect to the game server. Please check your internet connection.',
          ),
        );
      });

      test('should sanitize timeout error messages', () {
        const errorMessage = 'TimeoutException: Request timeout after 30000ms';
        final sanitized = ErrorHandlingWidget.sanitizeErrorMessage(
          errorMessage,
        );

        expect(sanitized, equals('The request timed out. Please try again.'));
      });

      test('should sanitize permission error messages', () {
        const errorMessage =
            'PermissionDenied: User not authorized for this action';
        final sanitized = ErrorHandlingWidget.sanitizeErrorMessage(
          errorMessage,
        );

        expect(
          sanitized,
          equals('You do not have permission to perform this action.'),
        );
      });

      test('should sanitize Firebase error messages', () {
        const errorMessage = 'FirebaseException: Database connection failed';
        final sanitized = ErrorHandlingWidget.sanitizeErrorMessage(
          errorMessage,
        );

        expect(
          sanitized,
          equals(
            'Game service is temporarily unavailable. Please try again later.',
          ),
        );
      });

      test('should sanitize format error messages', () {
        const errorMessage = 'FormatException: Invalid JSON format in response';
        final sanitized = ErrorHandlingWidget.sanitizeErrorMessage(
          errorMessage,
        );

        expect(
          sanitized,
          equals('Invalid game data detected. Please restart the game.'),
        );
      });

      test('should provide generic message for unknown errors', () {
        const errorMessage = 'SomeUnknownException: Mysterious error occurred';
        final sanitized = ErrorHandlingWidget.sanitizeErrorMessage(
          errorMessage,
        );

        expect(
          sanitized,
          equals(
            'An unexpected error occurred. Please try again or contact support if the problem persists.',
          ),
        );
      });

      test('should preserve details for logging when requested', () {
        const errorMessage = 'Error at /Users/testuser/game/file.dart:123';
        final sanitized = ErrorHandlingWidget.sanitizeErrorMessage(
          errorMessage,
          preserveDetails: true,
        );

        expect(sanitized, equals('Error at /Users/***/game/file.dart:123'));
      });

      test('should sanitize Windows paths for logging', () {
        const errorMessage = r'Error at C:\Users\testuser\game\file.dart:123';
        final sanitized = ErrorHandlingWidget.sanitizeErrorMessage(
          errorMessage,
          preserveDetails: true,
        );

        expect(sanitized, equals(r'Error at C:\Users\***\game\file.dart:123'));
      });

      test('should sanitize file URLs for logging', () {
        const errorMessage = 'Error loading file:///home/user/secret/file.json';
        final sanitized = ErrorHandlingWidget.sanitizeErrorMessage(
          errorMessage,
          preserveDetails: true,
        );

        expect(sanitized, equals('Error loading file:///***/'));
      });
    });

    group('User Friendly Message Creation', () {
      test('should create user friendly message from exception', () {
        final exception = Exception('Network connection failed');
        final message = ErrorHandlingWidget.createUserFriendlyMessage(
          exception,
        );

        expect(
          message,
          equals(
            'Unable to connect to the game server. Please check your internet connection.',
          ),
        );
      });

      test('should create user friendly message from string error', () {
        const error = 'TimeoutException: Request timeout';
        final message = ErrorHandlingWidget.createUserFriendlyMessage(error);

        expect(message, equals('The request timed out. Please try again.'));
      });

      test('should create user friendly message from arbitrary object', () {
        final error = {
          'type': 'CustomError',
          'message': 'Something went wrong',
        };
        final message = ErrorHandlingWidget.createUserFriendlyMessage(error);

        expect(
          message,
          equals(
            'An unexpected error occurred. Please try again or contact support if the problem persists.',
          ),
        );
      });
    });

    group('Widget Factory Constructors', () {
      testWidgets('should create network error widget', (
        WidgetTester tester,
      ) async {
        final widget = ErrorHandlingWidget.networkError(
          message: 'Custom network error message',
        );

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Connection Error'), findsOneWidget);
        expect(find.text('Custom network error message'), findsOneWidget);
      });

      testWidgets('should create game state error widget', (
        WidgetTester tester,
      ) async {
        final widget = ErrorHandlingWidget.gameStateError(
          message: 'Game state corrupted',
        );

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Game Error'), findsOneWidget);
        expect(find.text('Game state corrupted'), findsOneWidget);
      });

      testWidgets('should create sync error widget', (
        WidgetTester tester,
      ) async {
        final widget = ErrorHandlingWidget.syncError(
          message: 'Failed to sync with server',
        );

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Sync Error'), findsOneWidget);
        expect(find.text('Failed to sync with server'), findsOneWidget);
      });

      testWidgets('should use default messages when not provided', (
        WidgetTester tester,
      ) async {
        final widget = ErrorHandlingWidget.networkError();

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Connection Error'), findsOneWidget);
        expect(
          find.text(
            'Lost connection to the game server. Your game progress is safe.',
          ),
          findsOneWidget,
        );
      });
    });

    group('Widget Interaction', () {
      testWidgets('should call onRetry when retry button is pressed', (
        WidgetTester tester,
      ) async {
        bool retryCalled = false;

        final widget = ErrorHandlingWidget(
          title: 'Test Error',
          message: 'Test message',
          onRetry: () {
            retryCalled = true;
          },
        );

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Retry'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(retryCalled, isTrue);
      });

      testWidgets('should call onDismiss when dismiss button is pressed', (
        WidgetTester tester,
      ) async {
        bool dismissCalled = false;

        final widget = ErrorHandlingWidget(
          title: 'Test Error',
          message: 'Test message',
          onDismiss: () {
            dismissCalled = true;
          },
        );

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Dismiss'), findsOneWidget);
        await tester.tap(find.text('Dismiss'));
        await tester.pump();

        expect(dismissCalled, isTrue);
      });

      testWidgets('should not show buttons when callbacks are null', (
        WidgetTester tester,
      ) async {
        final widget = ErrorHandlingWidget(
          title: 'Test Error',
          message: 'Test message',
          // No onRetry or onDismiss provided
        );

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Retry'), findsNothing);
        expect(find.text('Dismiss'), findsNothing);
      });

      testWidgets('should show details when provided', (
        WidgetTester tester,
      ) async {
        final widget = ErrorHandlingWidget(
          title: 'Test Error',
          message: 'Test message',
          details: 'Additional error details here',
        );

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Additional error details here'), findsOneWidget);
      });
    });

    group('Static Utility Methods', () {
      testWidgets('should show network error snackbar', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    GameErrorDialog.showNetworkError(
                      context,
                      message: 'Network connection lost',
                    );
                  },
                  child: const Text('Show Error'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Error'));
        await tester.pump();

        expect(find.text('Network connection lost'), findsOneWidget);
      });

      testWidgets('should show connection restored snackbar', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    GameErrorDialog.showConnectionRestored(context);
                  },
                  child: const Text('Show Success'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Success'));
        await tester.pump();

        expect(
          find.text('Connection restored! Game synchronized.'),
          findsOneWidget,
        );
      });
    });
  });
}
