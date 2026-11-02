import '../models/card.dart';
import 'bot_decision.dart';
import 'bot_strategic_memory.dart';
import 'planner/competitive_policy.dart';
import 'planner/legal_actions.dart';

/// How an Apple Intelligence seat asks the coded planner to lean.
///
/// There is no stall option. Postures only tighten play.
enum ApplePosture {
  raceGoOut,
  buildBooks,
  denyPile,
  holdKeys;

  static const double boost = 1.35;

  String get wireName {
    switch (this) {
      case ApplePosture.raceGoOut:
        return 'raceGoOut';
      case ApplePosture.buildBooks:
        return 'buildBooks';
      case ApplePosture.denyPile:
        return 'denyPile';
      case ApplePosture.holdKeys:
        return 'holdKeys';
    }
  }

  /// Accepts the wire name. Unknown values, including stall, are ignored.
  static ApplePosture? parse(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final cleaned = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    switch (cleaned) {
      case 'racegoout':
        return ApplePosture.raceGoOut;
      case 'buildbooks':
        return ApplePosture.buildBooks;
      case 'denypile':
        return ApplePosture.denyPile;
      case 'holdkeys':
        return ApplePosture.holdKeys;
      default:
        return null;
    }
  }

  /// Multiplies the personality weights this posture is allowed to raise.
  ScorerWeights adjust(ScorerWeights base) {
    switch (this) {
      case ApplePosture.raceGoOut:
        return base.scaled(goOut: boost, footTransition: boost);
      case ApplePosture.buildBooks:
        return base.scaled(bookProgress: boost, cleanBook: boost);
      case ApplePosture.denyPile:
        return base.scaled(takePile: boost, denial: boost);
      case ApplePosture.holdKeys:
        return base.scaled(keyHold: boost);
    }
  }
}

/// Ranks and weight bias for one Apple seat turn.
///
/// Applied on top of [TurnPlanner] hard constraints. A null posture leaves
/// the personality weights unchanged.
class AppleTurnBias {
  const AppleTurnBias({
    this.posture,
    this.holdRanks = const <CardRank>{},
    this.avoidFeedRanks = const <CardRank>{},
  });

  final ApplePosture? posture;
  final Set<CardRank> holdRanks;
  final Set<CardRank> avoidFeedRanks;

  ScorerWeights adjustWeights(ScorerWeights base) {
    final posture = this.posture;
    if (posture == null) {
      return base;
    }
    return posture.adjust(base);
  }
}

/// A legal candidate exposed to the on-device model with a stable id.
class LabeledLegalCandidate {
  const LabeledLegalCandidate({
    required this.id,
    required this.label,
    required this.kind,
    required this.decision,
  });

  final String id;
  final String label;
  final LegalActionKind kind;
  final BotDecision decision;

  Map<String, dynamic> toPromptJson() {
    return {'id': id, 'label': label, 'kind': kind.name};
  }
}

/// Structured turn plan returned by Foundation Models (or a test fake).
class BotTurnPlan {
  BotTurnPlan({
    required this.intent,
    this.posture,
    this.stepCandidateIds = const [],
    required this.thinkingAhead,
    required this.memoryUpdate,
  });

  final String intent;
  final ApplePosture? posture;

  /// Accepted from older native payloads and ignored when choosing an action.
  final List<String> stepCandidateIds;
  final List<String> thinkingAhead;
  final BotStrategicMemoryUpdate memoryUpdate;

  factory BotTurnPlan.empty() {
    return BotTurnPlan(
      intent: '',
      thinkingAhead: const [],
      memoryUpdate: const BotStrategicMemoryUpdate(),
    );
  }

  factory BotTurnPlan.fromJson(Map<String, dynamic> json) {
    final stepsRaw = json['stepCandidateIds'] ?? json['steps'];
    final steps = <String>[];
    if (stepsRaw is List) {
      for (final entry in stepsRaw) {
        if (entry is String) {
          steps.add(entry);
        } else if (entry is Map && entry['id'] != null) {
          steps.add(entry['id'].toString());
        }
      }
    }

    final thinking = <String>[];
    final thinkingRaw = json['thinkingAhead'];
    if (thinkingRaw is List) {
      thinking.addAll(thinkingRaw.map((e) => e.toString()));
    }

    // Memory fields may be nested under memoryUpdate or flat on the plan.
    final memoryJson = json['memoryUpdate'] is Map<String, dynamic>
        ? json['memoryUpdate'] as Map<String, dynamic>
        : <String, dynamic>{
            'goals': json['goals'],
            'holdRanks': json['holdRanks'],
            'safeDiscards': json['safeDiscards'],
            'plannedUnlock': json['plannedUnlock'],
            'opponentNotes': json['opponentNotes'],
            'lastTurnSummary': json['lastTurnSummary'],
            'thinkingAhead': json['thinkingAhead'],
            'avoidFeedRanks': json['avoidFeedRanks'],
            'posture': json['posture'],
          };

    return BotTurnPlan(
      intent: (json['intent'] as String?)?.trim() ?? '',
      posture: ApplePosture.parse(json['posture'] ?? memoryJson['posture']),
      stepCandidateIds: steps,
      thinkingAhead: thinking,
      memoryUpdate: BotStrategicMemoryUpdate.fromJson(memoryJson),
    );
  }
}

/// Active plan being walked during a bot turn.
class ActiveTurnPlan {
  ActiveTurnPlan({required this.plan, required this.candidatesById});

  final BotTurnPlan plan;
  final Map<String, LabeledLegalCandidate> candidatesById;
  int nextStepIndex = 0;

  /// Returns the next planned candidate whose kind is in [phaseKinds].
  ///
  /// Skips unknown/stale ids. Stops without consuming when the next known
  /// step belongs to a later phase.
  LabeledLegalCandidate? takeNextForPhase(Set<LegalActionKind> phaseKinds) {
    while (nextStepIndex < plan.stepCandidateIds.length) {
      final id = plan.stepCandidateIds[nextStepIndex];
      final candidate = candidatesById[id];
      if (candidate == null) {
        nextStepIndex++;
        continue;
      }
      if (phaseKinds.contains(candidate.kind)) {
        nextStepIndex++;
        return candidate;
      }
      if (_phaseOrder(candidate.kind) > _phaseOrderForKinds(phaseKinds)) {
        return null;
      }
      // Earlier-phase leftover — skip.
      nextStepIndex++;
    }
    return null;
  }

  static int _phaseOrder(LegalActionKind kind) {
    switch (kind) {
      case LegalActionKind.drawDeck:
      case LegalActionKind.drawDiscard:
        return 0;
      case LegalActionKind.playDown:
      case LegalActionKind.createMeld:
      case LegalActionKind.maximalBurst:
      case LegalActionKind.addToMeld:
      case LegalActionKind.noMeld:
      case LegalActionKind.goOut:
      case LegalActionKind.endTurn:
        return 1;
      case LegalActionKind.discard:
        return 2;
      case LegalActionKind.error:
        return 99;
    }
  }

  static int _phaseOrderForKinds(Set<LegalActionKind> kinds) {
    var minOrder = 99;
    for (final kind in kinds) {
      final order = _phaseOrder(kind);
      if (order < minOrder) {
        minOrder = order;
      }
    }
    return minOrder;
  }
}
