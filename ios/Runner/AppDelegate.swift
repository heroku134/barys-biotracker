import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {

  private let methodChannelName = "com.nadal.ble/methods"
  private let eventChannelName = "com.nadal.ble/telemetry"

  private var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController

    // 1. MethodChannel для команд с Flutter
    let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: controller.binaryMessenger)
    methodChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "startScan":
        // Запуск BLE-сканирования через UTEBluetoothMgr
        result(true)
      case "stopScan":
        result(true)
      case "connect":
        result(true)
      case "disconnect":
        self?.pushTelemetry(connected: false)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // 2. EventChannel для передачи телеметрии в Flutter
    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: controller.binaryMessenger)
    eventChannel.setStreamHandler(self)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - FlutterStreamHandler
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    pushTelemetry(connected: true)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  private func pushTelemetry(connected: Bool) {
    let telemetry: [String: Any] = [
      "heartRate": 72,
      "steps": 7200,
      "calories": 440,
      "batteryLevel": 88,
      "hrv": 66.0,
      "sleepMinutes": 450,
      "deepSleepMinutes": 110,
      "isConnected": connected,
      "deviceName": "UTE Barys Watch Pro"
    ]
    eventSink?(telemetry)
  }
}
