import Flutter
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Bridges Apple Foundation Models turn planning to Flutter via MethodChannel.
final class FoundationModelsBotService {
  static let channelName = "com.spurlockapp.handfootgame/foundation_models"

  private weak var channel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(availabilityPayload())
    case "planTurn":
      guard let prompt = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "planTurn requires a prompt map",
            details: nil
          )
        )
        return
      }
      Task {
        let plan = await self.planTurn(prompt: prompt)
        result(plan)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func availabilityPayload() -> [String: Any] {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      let model = SystemLanguageModel.default
      switch model.availability {
      case .available:
        return ["available": true, "reason": "available"]
      case .unavailable(.deviceNotEligible):
        return [
          "available": false,
          "reason": "This device does not support Apple Intelligence.",
        ]
      case .unavailable(.appleIntelligenceNotEnabled):
        return [
          "available": false,
          "reason": "Enable Apple Intelligence in Settings to use this opponent.",
        ]
      case .unavailable(.modelNotReady):
        return [
          "available": false,
          "reason": "Apple Intelligence model is not ready yet. Try again later.",
        ]
      case .unavailable(let other):
        return [
          "available": false,
          "reason": "Foundation Models unavailable (\(String(describing: other))).",
        ]
      }
    }
    #endif
    return [
      "available": false,
      "reason": "Requires iOS 26 or later with Apple Intelligence.",
    ]
  }

  private func planTurn(prompt: [String: Any]) async -> [String: Any]? {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      return await planTurnWithFoundationModels(prompt: prompt)
    }
    #endif
    return nil
  }

  #if canImport(FoundationModels)
  @available(iOS 26.0, *)
  private func planTurnWithFoundationModels(prompt: [String: Any]) async -> [String: Any]? {
    let model = SystemLanguageModel.default
    guard case .available = model.availability else {
      return nil
    }

    let instructions = """
    You are a Hand & Foot card-game strategist. Choose only candidate ids from \
    the provided list. Return a short intent, ordered stepCandidateIds for this \
    turn (draw then meld then discard), thinkingAhead contingencies, and memory \
    fields (goals, holdRanks, safeDiscards, plannedUnlock, opponentNotes, \
    lastTurnSummary). Prefer legal book progress and denying opponent unlocks.
    """

    let session = LanguageModelSession(model: model, instructions: instructions)
    let promptText = promptToText(prompt)

    do {
      let response = try await session.respond(
        to: promptText,
        generating: HandFootTurnPlan.self
      )
      return response.content.asDictionary()
    } catch {
      // Fallback: try unstructured JSON-ish generation is not available; fail open.
      NSLog("FoundationModelsBotService planTurn failed: \(error)")
      return nil
    }
  }
  #endif

  private func promptToText(_ prompt: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(
      withJSONObject: prompt,
      options: [.sortedKeys]
    ),
      let text = String(data: data, encoding: .utf8)
    else {
      return String(describing: prompt)
    }
    return text
  }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct HandFootTurnPlan {
  @Guide(description: "One or two sentences describing this turn's plan")
  var intent: String

  @Guide(description: "Ordered candidate ids to execute this turn")
  var stepCandidateIds: [String]

  @Guide(description: "One to three next-turn contingencies")
  var thinkingAhead: [String]

  @Guide(description: "Strategic goals to remember")
  var goals: [String]

  @Guide(description: "Card ranks to hold for unlocks or books")
  var holdRanks: [String]

  @Guide(description: "Card ranks that are safer to discard")
  var safeDiscards: [String]

  @Guide(description: "Planned unlock target and why")
  var plannedUnlock: String

  @Guide(description: "Visible opponent notes")
  var opponentNotes: [String]

  @Guide(description: "Brief summary of this turn for next prompt")
  var lastTurnSummary: String

  func asDictionary() -> [String: Any] {
    [
      "intent": intent,
      "stepCandidateIds": stepCandidateIds,
      "thinkingAhead": thinkingAhead,
      "goals": goals,
      "holdRanks": holdRanks,
      "safeDiscards": safeDiscards,
      "plannedUnlock": plannedUnlock,
      "opponentNotes": opponentNotes,
      "lastTurnSummary": lastTurnSummary,
    ]
  }
}
#endif
