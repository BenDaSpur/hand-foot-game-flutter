import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let foundationModelsBotService = FoundationModelsBotService()
  private var adsWindowChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    foundationModelsBotService.register(
      with: engineBridge.applicationRegistrar.messenger()
    )
    let channel = FlutterMethodChannel(
      name: "com.handfoot/ads_window",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "bindSceneWindow" {
        self?.bindForegroundSceneWindow()
        result(nil)
        return
      }
      result(FlutterMethodNotImplemented)
    }
    adsWindowChannel = channel
  }

  /// google_mobile_ads presents from `delegate.window`, which the scene
  /// embed never assigns. Prefer the Flutter view's window so a Duo
  /// interstitial is asked to cover the full-bleed canvas.
  private func bindForegroundSceneWindow() {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    guard let scene else {
      return
    }
    let windows = scene.windows
    let flutterWindow = windows.first { $0.rootViewController is FlutterViewController }
      ?? windows.max { lhs, rhs in
        lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
      }
    if let flutterWindow {
      window = flutterWindow
    }
  }
}
