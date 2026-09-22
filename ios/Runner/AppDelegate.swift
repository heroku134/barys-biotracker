import Flutter
import UIKit
import UserNotifications
import BackgroundTasks
import CoreBluetooth

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(Darwin)
import Darwin
#endif

// MARK: - Swift Concurrency Runtime Compatibility Stub
// Resolves `_swift_coroFrameAlloc` missing symbol when linking with UTEBluetoothRYApi static framework.
@_cdecl("swift_coroFrameAlloc")
public func _kalkan_swift_coroFrameAlloc(_ size: Int, _ typeId: UInt64) -> UnsafeMutableRawPointer? {
  let allocSize = size == 0 ? 1 : size
  return malloc(allocSize)
}

#if canImport(UTEBluetoothRYApi)
import UTEBluetoothRYApi

class KalkanBleManager: NSObject, UTEBluetoothDelegate, FlutterStreamHandler {
  static let shared = KalkanBleManager()

  private var scanSink: FlutterEventSink?
  private var telemetrySink: FlutterEventSink?
  private var discoveredDevices: [String: UTEModelDevice] = [:]
  private var connectedModel: UTEModelDevice?
  private var isConnected = false
  private var currentDeviceName = "СААТ-1"

  private var currentBpm: Int = 72
  private var currentSteps: Int = 0
  private var currentCalories: Int = 0
  private var currentBattery: Int = 85
  private var pollTimer: Timer?

  func initSdk() {
    UTEBluetoothMgr.sharedInstance().initUTEMgr()
    UTEBluetoothMgr.sharedInstance().delegate = self
  }

  func isBluetoothEnabled() -> Bool {
    return UTEBluetoothMgr.sharedInstance().isOpenBluetooth
  }

  func startScan(result: @escaping FlutterResult) {
    discoveredDevices.removeAll()
    UTEBluetoothMgr.sharedInstance().delegate = self
    UTEBluetoothMgr.sharedInstance().isScanRepeat = false
    UTEBluetoothMgr.sharedInstance().startScanDevices()
    result(true)
  }

  func stopScan(result: @escaping FlutterResult) {
    UTEBluetoothMgr.sharedInstance().stopScanDevices()
    DispatchQueue.main.async { [weak self] in
      self?.scanSink?(["isScanComplete": true])
    }
    result(true)
  }

  func connect(address: String, result: @escaping FlutterResult) {
    var targetModel: UTEModelDevice? = discoveredDevices[address]
    if targetModel == nil {
      for dev in discoveredDevices.values {
        if dev.identifier == address || dev.advertisementAddress == address {
          targetModel = dev
          break
        }
      }
    }
    guard let model = targetModel else {
      result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device \(address) not found in scan results", details: nil))
      return
    }
    UTEBluetoothMgr.sharedInstance().connect(model)
    result(true)
  }

  func disconnect(result: @escaping FlutterResult) {
    if let model = connectedModel {
      _ = UTEBluetoothMgr.sharedInstance().disconnectDevices(model)
    }
    isConnected = false
    connectedModel = nil
    stopTelemetryPoll()
    pushTelemetry()
    result(true)
  }

