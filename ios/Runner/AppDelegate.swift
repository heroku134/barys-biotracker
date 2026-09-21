import Flutter
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let liveActivityChannel = FlutterMethodChannel(
        name: "sport.kalkan.biotracker/live_activity",
        binaryMessenger: controller.binaryMessenger
      )
      
      liveActivityChannel.setMethodCallHandler { (call, result) in
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
          switch call.method {
          case "startWorkoutActivity":
            result(true)
          case "updateWorkoutActivity":
            result(true)
          case "endWorkoutActivity":
            result(true)
          default:
            result(FlutterMethodNotImplemented)
          }
          return
        }
        #endif
        result(false)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
