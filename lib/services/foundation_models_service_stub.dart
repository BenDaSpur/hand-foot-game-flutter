import 'foundation_models_service.dart';

FoundationModelsService createFoundationModelsService() {
  return StubFoundationModelsService();
}

/// Always-unavailable implementation for web/tests/non-Apple platforms.
class StubFoundationModelsService implements FoundationModelsService {
  @override
  Future<FoundationModelsAvailability> checkAvailability() async {
    return const FoundationModelsAvailability(
      available: false,
      reason:
          'Apple Foundation Models are only available on iOS 26+ with '
          'Apple Intelligence enabled.',
    );
  }

  @override
  Future<Map<String, dynamic>?> planTurn(Map<String, dynamic> prompt) async {
    return null;
  }
}
