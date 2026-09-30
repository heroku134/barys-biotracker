import Flutter
import UIKit
import UserNotifications
import BackgroundTasks
import CoreBluetooth

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(UTEBluetoothRYApi)
import UTEBluetoothRYApi
#endif

class KalkanBleManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, FlutterStreamHandler {
  static let shared = KalkanBleManager()

  private var centralManager: CBCentralManager?
  private var scanSink: FlutterEventSink?
  private var telemetrySink: FlutterEventSink?

  private var isScanning = false
  private var discoveredPeripherals: [String: CBPeripheral] = [:]
  private var connectedPeripheral: CBPeripheral?

  #if canImport(UTEBluetoothRYApi)
  private var discoveredUteDevices: [String: UTEModelDevice] = [:]
  private var connectedModel: UTEModelDevice?
  private var mgr: UTEBluetoothMgr { UTEBluetoothMgr.sharedInstance() }
  private var device: UTEDeviceMgr { mgr.mgrDevice }
  private func sdkOk(_ code: Int) -> Bool { code == 100000 }
  #endif

  private var isConnected = false
  private var currentDeviceName = ""
  private var pollTimer: Timer?

  private var currentBpm: Int = 0
  private var currentSteps: Int = 0
  private var currentCalories: Int = 0
  private var currentBattery: Int = 0
  private var currentHrv: Double = 0
  private var currentRhr: Int = 0
  private var currentSleepMinutes: Int = 0
  private var isOffWrist: Bool = false

  func initSdk() {
    if centralManager == nil {
      centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    #if canImport(UTEBluetoothRYApi)
    mgr.initUTEMgr()
    mgr.delegate = self
    #endif
  }

  func isBluetoothEnabled() -> Bool {
    if let cm = centralManager {
      return cm.state != .poweredOff && cm.state != .unauthorized && cm.state != .unsupported
    }
    #if canImport(UTEBluetoothRYApi)
    return mgr.isOpenBluetooth
    #else
    return true
    #endif
  }

  func checkPermissions() -> Bool {
    if #available(iOS 13.1, *) {
      return CBCentralManager.authorization == .allowedAlways
    } else {
      return true
    }
  }

