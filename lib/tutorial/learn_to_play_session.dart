import '../ai/bot_personality.dart';
import '../config/solo_game_settings.dart';
import '../game/game_controller.dart';
import '../game/game_controller_factory.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/player.dart';

/// Builds a deterministic GameController and scripted hand for Learn to Play.
class LearnToPlaySession {
  static const int lessonSeed = 424242;

  static final SoloGameSettings lessonSettings = SoloGameSettings(
    botCount: 1,
    botPersonalities: const [BotPersonality.conservative],
    enableGoingOutBonus: true,
    enableFinalTurnAfterGoingOut: false,
  );

  final GameController controller;

  LearnToPlaySession._(this.controller);

  Player get human => controller.gameState.players.firstWhere(
    (p) => p.type == PlayerType.human,
    orElse: () => controller.gameState.players.first,
  );

  /// Creates a dealt lesson session ready at [TurnPhase.draw].
  static LearnToPlaySession create() {
    final players = lessonSettings.buildPlayers();
    final controller = GameControllerFactory.createSingleplayerGame(
      players: players,
      seed: lessonSeed,
      soloSettings: lessonSettings,
    );
    controller.autosaveEnabled = false;
    controller.initializeGame(dealCards: false);
    controller.completeRoundStart(earnedPerfectGrabBonus: false);

    final session = LearnToPlaySession._(controller);
    session.applyScriptedStartingHand();
    return session;
  }

  /// Keep the human as current player so GameScreen action UI stays interactive
  /// during coach/info steps after a discard advanced the turn.
  void keepHumanInControl() {
    final players = controller.gameState.players;
    final humanIndex = players.indexWhere((p) => p.type == PlayerType.human);
    if (humanIndex >= 0) {
      controller.gameState.currentPlayerIndex = humanIndex;
    }
  }

  /// Hand with 6 Kings (60 pts play-down) plus a junk discard before draw.
  void applyScriptedStartingHand() {
    final player = human;
    player.hand
      ..clear()
      ..addAll(_kingsForPlayDown())
      ..add(const PlayingCard(rank: CardRank.five, suit: Suit.clubs));
    player.foot
      ..clear()
      ..addAll(_footCards());
    player.sortHandByRank();
    controller.gameState.turnPhase = TurnPhase.draw;
    controller.gameState.hasDrawnFromDeck = false;
  }

  /// After the practice draw, restore a clean teachable hand for meld.
  void normalizeHandAfterDraw() {
    final player = human;
    player.hand
      ..clear()
      ..addAll(_kingsForPlayDown())
      ..add(const PlayingCard(rank: CardRank.five, suit: Suit.clubs));
    player.sortHandByRank();
  }

  /// Indices of the six Kings currently in hand (for auto-highlight).
  List<int> kingIndicesInHand() {
    final indices = <int>[];
    final hand = human.currentHand;
    for (var i = 0; i < hand.length; i++) {
      if (hand[i].rank == CardRank.king && !hand[i].isWild) {
        indices.add(i);
      }
    }
    return indices;
  }

  /// Index of the single non-King (discard target), or null.
  int? discardTargetIndex() {
    final hand = human.currentHand;
    for (var i = 0; i < hand.length; i++) {
      if (hand[i].rank != CardRank.king) {
        return i;
      }
    }
    if (hand.isNotEmpty) {
      return hand.length - 1;
    }
    return null;
  }

  static List<PlayingCard> _kingsForPlayDown() {
    return const [
      PlayingCard(rank: CardRank.king, suit: Suit.hearts),
      PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
      PlayingCard(rank: CardRank.king, suit: Suit.clubs),
      PlayingCard(rank: CardRank.king, suit: Suit.spades),
      PlayingCard(rank: CardRank.king, suit: Suit.hearts),
      PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
    ];
  }

  static List<PlayingCard> _footCards() {
    return const [
      PlayingCard(rank: CardRank.ace, suit: Suit.spades),
      PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
      PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
      PlayingCard(rank: CardRank.queen, suit: Suit.spades),
      PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
      PlayingCard(rank: CardRank.queen, suit: Suit.clubs),
      PlayingCard(rank: CardRank.jack, suit: Suit.spades),
      PlayingCard(rank: CardRank.jack, suit: Suit.hearts),
      PlayingCard(rank: CardRank.ten, suit: Suit.spades),
      PlayingCard(rank: CardRank.nine, suit: Suit.hearts),
      PlayingCard(rank: CardRank.eight, suit: Suit.clubs),
    ];
  }
}
