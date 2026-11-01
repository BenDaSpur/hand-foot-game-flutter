import 'bot_decision.dart';
import 'bot_strategic_memory.dart';
import 'planner/legal_actions.dart';

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
    required this.stepCandidateIds,
    required this.thinkingAhead,
    required this.memoryUpdate,
  });

  final String intent;
  final List<String> stepCandidateIds;
  final List<String> thinkingAhead;
  final BotStrategicMemoryUpdate memoryUpdate;

  factory BotTurnPlan.empty() {
    return BotTurnPlan(
      intent: '',
      stepCandidateIds: const [],
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
          };

    return BotTurnPlan(
      intent: (json['intent'] as String?)?.trim() ?? '',
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