  func findDevice(result: @escaping FlutterResult) {
    if isConnected {
      UTEDeviceMgr.sharedInstance().setFindWearCmd(1) { _, _ in }
      result(true)
    } else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
    }
  }

  func measureHeartRate(result: @escaping FlutterResult) {
    if isConnected {
      UTEDeviceMgr.sharedInstance().oneClickMeasurement { _ in }
      result(true)
    } else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
    }
  }

  func syncTime(result: @escaping FlutterResult) {
    if isConnected {
      let seconds = Int(Date().timeIntervalSince1970)
      let timeZone = TimeZone.current.secondsFromGMT() / 3600
      UTEDeviceMgr.sharedInstance().setTimeClock(seconds, timeZone: timeZone, minuteOffset: 0) { _, _ in }
      result(true)
    } else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
    }
  }

  // --- UTEBluetoothDelegate callbacks ---

  func uteDiscoverDevices(_ model: UTEModelDevice?) {
    guard let model = model else { return }
    let name = model.name ?? "KALKAN СААТ-1"
    let addr = model.advertisementAddress ?? model.identifier ?? UUID().uuidString
    discoveredDevices[addr] = model
    if let id = model.identifier {
      discoveredDevices[id] = model
    }

    let dict: [String: Any] = [
      "name": name,
      "address": addr,
      "rssi": model.rssi
    ]
    DispatchQueue.main.async { [weak self] in
      self?.scanSink?(dict)
    }
  }

  func uteDevicesStatus(_ status: UTEDevicesStatus, error: Error?, userInfo info: [AnyHashable : Any]?) {
    if status.rawValue == 0 { // UTEDevicesStatusConnected
      isConnected = true
      connectedModel = UTEBluetoothMgr.sharedInstance().connnectModel
      currentDeviceName = connectedModel?.name ?? "KALKAN СААТ-1"

      UTEDeviceMgr.sharedInstance().setContinueMeasureHeartRateSwitch(true) { _, _ in }
      UTEDeviceMgr.sharedInstance().setAutoHeartRate(true) { _, _ in }

      UTEDeviceMgr.sharedInstance().onNotifyCurrentData { [weak self] item in
        guard let self = self, let item = item else { return }
        if item.dynamicHeartRate > 0 {
          self.currentBpm = item.dynamicHeartRate
        } else if item.restingHeartRate > 0 {
          self.currentBpm = item.restingHeartRate
        }
        if item.step > 0 {
          self.currentSteps = item.step
        }
        if item.calorie > 0 {
          self.currentCalories = item.calorie
        }
        self.pushTelemetry()
      }

      UTEDeviceMgr.sharedInstance().onNotifyOneClickMeasurementBlock { [weak self] _, hrm, _, _ in
        guard let self = self else { return }
        if hrm > 0 {
          self.currentBpm = hrm
          self.pushTelemetry()
        }
      }

      UTEDeviceMgr.sharedInstance().onNofityBattery { [weak self] battery, _ in
        guard let self = self else { return }
        if battery > 0 {
          self.currentBattery = battery
          self.pushTelemetry()
        }
      }

      startTelemetryPoll()
      pushTelemetry()
    } else if status.rawValue == 1 || status.rawValue == -1 || status.rawValue == 3 {
      // Disconnected, check fail, timeout
      isConnected = false
      connectedModel = nil
      stopTelemetryPoll()
      pushTelemetry()
    }
  }

  private func startTelemetryPoll() {
    stopTelemetryPoll()
    DispatchQueue.main.async { [weak self] in
      self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        guard let self = self, self.isConnected else { return }
        UTEDeviceMgr.sharedInstance().getBatteryInfo { [weak self] percent, errorCode, _ in
          if errorCode == 0 && percent > 0 {
            self?.currentBattery = percent
          }
        }
        UTEDeviceMgr.sharedInstance().getCurrentDayTotalWorkoutData { [weak self] todayModel, errorCode, _ in
          if errorCode == 0, let model = todayModel {
            if model.totalCalorie > 0 {
              self?.currentCalories = model.totalCalorie
            }
            if let last = model.lastHeartRate, last.rate > 0 {
              self?.currentBpm = last.rate
            }
          }
          self?.pushTelemetry()
        }
      }
    }
  }

  private func stopTelemetryPoll() {
    pollTimer?.invalidate()
    pollTimer = nil
  }

  private func pushTelemetry() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let telemetry: [String: Any] = [
        "heartRate": self.currentBpm,
        "steps": self.currentSteps,
        "calories": self.currentCalories,
        "batteryLevel": self.currentBattery,
        "isConnected": self.isConnected,
        "deviceName": self.isConnected ? self.currentDeviceName : "СААТ-1"
      ]
      self.telemetrySink?(telemetry)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    telemetrySink = events
    pushTelemetry()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    telemetrySink = nil
    return nil
  }

  func setScanSink(_ sink: FlutterEventSink?) {
    self.scanSink = sink
  }
}

#else

class KalkanBleManager: NSObject, FlutterStreamHandler {
  static let shared = KalkanBleManager()
  private var scanSink: FlutterEventSink?
  private var telemetrySink: FlutterEventSink?

