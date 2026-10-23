import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    StrideLocationPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "StrideLocationPlugin")!)
    registerStorageChannel(engineBridge.pluginRegistry.registrar(forPlugin: "StrideStorage")!)
  }

  /// Keeps the local run database (full GPS history) out of iCloud backups;
  /// signed-in users already have it in their own account via sync.
  private func registerStorageChannel(_ registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "stride/storage", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      var url = URL(fileURLWithPath: path)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        result(true)
      } catch {
        result(FlutterError(code: "exclude_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
