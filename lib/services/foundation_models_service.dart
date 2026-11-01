import 'foundation_models_service_stub.dart'
    if (dart.library.io) 'foundation_models_service_io.dart'
    as fm_impl;

/// Availability snapshot for Apple Foundation Models.
class FoundationModelsAvailability {
  const FoundationModelsAvailability({
    required this.available,
    required this.reason,
  });

  final bool available;
  final String reason;
}

/// Dart facade for on-device Apple Foundation Models turn planning.
abstract class FoundationModelsService {
  static FoundationModelsService? _instance;

  static FoundationModelsService get instance =>
      _instance ??= fm_impl.createFoundationModelsService();

  static set instance(FoundationModelsService value) => _instance = value;

  static void debugReset() {
    _instance = null;
  }

  Future<FoundationModelsAvailability> checkAvailability();

  /// Returns a JSON map matching [BotTurnPlan.fromJson], or null on failure.
  Future<Map<String, dynamic>?> planTurn(Map<String, dynamic> prompt);
}