  func initSdk() {}
  func isBluetoothEnabled() -> Bool { return true }
  func startScan(result: @escaping FlutterResult) { result(true) }
  func stopScan(result: @escaping FlutterResult) { result(true) }
  func connect(address: String, result: @escaping FlutterResult) { result(true) }
  func disconnect(result: @escaping FlutterResult) { result(true) }
  func findDevice(result: @escaping FlutterResult) { result(true) }
  func measureHeartRate(result: @escaping FlutterResult) { result(true) }
  func syncTime(result: @escaping FlutterResult) { result(true) }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    telemetrySink = events
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    telemetrySink = nil
    return nil
  }
  func setScanSink(_ sink: FlutterEventSink?) {
    self.scanSink = sink
  }
}

#endif

class KalkanScanStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    KalkanBleManager.shared.setScanSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    KalkanBleManager.shared.setScanSink(nil)
    return nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "sport.kalkan.bio.refresh", using: nil) { task in
      let request = BGAppRefreshTaskRequest(identifier: "sport.kalkan.bio.refresh")
      request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
      try? BGTaskScheduler.shared.submit(request)
      task.setTaskCompleted(success: true)
    }

    if let controller = controller {
      // 1. Background refresh channel
      let bgChannel = FlutterMethodChannel(
        name: "sport.kalkan.biotracker/background",
        binaryMessenger: controller.binaryMessenger
      )
      bgChannel.setMethodCallHandler { call, result in
        if call.method == "scheduleRefresh" {
          let request = BGAppRefreshTaskRequest(identifier: "sport.kalkan.bio.refresh")
          request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
          do {
            try BGTaskScheduler.shared.submit(request)
            result(true)
          } catch {
            result(false)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      // 2. Notification channel
      let notifyChannel = FlutterMethodChannel(
        name: "sport.kalkan.biotracker/notify",
        binaryMessenger: controller.binaryMessenger
      )
      notifyChannel.setMethodCallHandler { call, result in
        if call.method == "requestPermission" {
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { result(ok) }
          }
        } else if call.method == "scheduleDaily" {
          guard let args = call.arguments as? [String: Any] else { result(false); return }
          let id = args["id"] as? Int ?? 1
          let hour = args["hour"] as? Int ?? 7
          let minute = args["minute"] as? Int ?? 0
          let title = args["title"] as? String ?? ""
          let body = args["body"] as? String ?? ""
          let content = UNMutableNotificationContent()
          content.title = title
          content.body = body
          var date = DateComponents()
          date.hour = hour
          date.minute = minute
          let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
          let req = UNNotificationRequest(identifier: "kalkan_\(id)", content: content, trigger: trigger)
          UNUserNotificationCenter.current().add(req)
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      // 3. Live Activities & Dynamic Island channel
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

      // 4. Native BLE Watch SDK Channels (Method, Scan, Telemetry)
      KalkanBleManager.shared.initSdk()

      let bleMethodChannel = FlutterMethodChannel(
        name: "com.nadal.ble/methods",
        binaryMessenger: controller.binaryMessenger
      )
      bleMethodChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "isBluetoothEnabled":
          result(KalkanBleManager.shared.isBluetoothEnabled())
        case "checkPermissions", "requestPermissions":
          result(true)
        case "startScan":
          KalkanBleManager.shared.startScan(result: result)
        case "stopScan":
          KalkanBleManager.shared.stopScan(result: result)
        case "connect":
          let address = (call.arguments as? [String: Any])?["address"] as? String ?? ""
          KalkanBleManager.shared.connect(address: address, result: result)
        case "disconnect":
          KalkanBleManager.shared.disconnect(result: result)
        case "findDevice":
          KalkanBleManager.shared.findDevice(result: result)
        case "measureHeartRate":
          KalkanBleManager.shared.measureHeartRate(result: result)
        case "syncTime":
          KalkanBleManager.shared.syncTime(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let bleScanChannel = FlutterEventChannel(
        name: "com.nadal.ble/scan",
        binaryMessenger: controller.binaryMessenger
      )
      bleScanChannel.setStreamHandler(KalkanScanStreamHandler())

      let bleTelemetryChannel = FlutterEventChannel(
        name: "com.nadal.ble/telemetry",
        binaryMessenger: controller.binaryMessenger
      )
      bleTelemetryChannel.setStreamHandler(KalkanBleManager.shared)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
