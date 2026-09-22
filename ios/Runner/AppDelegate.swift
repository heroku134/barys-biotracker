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
  private var pollTimer: Timer?

  private var currentBpm: Int = 0
  private var currentSteps: Int = 0
  private var currentCalories: Int = 0
  private var currentBattery: Int = 0
  private var currentHrv: Double = 0
  private var currentRhr: Int = 0
  private var currentSleepMinutes: Int = 0
  private var isOffWrist: Bool = false

  private var mgr: UTEBluetoothMgr { UTEBluetoothMgr.sharedInstance() }
  private var device: UTEDeviceMgr { mgr.mgrDevice }

  private func sdkOk(_ code: Int) -> Bool { code == 100000 }

  func initSdk() {
    mgr.initUTEMgr()
    mgr.delegate = self
  }

  func isBluetoothEnabled() -> Bool {
    return mgr.isOpenBluetooth
  }

  func startScan(result: @escaping FlutterResult) {
    discoveredDevices.removeAll()
    mgr.delegate = self
    mgr.isScanRepeat = true
    mgr.startScanDevices()
    result(true)
  }

  func stopScan(result: @escaping FlutterResult) {
    mgr.stopScanDevices()
    DispatchQueue.main.async { [weak self] in
      self?.scanSink?(["isScanComplete": true])
    }
    result(true)
  }

  func connect(address: String, result: @escaping FlutterResult) {
    var target = discoveredDevices[address]
    if target == nil {
      for dev in discoveredDevices.values {
        if deviceAddress(dev) == address || (dev.identifier ?? "") == address {
          target = dev
          break
        }
      }
    }
    guard let model = target else {
      result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device \(address) not found in scan results", details: nil))
      return
    }
    mgr.connect(model)
    result(true)
  }

  func disconnect(result: @escaping FlutterResult) {
    if let model = connectedModel {
      _ = mgr.disconnectDevices(model)
    }
    isConnected = false
    connectedModel = nil
    stopTelemetryPoll()
    currentBpm = 0
    currentHrv = 0
    currentRhr = 0
    currentSleepMinutes = 0
    pushTelemetry()
    result(true)
  }

  func findDevice(result: @escaping FlutterResult) {
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    device.setFindWearCmd(1) { _, _ in }
    result(true)
  }

  func measureHeartRate(result: @escaping FlutterResult) {
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    device.click(UTEMeasurementType.HRM) { _ in }
    result(true)
  }

  func syncTime(result: @escaping FlutterResult) {
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    let seconds = Int(Date().timeIntervalSince1970)
    let timeZone = TimeZone.current.secondsFromGMT() / 3600
    device.setTimeClock(seconds, timeZone: timeZone, minuteOffset: 0) { _, _ in }
    result(true)
  }

  func uteDiscoverDevices(_ model: UTEModelDevice?) {
    guard let model = model else { return }
    let name = model.name ?? "KALKAN СААТ-1"
    let addr = deviceAddress(model)
    discoveredDevices[addr] = model
    if let id = model.identifier {
      discoveredDevices[id] = model
    }
    DispatchQueue.main.async { [weak self] in
      self?.scanSink?([
        "name": name,
        "address": addr,
        "rssi": model.rssi
      ])
    }
  }

  func uteDevicesStatus(_ status: UTEDevicesStatus, error: Error?, userInfo info: [AnyHashable: Any]?) {
    if status.rawValue == 0 {
      isConnected = true
      connectedModel = mgr.connnectModel
      currentDeviceName = connectedModel?.name ?? "KALKAN СААТ-1"
      bindLiveStreams()
      pullNightAndDay()
      startTelemetryPoll()
      pushTelemetry()
    } else if status.rawValue == 1 || status.rawValue == -1 || status.rawValue == 3 {
      isConnected = false
      connectedModel = nil
      stopTelemetryPoll()
      currentBpm = 0
      pushTelemetry()
    }
  }

  private func bindLiveStreams() {
    device.setContinueMeasureHeartRateSwitch(true) { _, _ in }
    device.setAutoHeartRate(true) { _, _ in }

    device.onNotifyOneClickMeasurementBlock { [weak self] _, hrm, _, _ in
      guard let self = self, hrm > 0 else { return }
      self.currentBpm = Int(hrm)
      self.pushTelemetry()
    }

    device.onNotifyMeasurementBlock { [weak self] _, type, value in
      guard let self = self else { return }
      if type == UTEMeasurementType.HRM, value > 0 {
        self.currentBpm = Int(value)
      } else if type == UTEMeasurementType.HRV, value > 0 {
        self.currentHrv = Double(value)
      }
      self.pushTelemetry()
    }

    device.onNofityBattery { [weak self] battery, _ in
      guard let self = self, battery > 0 else { return }
      self.currentBattery = Int(battery)
      self.pushTelemetry()
    }

    device.onNotifyOffWristBlock { [weak self] _, _, state in
      guard let self = self else { return }
      self.isOffWrist = (state == 0)
      self.pushTelemetry()
    }

    device.click(UTEMeasurementType.HRV) { _ in }
  }

  private func pullNightAndDay() {
    let now = Int(Date().timeIntervalSince1970)
    let start = now - 36 * 3600
    device.getSciSleepModel(withStartTime: start, endTime: now) { [weak self] _, _, ok, code, _, dict in
      guard let self = self, self.sdkOk(Int(code)) || ok else { return }
      if let minutes = self.sleepMinutes(from: dict), minutes > 0 {
        self.currentSleepMinutes = minutes
        self.pushTelemetry()
      }
    }
    refreshWorkout()
  }

  private func refreshWorkout() {
    device.getBatteryInfo { [weak self] percent, code, _ in
      if self?.sdkOk(Int(code)) == true, percent > 0 {
        self?.currentBattery = Int(percent)
      }
    }
    device.getCurrentDayTotalWorkoutData { [weak self] todayModel, code, _ in
      guard let self = self, self.sdkOk(Int(code)), let model = todayModel else {
        self?.pushTelemetry()
        return
      }
      if model.totalCalorie > 0 { self.currentCalories = Int(model.totalCalorie) }
      if let last = model.lastHeartRate, last.rate > 0 { self.currentBpm = Int(last.rate) }
      if let items = model.motionData as? [UTEModelTodayDetail] {
        var steps = 0
        var sleep = 0
        for item in items {
          steps += Int(item.step)
          sleep += Int(item.sleepTime)
        }
        if steps > 0 { self.currentSteps = steps }
        if sleep > 0 { self.currentSleepMinutes = sleep }
      }
      self.pushTelemetry()
    }
  }

  private func startTelemetryPoll() {
    stopTelemetryPoll()
    DispatchQueue.main.async { [weak self] in
      self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
        self?.refreshWorkout()
      }
    }
  }

  private func stopTelemetryPoll() {
    pollTimer?.invalidate()
    pollTimer = nil
  }

  private func sleepMinutes(from dict: [AnyHashable: Any]?) -> Int? {
    guard let dict = dict else { return nil }
    var total = 0
    for (_, value) in dict {
      if let arr = value as? [Any] {
        for row in arr {
          if let map = row as? [AnyHashable: Any] {
            for key in ["sleepTime", "sleepMinutes", "duration", "totalSleep"] {
              if let n = map[key] as? NSNumber { total += n.intValue }
            }
          }
        }
      }
    }
    if total > 24 * 60 { total = total / 60 }
    return total > 0 ? total : nil
  }

  private func deviceAddress(_ model: UTEModelDevice) -> String {
    if let s = model.addressStr, !s.isEmpty { return s }
    if let s = model.identifier, !s.isEmpty { return s }
    return UUID().uuidString
  }

  private func pushTelemetry() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.telemetrySink?([
        "heartRate": self.currentBpm,
        "steps": self.currentSteps,
        "calories": self.currentCalories,
        "batteryLevel": self.currentBattery,
        "isConnected": self.isConnected,
        "deviceName": self.isConnected ? self.currentDeviceName : "СААТ-1",
        "hrv": self.currentHrv,
        "restingHeartRate": self.currentRhr,
        "sleepMinutes": self.currentSleepMinutes,
        "isOffWrist": self.isOffWrist
      ] as [String: Any])
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
    scanSink = sink
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
  func setScanSink(_ sink: FlutterEventSink?) { scanSink = sink }
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
        } else if call.method == "cancel" {
          let id = (call.arguments as? [String: Any])?["id"] as? Int ?? 0
          UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["kalkan_\(id)"])
          result(true)
        } else if call.method == "showNow" {
          guard let args = call.arguments as? [String: Any] else { result(false); return }
          let id = args["id"] as? Int ?? 1201
          let title = args["title"] as? String ?? ""
          let body = args["body"] as? String ?? ""
          let content = UNMutableNotificationContent()
          content.title = title
          content.body = body
          content.sound = .default
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.3, repeats: false)
          let req = UNNotificationRequest(identifier: "kalkan_now_\(id)", content: content, trigger: trigger)
          UNUserNotificationCenter.current().add(req)
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      let liveActivityChannel = FlutterMethodChannel(
        name: "sport.kalkan.biotracker/live_activity",
        binaryMessenger: controller.binaryMessenger
      )
      liveActivityChannel.setMethodCallHandler { (call, result) in
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
          switch call.method {
          case "startWorkoutActivity", "updateWorkoutActivity", "endWorkoutActivity":
            result(true)
          default:
            result(FlutterMethodNotImplemented)
          }
          return
        }
        #endif
        result(false)
      }

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
