import '../config/game_config.dart';
import '../game/game_controller.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/meld.dart';
import '../models/player.dart';
import 'bot_decision.dart';
import 'bot_meld_analyzer.dart';
import 'bot_strategic_memory.dart';
import 'planner/competitive_policy.dart';

/// Compact prompt payload for the on-device posture advisor.
///
/// The coded planner still chooses the action. This brief gives the model
/// the position, the expert move, and the memory it wrote last turn.
class AppleSituationBrief {
  static const List<String> rules = [
    'Play down before any other meld. This round needs the listed points.',
    'Wilds (2s and jokers) cannot outnumber natural cards in a meld.',
    '3s cannot be melded.',
    'Unlocking the discard pile needs 2 natural cards matching the top and a play-down already made.',
    'Going out needs one clean book (no wilds) and one dirty book (with wilds).',
  ];

  static Map<String, dynamic> build({
    required Player bot,
    required GameController controller,
    required BotStrategicMemory memory,
    required BotDecision expert,
    required BotMeldAnalyzer meldAnalyzer,
  }) {
    final state = controller.gameState;
    final hand = bot.currentHand;
    var wildCount = 0;
    var threeCount = 0;
    for (final card in hand) {
      if (card.isWild) {
        wildCount++;
      }
      if (card.isThree) {
        threeCount++;
      }
    }

    final recent = state.discardPile.length <= 6
        ? state.discardPile.map((card) => card.compactName).toList()
        : state.discardPile
              .sublist(state.discardPile.length - 6)
              .map((card) => card.compactName)
              .toList();

    final opponents = state.players
        .where((player) => player.id != bot.id)
        .map(
          (player) => {
            'name': player.name,
            'isHuman': player.type == PlayerType.human,
            'handSize': player.currentHand.length,
            'footSize': player.foot.length,
            'hasPlayedDown': player.hasPlayedDown,
            'hasPickedUpFoot': player.hasPickedUpFoot,
            'bookCount': player.bookCount,
            'score': player.score,
            'melds': player.melds.map(describeMeld).toList(),
          },
        )
        .toList(growable: false);

    return {
      'instructions':
          'You advise a Hand & Foot bot. Do not pick cards or candidate ids. '
          'The coded planner plays the move and will not skip a forced take, '
          'play-down, or hand-pile empty. Return posture (raceGoOut, '
          'buildBooks, denyPile, or holdKeys), holdRanks, avoidFeedRanks, '
          'and a short intent. Match the expert action. Never stall.',
      'postureOptions': const [
        'raceGoOut',
        'buildBooks',
        'denyPile',
        'holdKeys',
      ],
      'rules': rules,
      'game': {
        'round': state.round,
        'phase': state.turnPhase.name,
        'playDownRequirement': state.playDownRequirement,
        'deckSize': state.deck.size,
      },
      'discard': {
        'top': state.topDiscard?.compactName,
        'size': state.discardPile.length,
        'frozen': state.discardPileFrozen,
        'threeCount': state.discardPile.where((card) => card.isThree).length,
        'canUnlock': state.canUnlockDiscard(),
        'humanCanUnlock': CompetitivePolicy.humanLikelyCanUnlock(state, bot.id),
        'recent': recent,
      },
      'self': {
        'name': bot.name,
        'pile': bot.hasPickedUpFoot ? 'foot' : 'hand',
        'handCounts': rankCounts(hand),
        'wildCount': wildCount,
        'threeCount': threeCount,
        'hasPlayedDown': bot.hasPlayedDown,
        'hasPickedUpFoot': bot.hasPickedUpFoot,
        'footSize': bot.foot.length,
        'score': bot.score,
        'bookCount': bot.bookCount,
        'booksMissing': missingBooks(bot),
        'melds': bot.melds.map(describeMeld).toList(),
        'playDown': _playDownGap(
          bot: bot,
          controller: controller,
          meldAnalyzer: meldAnalyzer,
        ),
      },
      'opponents': opponents,
      'expert': {
        'action': expert.action,
        'reason': describeExpertAction(
          decision: expert,
          bot: bot,
          state: state,
        ),
      },
      'memory': memory.toJson(),
    };
  }

  static String rankCounts(List<PlayingCard> cards) {
    if (cards.isEmpty) {
      return 'empty';
    }
    final counts = <CardRank, int>{};
    for (final card in cards) {
      counts[card.rank] = (counts[card.rank] ?? 0) + 1;
    }
    return CardRank.values
        .where(counts.containsKey)
        .map((rank) => '${rank.name}×${counts[rank]}')
        .join(', ');
  }

  static String describeMeld(Meld meld) {
    final lane = meld.cards.any((card) => card.isWild) ? 'dirty' : 'clean';
    final remaining = GameConfig.bookSize - meld.cards.length;
    final progress = remaining <= 0 ? 'book' : '$remaining to book';
    return '${meld.rank.name} ${meld.cards.length}/${GameConfig.bookSize} '
        '$lane, $progress';
  }

  static String missingBooks(Player bot) {
    final missing = <String>[
      if (!bot.hasCleanBook) 'clean',
      if (!bot.hasDirtyBook) 'dirty',
    ];
    if (missing.isEmpty) {
      return 'none';
    }
    return missing.join(' and ');
  }

  static String describeExpertAction({
    required BotDecision decision,
    required Player bot,
    required GameState state,
  }) {
    switch (decision.action) {
      case 'drawFromDiscard':
        {
          final top = state.topDiscard?.compactName ?? 'the top card';
          final size = state.discardPile.length;
          if (CompetitivePolicy.humanLikelyCanUnlock(state, bot.id)) {
            return 'Take the $size-card pile ($top) before an opponent unlocks it.';
          }
          return 'Take the $size-card pile headed by $top.';
        }
      case 'drawFromDeck':
        {
          return 'Draw from the deck. Taking the pile is not the expert play.';
        }
      case 'createMeld':
      case 'createMultipleMelds':
        {
          if (!bot.hasPlayedDown) {
            return 'Play down now. A legal meld meets the '
                '${state.playDownRequirement}-point requirement.';
          }
          return 'Meld toward a book. Do not stall.';
        }
      case 'addToMeld':
        {
          return 'Add a card onto an existing meld toward a book.';
        }
      case 'noMeld':
        {
          return 'No meld. No forced play-down or hand-pile empty is available.';
        }
      case 'discard':
        {
          final data = decision.data;
          if (data is PlayingCard) {
            return 'Discard ${data.compactName}. It is the least costly legal pitch.';
          }
          return 'Discard the planner pick.';
        }
      case 'goOut':
        {
          return 'Go out. Clean and dirty books are finished.';
        }
      case 'endTurn':
        {
          return 'End the turn without emptying the foot before going out.';
        }
      default:
        {
          return 'Follow the coded planner (${decision.action}).';
        }
    }
  }

  static Map<String, dynamic>? _playDownGap({
    required Player bot,
    required GameController controller,
    required BotMeldAnalyzer meldAnalyzer,
  }) {
    if (bot.hasPlayedDown) {
      return null;
    }
    final requirement = controller.gameState.playDownRequirement;
    final combo = meldAnalyzer.findBestPlayDownCombination(
      bot,
      controller,
      requirement,
    );
    final available = meldAnalyzer.calculateTotalMeldValue(combo);
    final gap = requirement - available;
    return {
      'requirement': requirement,
      'bestMeldPoints': available,
      'gap': gap > 0 ? gap : 0,
      'canPlayDown': combo.isNotEmpty && available >= requirement,
    };
  }
}