  func requestPermissions(result: @escaping FlutterResult) {
    if centralManager == nil {
      centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    result(true)
  }

  func startScan(result: @escaping FlutterResult) {
    isScanning = true
    discoveredPeripherals.removeAll()
    #if canImport(UTEBluetoothRYApi)
    discoveredUteDevices.removeAll()
    mgr.delegate = self
    mgr.isScanRepeat = true
    mgr.startScanDevices()
    #endif

    if centralManager == nil {
      centralManager = CBCentralManager(delegate: self, queue: .main)
    } else if centralManager?.state == .poweredOn {
      centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    result(true)
  }

  func stopScan(result: @escaping FlutterResult) {
    isScanning = false
    centralManager?.stopScan()
    #if canImport(UTEBluetoothRYApi)
    mgr.stopScanDevices()
    #endif

    DispatchQueue.main.async { [weak self] in
      self?.scanSink?(["isScanComplete": true])
    }
    result(true)
  }

  func connect(address: String, result: @escaping FlutterResult) {
    #if canImport(UTEBluetoothRYApi)
    var targetUte: UTEModelDevice? = discoveredUteDevices[address]
    if targetUte == nil {
      for dev in discoveredUteDevices.values {
        if deviceAddress(dev) == address || (dev.identifier ?? "") == address {
          targetUte = dev
          break
        }
      }
    }
    if let model = targetUte {
      mgr.connectDevice(model)
      result(true)
      return
    }
    #endif

    if let peripheral = discoveredPeripherals[address] {
      connectedPeripheral = peripheral
      peripheral.delegate = self
      centralManager?.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
      result(true)
      return
    }

    result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device \(address) not found in scan results", details: nil))
  }

  func disconnect(result: @escaping FlutterResult) {
    #if canImport(UTEBluetoothRYApi)
    if let model = connectedModel {
      _ = mgr.disconnectDevices(model)
    }
    connectedModel = nil
    #endif

    if let peripheral = connectedPeripheral {
      centralManager?.cancelPeripheralConnection(peripheral)
      connectedPeripheral = nil
    }

    isConnected = false
    stopTelemetryPoll()
    currentBpm = 0
    currentBattery = 0
    currentSteps = 0
    currentCalories = 0
    currentHrv = 0
    currentRhr = 0
    currentSleepMinutes = 0
    currentDeviceName = ""
    pushTelemetry()
    result(true)
  }

  func findDevice(result: @escaping FlutterResult) {
    #if canImport(UTEBluetoothRYApi)
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    device.setFindWearCmd(1) { _, _ in }
    result(true)
    #else
    result(true)
    #endif
  }

  func measureHeartRate(result: @escaping FlutterResult) {
    #if canImport(UTEBluetoothRYApi)
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    device.click(UTEMeasurementType.HRM) { _ in }
    result(true)
    #else
    result(true)
    #endif
  }

  func syncTime(result: @escaping FlutterResult) {
    #if canImport(UTEBluetoothRYApi)
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    let seconds = Int(Date().timeIntervalSince1970)
    let timeZone = TimeZone.current.secondsFromGMT() / 3600
    device.setTimeClock(seconds, timeZone: timeZone, minuteOffset: 0) { _, _ in }
    result(true)
    #else
    result(true)
    #endif
  }

  // MARK: - CBCentralManagerDelegate

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      if isScanning {
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
      }
    case .poweredOff, .unsupported, .unauthorized, .resetting:
      if isConnected {
        isConnected = false
        pushTelemetry()
      }
    @unknown default:
      break
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    let rawName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
    let cleanName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    let address = peripheral.identifier.uuidString

    discoveredPeripherals[address] = peripheral

    let displayName: String
    if !cleanName.isEmpty {
      displayName = cleanName
    } else if RSSI.intValue > -85 {
      displayName = "СААТ-1 (\(address.prefix(4)))"
    } else {
      return
    }

    DispatchQueue.main.async { [weak self] in
      self?.scanSink?([
        "name": displayName,
        "address": address,
        "rssi": RSSI.intValue
      ])
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    isConnected = true
    currentDeviceName = peripheral.name ?? "СААТ-1"
    peripheral.discoverServices([
      CBUUID(string: "180D"),
      CBUUID(string: "180F"),
      CBUUID(string: "180A")
    ])
    pushTelemetry()
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    isConnected = false
    pushTelemetry()
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    isConnected = false
    connectedPeripheral = nil
    currentBpm = 0
    currentBattery = 0
    currentSteps = 0
    currentCalories = 0
    currentHrv = 0
    currentRhr = 0
    currentSleepMinutes = 0
    currentDeviceName = ""
    pushTelemetry()
  }

  // MARK: - CBPeripheralDelegate

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    for s in services {
      peripheral.discoverCharacteristics(nil, for: s)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let chars = service.characteristics else { return }
    for c in chars {
      if c.uuid == CBUUID(string: "2A37") {
        peripheral.setNotifyValue(true, for: c)
      } else if c.uuid == CBUUID(string: "2A19") {
        peripheral.readValue(for: c)
        peripheral.setNotifyValue(true, for: c)
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let data = characteristic.value, !data.isEmpty else { return }
    if characteristic.uuid == CBUUID(string: "2A37") {
      let flags = data[0]
      let is16Bit = (flags & 0x01) != 0
      let bpm: Int
      if is16Bit && data.count >= 3 {
        bpm = Int(data[1]) | (Int(data[2]) << 8)
      } else if data.count >= 2 {
        bpm = Int(data[1])
      } else {
        bpm = 0
      }
      if bpm > 0 {
        currentBpm = bpm
        pushTelemetry()
      }
    } else if characteristic.uuid == CBUUID(string: "2A19") {
      currentBattery = Int(data[0])
      pushTelemetry()
    }
  }

  // MARK: - Telemetry Push & FlutterStreamHandler

  private func pushTelemetry() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.telemetrySink?([
        "heartRate": self.currentBpm,
        "steps": self.currentSteps,
        "calories": self.currentCalories,
        "batteryLevel": self.currentBattery,
        "isConnected": self.isConnected,
        "deviceName": self.isConnected ? self.currentDeviceName : "",
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

  #if canImport(UTEBluetoothRYApi)
  // MARK: - UTE SDK Integration
  private func deviceAddress(_ model: UTEModelDevice) -> String {
    if let s = model.addressStr, !s.isEmpty { return s }
    if let s = model.identifier, !s.isEmpty { return s }
    return UUID().uuidString
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

  private func bindLiveStreams() {
    device.setContinueMeasureHeartRateSwitch(true) { _, _ in }
    device.setAutoHeartRate(true) { _, _ in }

    device.onNotifyOneClickMeasurementBlock { [weak self] _, hrm, _, _ in
      guard let self = self, hrm > 0 else { return }
      self.currentBpm = Int(hrm)
      self.pushTelemetry()
    }

    device.onNotifyHRVDataBlock { [weak self] _, hrv, rhr, _, _ in
      guard let self = self else { return }
      if hrv > 0 { self.currentHrv = Double(hrv) }
      if rhr > 0 { self.currentRhr = Int(rhr) }
      self.pushTelemetry()
    }

    device.click(UTEMeasurementType.HRV) { _ in }
  }
  #else
  private func stopTelemetryPoll() {
    pollTimer?.invalidate()
    pollTimer = nil
  }
  #endif
}

#if canImport(UTEBluetoothRYApi)
extension KalkanBleManager: UTEBluetoothDelegate {
  func uteDiscoverDevices(_ model: UTEModelDevice?) {
    guard let model = model else { return }
    let name = model.name ?? "KALKAN СААТ-1"
    let addr = deviceAddress(model)
    discoveredUteDevices[addr] = model
    if let id = model.identifier {
      discoveredUteDevices[id] = model
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
      currentBattery = 0
      currentSteps = 0
      currentCalories = 0
      currentHrv = 0
      currentRhr = 0
      currentSleepMinutes = 0
      currentDeviceName = ""
      pushTelemetry()
    }
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
  private var didSetupChannels = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    BGTaskScheduler.shared.register(forTaskWithIdentifier: "sport.kalkan.bio.refresh", using: nil) { task in
      let request = BGAppRefreshTaskRequest(identifier: "sport.kalkan.bio.refresh")
      request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
      try? BGTaskScheduler.shared.submit(request)
      task.setTaskCompleted(success: true)
    }

    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      setupChannels(messenger: controller.binaryMessenger)
    }

    return ok
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KalkanBlePlugin") {
      setupChannels(messenger: registrar.messenger())
    }
  }

  func setupChannels(messenger: FlutterBinaryMessenger) {
    guard !didSetupChannels else { return }
    didSetupChannels = true

    KalkanBleManager.shared.initSdk()

    let bgChannel = FlutterMethodChannel(
      name: "sport.kalkan.biotracker/background",
      binaryMessenger: messenger
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
      binaryMessenger: messenger
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

    let iconChannel = FlutterMethodChannel(
      name: "sport.kalkan.biotracker/icon",
      binaryMessenger: messenger
    )
    iconChannel.setMethodCallHandler { call, result in
      if call.method == "setIcon" {
        let name = (call.arguments as? [String: Any])?["name"] as? String
        if UIApplication.shared.supportsAlternateIcons {
          UIApplication.shared.setAlternateIconName(name) { err in
            result(err == nil)
          }
        } else {
          result(false)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let liveActivityChannel = FlutterMethodChannel(
      name: "sport.kalkan.biotracker/live_activity",
      binaryMessenger: messenger
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

    let bleMethodChannel = FlutterMethodChannel(
      name: "com.nadal.ble/methods",
      binaryMessenger: messenger
    )
    bleMethodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "isBluetoothEnabled":
        result(KalkanBleManager.shared.isBluetoothEnabled())
      case "checkPermissions":
        result(KalkanBleManager.shared.checkPermissions())
      case "requestPermissions":
        KalkanBleManager.shared.requestPermissions(result: result)
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
      binaryMessenger: messenger
    )
    bleScanChannel.setStreamHandler(KalkanScanStreamHandler())

    let bleTelemetryChannel = FlutterEventChannel(
      name: "com.nadal.ble/telemetry",
      binaryMessenger: messenger
    )
    bleTelemetryChannel.setStreamHandler(KalkanBleManager.shared)
  }
}
