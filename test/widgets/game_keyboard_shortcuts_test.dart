import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/widgets/game_keyboard_shortcuts.dart';

void main() {
  group('focusPreviousCardIndex', () {
    test('returns last card when current is null', () {
      expect(focusPreviousCardIndex(currentIndex: null, handLength: 5), 4);
    });

    test('wraps from first card to last', () {
      expect(focusPreviousCardIndex(currentIndex: 0, handLength: 5), 4);
    });

    test('moves to previous card', () {
      expect(focusPreviousCardIndex(currentIndex: 3, handLength: 5), 2);
    });
  });

  group('focusNextCardIndex', () {
    test('returns first card when current is null', () {
      expect(focusNextCardIndex(currentIndex: null, handLength: 5), 0);
    });

    test('wraps from last card to first', () {
      expect(focusNextCardIndex(currentIndex: 4, handLength: 5), 0);
    });

    test('moves to next card', () {
      expect(focusNextCardIndex(currentIndex: 2, handLength: 5), 3);
    });
  });

  group('handleGameKeyboardEvent', () {
    late int drawCount;
    late int unlockCount;
    late int meldCount;
    late int discardCount;
    late int clearCount;
    late int sortCount;
    late int toggleSelectCount;
    late int focusPreviousCount;
    late int focusNextCount;
    late int scoreboardCount;
    late int helpCount;

    GameKeyboardActions buildActions() {
      return GameKeyboardActions(
        onDrawFromDeck: () => drawCount++,
        onUnlockDiscard: () => unlockCount++,
        onOpenMeldModal: () => meldCount++,
        onDiscard: () => discardCount++,
        onClearSelection: () => clearCount++,
        onSortHand: () => sortCount++,
        onToggleSelectFocused: () => toggleSelectCount++,
        onFocusPrevious: () => focusPreviousCount++,
        onFocusNext: () => focusNextCount++,
        onShowScoreboard: () => scoreboardCount++,
        onToggleHelp: () => helpCount++,
      );
    }

    GameKeyboardContext buildContext({
      TurnPhase turnPhase = TurnPhase.draw,
      bool canUnlockDiscard = true,
      int selectedCardCount = 0,
      int handLength = 5,
      int? focusedCardIndex,
      bool isHumanTurn = true,
      bool isAnimating = false,
      bool hasInteractedSinceDraw = true,
      bool isHelpVisible = false,
    }) {
      return GameKeyboardContext(
        turnPhase: turnPhase,
        canUnlockDiscard: canUnlockDiscard,
        selectedCardCount: selectedCardCount,
        handLength: handLength,
        focusedCardIndex: focusedCardIndex,
        isHumanTurn: isHumanTurn,
        isAnimating: isAnimating,
        hasInteractedSinceDraw: hasInteractedSinceDraw,
        isHelpVisible: isHelpVisible,
      );
    }

    KeyDownEvent keyEvent(LogicalKeyboardKey key, {String? character}) {
      return KeyDownEvent(
        physicalKey: PhysicalKeyboardKey(0),
        logicalKey: key,
        character: character,
        timeStamp: Duration.zero,
      );
    }

    setUp(() {
      drawCount = 0;
      unlockCount = 0;
      meldCount = 0;
      discardCount = 0;
      clearCount = 0;
      sortCount = 0;
      toggleSelectCount = 0;
      focusPreviousCount = 0;
      focusNextCount = 0;
      scoreboardCount = 0;
      helpCount = 0;
    });

    test('W draws during draw phase', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyW),
        context: buildContext(),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.handled);
      expect(drawCount, 1);
    });

    test('Q unlocks discard when available', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyQ),
        context: buildContext(),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.handled);
      expect(unlockCount, 1);
    });

    test('E opens meld modal during meld phase', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyE),
        context: buildContext(turnPhase: TurnPhase.meld),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.handled);
      expect(meldCount, 1);
    });

    test('Space discards with one selected card and interaction guard', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.space),
        context: buildContext(turnPhase: TurnPhase.meld, selectedCardCount: 1),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.handled);
      expect(discardCount, 1);
    });

    test('Space ignores discard without interaction guard', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.space),
        context: buildContext(
          turnPhase: TurnPhase.meld,
          selectedCardCount: 1,
          hasInteractedSinceDraw: false,
        ),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.ignored);
      expect(discardCount, 0);
    });

    test('A and D navigate hand', () {
      handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyA),
        context: buildContext(),
        actions: buildActions(),
      );
      handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyD),
        context: buildContext(),
        actions: buildActions(),
      );

      expect(focusPreviousCount, 1);
      expect(focusNextCount, 1);
    });

    test('F toggles selection on focused card', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyF),
        context: buildContext(focusedCardIndex: 2),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.handled);
      expect(toggleSelectCount, 1);
    });

    test('C clears selection', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyC),
        context: buildContext(selectedCardCount: 2),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.handled);
      expect(clearCount, 1);
    });

    test('H toggles help overlay', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyH),
        context: buildContext(isHumanTurn: false),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.handled);
      expect(helpCount, 1);
    });

    test('ignores shortcuts during bot turn except help', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyW),
        context: buildContext(isHumanTurn: false),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.ignored);
      expect(drawCount, 0);
    });

    test('ignores shortcuts during animation', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.keyW),
        context: buildContext(isAnimating: true),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.ignored);
      expect(drawCount, 0);
    });

    test('Esc dismisses help overlay when visible', () {
      final result = handleGameKeyboardEvent(
        event: keyEvent(LogicalKeyboardKey.escape),
        context: buildContext(isHelpVisible: true),
        actions: buildActions(),
      );

      expect(result, KeyEventResult.handled);
      expect(helpCount, 1);
      expect(clearCount, 0);
    });
  });

  group('GameKeyboardShortcuts widget', () {
    testWidgets('invokes draw callback on W key press', (tester) async {
      var drawCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: GameKeyboardShortcuts(
            getContext: () => const GameKeyboardContext(
              turnPhase: TurnPhase.draw,
              canUnlockDiscard: false,
              selectedCardCount: 0,
              handLength: 3,
              focusedCardIndex: null,
              isHumanTurn: true,
              isAnimating: false,
              hasInteractedSinceDraw: true,
            ),
            actions: GameKeyboardActions(
              onDrawFromDeck: () => drawCount++,
              onUnlockDiscard: null,
              onOpenMeldModal: () {},
              onDiscard: () {},
              onClearSelection: () {},
              onSortHand: () {},
              onToggleSelectFocused: () {},
              onFocusPrevious: () {},
              onFocusNext: () {},
              onShowScoreboard: () {},
              onToggleHelp: () {},
            ),
            child: const SizedBox(),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      expect(drawCount, 1);
    });
  });
}
