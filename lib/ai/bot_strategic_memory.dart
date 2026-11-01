import '../models/card.dart';

/// Compact multi-turn memory for an Apple Intelligence (or similar) bot seat.
///
/// Kept in Dart and re-injected into each turn prompt so we do not rely on an
/// unbounded native session transcript.
class BotStrategicMemory {
  BotStrategicMemory({
    List<String>? goals,
    List<String>? holdRanks,
    List<String>? safeDiscards,
    this.plannedUnlock = '',
    List<String>? opponentNotes,
    this.lastTurnSummary = '',
    List<String>? thinkingAhead,
    this.updatedAtRound = 0,
    this.updatedAtTurn = 0,
  }) : goals = List<String>.from(goals ?? const []),
       holdRanks = List<String>.from(holdRanks ?? const []),
       safeDiscards = List<String>.from(safeDiscards ?? const []),
       opponentNotes = List<String>.from(opponentNotes ?? const []),
       thinkingAhead = List<String>.from(thinkingAhead ?? const []);

  final List<String> goals;
  final List<String> holdRanks;
  final List<String> safeDiscards;
  String plannedUnlock;
  final List<String> opponentNotes;
  String lastTurnSummary;
  final List<String> thinkingAhead;
  int updatedAtRound;
  int updatedAtTurn;

  BotStrategicMemory copy() {
    return BotStrategicMemory(
      goals: goals,
      holdRanks: holdRanks,
      safeDiscards: safeDiscards,
      plannedUnlock: plannedUnlock,
      opponentNotes: opponentNotes,
      lastTurnSummary: lastTurnSummary,
      thinkingAhead: thinkingAhead,
      updatedAtRound: updatedAtRound,
      updatedAtTurn: updatedAtTurn,
    );
  }

  /// Merge a model-produced patch. Empty lists/strings leave existing values.
  void mergeUpdate(BotStrategicMemoryUpdate update) {
    if (update.goals != null && update.goals!.isNotEmpty) {
      goals
        ..clear()
        ..addAll(update.goals!.take(5));
    }
    if (update.holdRanks != null && update.holdRanks!.isNotEmpty) {
      holdRanks
        ..clear()
        ..addAll(_normalizeRanks(update.holdRanks!));
    }
    if (update.safeDiscards != null && update.safeDiscards!.isNotEmpty) {
      safeDiscards
        ..clear()
        ..addAll(_normalizeRanks(update.safeDiscards!));
    }
    if (update.plannedUnlock != null &&
        update.plannedUnlock!.trim().isNotEmpty) {
      plannedUnlock = update.plannedUnlock!.trim();
    }
    if (update.opponentNotes != null && update.opponentNotes!.isNotEmpty) {
      opponentNotes
        ..clear()
        ..addAll(update.opponentNotes!.take(5));
    }
    if (update.lastTurnSummary != null &&
        update.lastTurnSummary!.trim().isNotEmpty) {
      lastTurnSummary = update.lastTurnSummary!.trim();
    }
    if (update.thinkingAhead != null && update.thinkingAhead!.isNotEmpty) {
      thinkingAhead
        ..clear()
        ..addAll(update.thinkingAhead!.take(3));
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'goals': goals,
      'holdRanks': holdRanks,
      'safeDiscards': safeDiscards,
      'plannedUnlock': plannedUnlock,
      'opponentNotes': opponentNotes,
      'lastTurnSummary': lastTurnSummary,
      'thinkingAhead': thinkingAhead,
      'updatedAtRound': updatedAtRound,
      'updatedAtTurn': updatedAtTurn,
    };
  }

  factory BotStrategicMemory.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return BotStrategicMemory();
    }
    return BotStrategicMemory(
      goals: _stringList(json['goals']),
      holdRanks: _stringList(json['holdRanks']),
      safeDiscards: _stringList(json['safeDiscards']),
      plannedUnlock: json['plannedUnlock'] as String? ?? '',
      opponentNotes: _stringList(json['opponentNotes']),
      lastTurnSummary: json['lastTurnSummary'] as String? ?? '',
      thinkingAhead: _stringList(json['thinkingAhead']),
      updatedAtRound: json['updatedAtRound'] as int? ?? 0,
      updatedAtTurn: json['updatedAtTurn'] as int? ?? 0,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return [];
    }
    return value.map((e) => e.toString()).toList();
  }

  static List<String> _normalizeRanks(List<String> raw) {
    final out = <String>[];
    for (final entry in raw) {
      final normalized = _matchRankName(entry);
      if (normalized != null && !out.contains(normalized)) {
        out.add(normalized);
      }
    }
    return out.take(8).toList();
  }

  static String? _matchRankName(String raw) {
    final cleaned = raw.trim().toLowerCase();
    if (cleaned.isEmpty) {
      return null;
    }
    for (final rank in CardRank.values) {
      if (rank.name.toLowerCase() == cleaned) {
        return rank.name;
      }
    }
    // Common short forms
    const aliases = {
      'a': 'ace',
      'j': 'jack',
      'q': 'queen',
      'k': 'king',
      '2': 'two',
      '3': 'three',
      '4': 'four',
      '5': 'five',
      '6': 'six',
      '7': 'seven',
      '8': 'eight',
      '9': 'nine',
      '10': 'ten',
      'joker': 'joker',
    };
    final alias = aliases[cleaned];
    return alias;
  }
}

/// Patch produced by a turn plan; null fields mean "leave unchanged".
class BotStrategicMemoryUpdate {
  const BotStrategicMemoryUpdate({
    this.goals,
    this.holdRanks,
    this.safeDiscards,
    this.plannedUnlock,
    this.opponentNotes,
    this.lastTurnSummary,
    this.thinkingAhead,
  });

  final List<String>? goals;
  final List<String>? holdRanks;
  final List<String>? safeDiscards;
  final String? plannedUnlock;
  final List<String>? opponentNotes;
  final String? lastTurnSummary;
  final List<String>? thinkingAhead;

  factory BotStrategicMemoryUpdate.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const BotStrategicMemoryUpdate();
    }
    return BotStrategicMemoryUpdate(
      goals: _optionalStringList(json['goals']),
      holdRanks: _optionalStringList(json['holdRanks']),
      safeDiscards: _optionalStringList(json['safeDiscards']),
      plannedUnlock: json['plannedUnlock'] as String?,
      opponentNotes: _optionalStringList(json['opponentNotes']),
      lastTurnSummary: json['lastTurnSummary'] as String?,
      thinkingAhead: _optionalStringList(json['thinkingAhead']),
    );
  }

  static List<String>? _optionalStringList(dynamic value) {
    if (value is! List) {
      return null;
    }
    return value.map((e) => e.toString()).toList();
  }
}

/// In-memory store keyed by bot player id.
class BotStrategicMemoryStore {
  final Map<String, BotStrategicMemory> _byPlayer = {};

  BotStrategicMemory forPlayer(String playerId) {
    return _byPlayer.putIfAbsent(playerId, BotStrategicMemory.new);
  }

  void clear() {
    _byPlayer.clear();
  }

  void clearPlayer(String playerId) {
    _byPlayer.remove(playerId);
  }
}
