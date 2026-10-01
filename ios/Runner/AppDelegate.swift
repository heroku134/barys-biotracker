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
  private var batteryCharacteristic: CBCharacteristic?
  private var alertCharacteristic: CBCharacteristic?
  private var writeCharacteristic: CBCharacteristic?

  private var currentBpm: Int = 0
  private var currentSteps: Int = 0
  private var currentCalories: Int = 0
  private var currentBattery: Int = 0
  private var isCharging: Bool = false
  private var currentHrv: Double = 0
  private var currentRhr: Int = 0
  private var currentSleepMinutes: Int = 0
  private var isOffWrist: Bool = false

  func initSdk() {
    if centralManager == nil {
      centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    #if canImport(UTEBluetoothRYApi)
    if centralManager?.state == .poweredOn {
      mgr.initUTEMgr()
      mgr.delegate = self
    }
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
    #else
    if centralManager == nil {
      centralManager = CBCentralManager(delegate: self, queue: .main)
    } else if centralManager?.state == .poweredOn {
      centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    #endif

    result(true)
  }

  func stopScan(result: @escaping FlutterResult) {
    isScanning = false
    #if canImport(UTEBluetoothRYApi)
    mgr.stopScanDevices()
    #else
    centralManager?.stopScan()
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
    isCharging = false
    pollTimer?.invalidate()
    pollTimer = nil
    batteryCharacteristic = nil
    alertCharacteristic = nil
    writeCharacteristic = nil
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
    guard isConnected, let peripheral = connectedPeripheral else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    if let alertChar = alertCharacteristic {
      peripheral.writeValue(Data([0x02]), for: alertChar, type: .withoutResponse)
    }
    if let writeChar = writeCharacteristic {
      let findPacket = Data([0xAB, 0x00, 0x04, 0xFF, 0x70, 0x01])
      let writeType: CBCharacteristicWriteType = writeChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
      peripheral.writeValue(findPacket, for: writeChar, type: writeType)
      peripheral.writeValue(Data([0x01]), for: writeChar, type: writeType)
    }
    result(true)
    #endif
  }

  func measureHeartRate(result: @escaping FlutterResult) {
    #if canImport(UTEBluetoothRYApi)
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    device.oneClickMeasurement { _ in }
    result(true)
    #else
    guard isConnected, let peripheral = connectedPeripheral else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    if let writeChar = writeCharacteristic {
      let measurePacket = Data([0xAB, 0x00, 0x04, 0xFF, 0x31, 0x01])
      let writeType: CBCharacteristicWriteType = writeChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
      peripheral.writeValue(measurePacket, for: writeChar, type: writeType)
    }
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
      #if canImport(UTEBluetoothRYApi)
      mgr.initUTEMgr()
      mgr.delegate = self
      #endif
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
    guard !cleanName.isEmpty else { return }

    #if canImport(UTEBluetoothRYApi)
    let lower = cleanName.lowercased()
    guard lower.contains("саат") || lower.contains("saat") || lower.contains("kalkan") || lower.contains("ute") || lower.contains("smart") || lower.contains("watch") || lower.contains("nadal") else {
      return
    }
    #endif

    let address = peripheral.identifier.uuidString
    discoveredPeripherals[address] = peripheral

    DispatchQueue.main.async { [weak self] in
      self?.scanSink?([
        "name": cleanName,
        "address": address,
        "rssi": RSSI.intValue
      ])
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    isConnected = true
    currentDeviceName = peripheral.name ?? "СААТ-1"
    peripheral.discoverServices(nil)
    pushTelemetry()
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    isConnected = false
    pushTelemetry()
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    isConnected = false
    connectedPeripheral = nil
    batteryCharacteristic = nil
    alertCharacteristic = nil
    writeCharacteristic = nil
    isCharging = false
    pollTimer?.invalidate()
    pollTimer = nil
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
      let uuid = c.uuid.uuidString.uppercased()

      // Heart Rate Measurement: 0x2A37
      if uuid == "2A37" {
        peripheral.setNotifyValue(true, for: c)
      }
      // Battery Level: 0x2A19
      else if uuid == "2A19" {
        self.batteryCharacteristic = c
        peripheral.readValue(for: c)
        peripheral.setNotifyValue(true, for: c)
      }
      // Immediate Alert: 0x2A06
      else if uuid == "2A06" {
        self.alertCharacteristic = c
      }

      // JieLi / UTE Vendor Write: 0xAE01 or any writable characteristic
      if c.properties.contains(.write) || c.properties.contains(.writeWithoutResponse) {
        if self.writeCharacteristic == nil || uuid == "AE01" {
          self.writeCharacteristic = c
        }
      }

      // JieLi / UTE Vendor Notify: 0xAE02 or any notify
      if uuid == "AE02" || c.properties.contains(.notify) || c.properties.contains(.indicate) {
        peripheral.setNotifyValue(true, for: c)
      }

      // Read readable characteristics (except standard stream)
      if c.properties.contains(.read) && uuid != "2A37" {
        peripheral.readValue(for: c)
      }
    }

    // Handshake: Send initial time sync, battery query, and continuous HR enable packet
    if let wChar = self.writeCharacteristic {
      let writeType: CBCharacteristicWriteType = wChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
      let now = Date()
      let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
      let y = comps.year ?? 2026
      let m = comps.month ?? 1
      let d = comps.day ?? 1
      let h = comps.hour ?? 12
      let min = comps.minute ?? 0
      let s = comps.second ?? 0
      let timePacket = Data([0xAB, 0x00, 0x08, 0xFF, 0x01, UInt8((y >> 8) & 0xFF), UInt8(y & 0xFF), UInt8(m), UInt8(d), UInt8(h), UInt8(min), UInt8(s)])
      peripheral.writeValue(timePacket, for: wChar, type: writeType)

      let batPacket = Data([0xAB, 0x00, 0x04, 0xFF, 0x70, 0x01])
      peripheral.writeValue(batPacket, for: wChar, type: writeType)

      let hrPacket = Data([0xAB, 0x00, 0x04, 0xFF, 0x31, 0x01])
      peripheral.writeValue(hrPacket, for: wChar, type: writeType)
    }

    // Start background poll timer for battery refresh if not already active
    if pollTimer == nil && isConnected {
      pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self, weak peripheral] _ in
        guard let self = self, let p = peripheral, self.isConnected else { return }
        if let bChar = self.batteryCharacteristic {
          p.readValue(for: bChar)
        }
        if let wChar = self.writeCharacteristic {
          let writeType: CBCharacteristicWriteType = wChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
          let batPacket = Data([0xAB, 0x00, 0x04, 0xFF, 0x70, 0x01])
          p.writeValue(batPacket, for: wChar, type: writeType)
          let stepPacket = Data([0xAB, 0x00, 0x04, 0xFF, 0x07, 0x01])
          p.writeValue(stepPacket, for: wChar, type: writeType)
        }
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let data = characteristic.value, !data.isEmpty else { return }
    let uuid = characteristic.uuid.uuidString.uppercased()

    if uuid == "2A37" {
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
    } else if uuid == "2A19" || characteristic == batteryCharacteristic {
      let bat = Int(data[0])
      if bat >= 0 && bat <= 100 {
        currentBattery = bat
      }
      if data.count >= 2 {
        isCharging = (data[1] == 1)
      }
      pushTelemetry()
    } else {
      // Vendor frame parsing (e.g. JieLi / UTE packet starting with 0xAB)
      if data[0] == 0xAB && data.count >= 5 {
        let cmd = data[4]
        // Battery report (0x70 or 0x08)
        if cmd == 0x70 || cmd == 0x08 {
          if data.count >= 6 {
            let bat = Int(data[5])
            if bat >= 0 && bat <= 100 {
              currentBattery = bat
            }
          }
          if data.count >= 7 {
            isCharging = (data[6] == 1)
          }
          pushTelemetry()
        }
        // Heart rate report (0x31 or 0x09)
        else if cmd == 0x31 || cmd == 0x09 {
          if data.count >= 6 {
            let hr = Int(data[5])
            if hr >= 30 && hr <= 240 {
              currentBpm = hr
              pushTelemetry()
            }
          }
        }
        // Steps report (0x07 or 0x51 or 0x52)
        else if (cmd == 0x07 || cmd == 0x51 || cmd == 0x52) && data.count >= 8 {
          let steps = (Int(data[5]) << 16) | (Int(data[6]) << 8) | Int(data[7])
          if steps > 0 && steps < 200000 {
            currentSteps = steps
            pushTelemetry()
          }
        }
      }
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
        "isCharging": self.isCharging,
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
      if percent > 0 && percent <= 100 {
        self?.currentBattery = Int(percent)
        self?.pushTelemetry()
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

    // Live continuous heart rate stream
    device.onNotifyHRMReal { [weak self] model, _ in
      guard let self = self, let m = model, m.heartRate > 0 else { return }
      self.currentBpm = Int(m.heartRate)
      self.pushTelemetry()
    }

    // One-click measurement notification
    device.onNotifyOneClickMeasurementBlock { [weak self] _, hrm, _, _ in
      guard let self = self, hrm > 0 else { return }
      self.currentBpm = Int(hrm)
      self.pushTelemetry()
    }

    // Live battery notifications
    device.onNofityBattery { [weak self] bat, _ in
      guard let self = self, bat > 0 else { return }
      self.currentBattery = Int(bat)
      self.pushTelemetry()
    }

    device.onNofityBatteryModel { [weak self] bModel in
      guard let self = self, let bModel = bModel else { return }
      if bModel.battery > 0 { self.currentBattery = Int(bModel.battery) }
      self.isCharging = (bModel.status == 1)
      self.pushTelemetry()
    }

    device.onNotifyMeasurementBlock { [weak self] _, type, value in
      guard let self = self else { return }
      if type == .HRV && value > 0 {
        self.currentHrv = Double(value)
        self.pushTelemetry()
      }
    }

    device.clickMeasurementType(.HRM) { _ in }
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

      // Handshake: query supported services
      device.querySupportService([1, 5, 12, 14, 17]) { _ in }

      // Sync time
      let now = Int(Date().timeIntervalSince1970)
      let timeZone = TimeZone.current.secondsFromGMT() / 3600
      device.setTimeClock(now, timeZone: timeZone, minuteOffset: 0) { _, _ in }

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
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "sport.kalkan.bio.refresh", using: nil) { task in
      let request = BGAppRefreshTaskRequest(identifier: "sport.kalkan.bio.refresh")
      request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
      try? BGTaskScheduler.shared.submit(request)
      task.setTaskCompleted(success: true)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KalkanNative") {
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
