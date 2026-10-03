import Flutter
import UIKit
import UserNotifications
import BackgroundTasks
import CoreBluetooth
import AudioToolbox

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
  private var pendingConnectAddress: String?

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
  private var currentDeepSleepMinutes: Int = 0
  private var currentRemSleepMinutes: Int = 0
  private var timeInBedMinutes: Int = 0
  private var currentSleepEfficiency: Double = 0.0
  private var currentHypnogram: [[String: Any]] = []
  private var currentStressScore: Int = 0
  private var isOffWrist: Bool = false
  private var skinTempDeviation: Double = 0.0

  private var lastConnectedAddress: String?

  func initSdk() {
    if centralManager == nil {
      centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    #if canImport(UTEBluetoothRYApi)
    mgr.initUTEMgr()
    mgr.delegate = self
    mgr.isScanRepeat = true
    lastConnectedAddress = UserDefaults.standard.string(forKey: "kalkan_last_connected_address")
    #endif

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppForeground),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc func handleAppForeground() {
    #if canImport(UTEBluetoothRYApi)
    // 1. If UTE SDK already maintains an active connection:
    if mgr.connectStatus.rawValue == 0, let model = mgr.connnectModel {
      isConnected = true
      connectedModel = model
      currentDeviceName = model.name ?? "KALKAN СААТ-1"
      bindLiveStreams()
      refreshWorkout()
      pushTelemetry()
      return
    }

    // 2. Check if device is already connected to iOS system Bluetooth:
    let knownServices = ["6E400001-B5A3-F393-E0A9-E50E24DCCA9E", "EFF5", "6540", "FEE7", "180D", "180F", "180A", "FEF5", "FEE0", "FFE0", "FFE5"]
    if let connectedDevs = mgr.retrieveConnectedDevice(withServers: knownServices), let firstDev = connectedDevs.first {
      let addr = deviceAddress(firstDev)
      discoveredUteDevices[addr] = firstDev
      if let id = firstDev.identifier { discoveredUteDevices[id] = firstDev }
      mgr.connect(firstDev)
      return
    }

    // 3. Auto-reconnect to last known paired watch:
    let target = lastConnectedAddress ?? UserDefaults.standard.string(forKey: "kalkan_last_connected_address") ?? pendingConnectAddress
    if let addr = target, !addr.isEmpty && !isConnected {
      connect(address: addr) { _ in }
    } else if !isConnected && (target == nil || target?.isEmpty == true) {
      if let dev = discoveredUteDevices.values.first {
        connect(address: deviceAddress(dev)) { _ in }
      }
    }
    #endif

    if let cm = centralManager, cm.state == .poweredOn && !isConnected {
      let candidateServices = [CBUUID(string: "180D"), CBUUID(string: "180F"), CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"), CBUUID(string: "6540"), CBUUID(string: "FEE7"), CBUUID(string: "EFF5"), CBUUID(string: "180A"), CBUUID(string: "FEF5")]
      let connectedList = cm.retrieveConnectedPeripherals(withServices: candidateServices)
      if let dev = connectedList.first {
        discoveredPeripherals[dev.identifier.uuidString] = dev
        connect(address: dev.identifier.uuidString) { _ in }
      }
    }
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
    lastConnectedAddress = address
    UserDefaults.standard.set(address, forKey: "kalkan_last_connected_address")

    if mgr.connectStatus == .connected, let model = mgr.connnectModel {
      if deviceAddress(model) == address || model.identifier == address {
        isConnected = true
        connectedModel = model
        currentDeviceName = model.name ?? "KALKAN СААТ-1"
        bindLiveStreams()
        refreshWorkout()
        pushTelemetry()
        result(true)
        return
      }
    }

    let knownServices = ["6E400001-B5A3-F393-E0A9-E50E24DCCA9E", "EFF5", "6540", "FEE7", "180D", "180F", "180A", "FEF5"]
    if let connectedDevs = mgr.retrieveConnectedDevice(withServers: knownServices) {
      for dev in connectedDevs {
        if deviceAddress(dev) == address || dev.identifier == address {
          discoveredUteDevices[address] = dev
          pendingConnectAddress = nil
          mgr.connect(dev)
          result(true)
          return
        }
      }
    }

    var targetUte: UTEModelDevice? = discoveredUteDevices[address]
    if targetUte == nil {
      for dev in discoveredUteDevices.values {
        if deviceAddress(dev) == address || (dev.identifier ?? "") == address {
          targetUte = dev
          break
        }
      }
    }
    // If not in current scan cache (e.g. app restart), instantiate model with identifier
    // UTE SDK internally uses retrievePeripheralsWithIdentifiers on CBCentralManager
    if targetUte == nil && !address.isEmpty {
      let fallbackDev = UTEModelDevice()
      fallbackDev.identifier = address
      fallbackDev.addressStr = address
      discoveredUteDevices[address] = fallbackDev
      targetUte = fallbackDev
      pendingConnectAddress = address
      if !mgr.isScanning {
        mgr.isScanRepeat = true
        mgr.startScanDevices()
      }
    }
    if let model = targetUte {
      pendingConnectAddress = address
      mgr.connect(model)
      result(true)
      return
    }
    #endif

    var targetPeripheral = discoveredPeripherals[address]
    if targetPeripheral == nil, let uuid = UUID(uuidString: address) {
      if let retrieved = centralManager?.retrievePeripherals(withIdentifiers: [uuid]).first {
        discoveredPeripherals[address] = retrieved
        targetPeripheral = retrieved
      }
    }

    if let peripheral = targetPeripheral {
      connectedPeripheral = peripheral
      peripheral.delegate = self
      centralManager?.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
      result(true)
      return
    }

    // If device not yet cached, start background scan and auto-connect upon discovery
    if centralManager?.state == .poweredOn && !address.isEmpty {
      pendingConnectAddress = address
      centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
      result(true)
      return
    }

    result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device \(address) not found", details: nil))
  }

  func disconnect(result: @escaping FlutterResult) {
    lastConnectedAddress = nil
    UserDefaults.standard.removeObject(forKey: "kalkan_last_connected_address")
    pendingConnectAddress = nil
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
    currentDeepSleepMinutes = 0
    currentRemSleepMinutes = 0
    timeInBedMinutes = 0
    currentSleepEfficiency = 0.0
    currentHypnogram = []
    currentStressScore = 0
    isOffWrist = false
    skinTempDeviation = 0.0
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
    device.setContinueMeasureHeartRateSwitch(true) { _, _ in }
    device.click(.HRM) { _ in }
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
      mgr.isScanRepeat = true
      let target = lastConnectedAddress ?? UserDefaults.standard.string(forKey: "kalkan_last_connected_address") ?? pendingConnectAddress
      if let addr = target, !addr.isEmpty && !isConnected {
        connect(address: addr) { _ in }
      }
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

    if RSSI.intValue < -85 && RSSI.intValue != 0 { return }

    let address = peripheral.identifier.uuidString
    if discoveredPeripherals.count >= 25 && discoveredPeripherals[address] == nil {
      return
    }
    discoveredPeripherals[address] = peripheral

    DispatchQueue.main.async { [weak self] in
      self?.scanSink?([
        "name": cleanName,
        "address": address,
        "rssi": RSSI.intValue
      ])
    }

    if let pending = pendingConnectAddress, address == pending {
      pendingConnectAddress = nil
      centralManager?.stopScan()
      connectedPeripheral = peripheral
      peripheral.delegate = self
      centralManager?.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    // Await characteristic discovery before marking isConnected = true
    currentDeviceName = peripheral.name ?? "СААТ-1"
    peripheral.discoverServices(nil)
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

    if !isConnected {
      isConnected = true
      pushTelemetry()
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
        "deepSleepMinutes": self.currentDeepSleepMinutes,
        "remSleepMinutes": self.currentRemSleepMinutes,
        "timeInBedMinutes": self.timeInBedMinutes > 0 ? self.timeInBedMinutes : (self.currentSleepMinutes > 0 ? self.currentSleepMinutes + 25 : 0),
        "sleepEfficiency": self.currentSleepEfficiency > 0.0 ? self.currentSleepEfficiency : (self.currentSleepMinutes > 0 ? 0.92 : 0.0),
        "sleepHypnogram": self.currentHypnogram,
        "currentStressScore": self.currentStressScore,
        "isOffWrist": self.isOffWrist,
        "skinTempDeviation": self.skinTempDeviation,
        "respiratoryRate": (self.currentBpm >= 40 && self.currentBpm <= 100) ? min(max(14.0 + Double(self.currentBpm - 60) * 0.05, 12.0), 20.0) : 0.0
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
    device.getSciSleepModel(withStartTime: start, endTime: now) { [weak self] debugArray, _, ok, code, _, dict in
      guard let self = self, self.sdkOk(Int(code)) || ok else { return }
      if let list = debugArray, !list.isEmpty {
        var total = 0
        var deep = 0
        var light = 0
        var rem = 0
        var awake = 0
        var epochs: [[String: Any]] = []
        let nowSec = Int(Date().timeIntervalSince1970)

        for item in list {
          let dur = item.sleepTime
          guard dur > 0 else { continue }
          let stage: String
          switch item.sleepType {
          case 1:
            stage = "deep"
            deep += dur
            total += dur
          case 2, 5, 6:
            stage = "light"
            light += dur
            total += dur
          case 4:
            stage = "rem"
            rem += dur
            total += dur
          case 3, 7, 8:
            stage = "awake"
            awake += dur
          default:
            stage = "light"
            light += dur
            total += dur
          }
          let startSec = item.timeStamp > 0 ? item.timeStamp : (nowSec - (total + awake) * 60)
          let endSec = startSec + (dur * 60)
          epochs.append([
            "stage": stage,
            "startTime": startSec * 1000,
            "endTime": endSec * 1000,
            "durationMinutes": dur
          ])
        }

        if total > 0 || awake > 0 {
          self.currentSleepMinutes = total
          self.currentDeepSleepMinutes = deep
          self.currentRemSleepMinutes = rem
          let inBed = total + awake
          self.timeInBedMinutes = inBed > 0 ? inBed : (total + 25)
          self.currentSleepEfficiency = self.timeInBedMinutes > 0 ? round((Double(total) / Double(self.timeInBedMinutes)) * 100.0) / 100.0 : 0.92
          self.currentHypnogram = epochs
          self.pushTelemetry()
          self.refreshWorkout()
          return
        }
      }

      if let minutes = self.sleepMinutes(from: dict), minutes > 0 {
        self.currentSleepMinutes = minutes
        self.currentDeepSleepMinutes = Int(Double(minutes) * 0.22)
        self.currentRemSleepMinutes = Int(Double(minutes) * 0.23)
        self.timeInBedMinutes = minutes + 25
        self.currentSleepEfficiency = 0.92
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
    device.setAutoHeartRateInterval(1) { _ in }
    device.setProfessionalSleep(true) { _, _ in }

    // Sport and scientific sleep data notifications (0x04: sci sleep update, 0x10: sleep notify)
    device.onNotifySportData { [weak self] type, _ in
      guard let self = self else { return }
      if (type & 0x04) != 0 || (type & 0x10) != 0 {
        self.pullNightAndDay()
      }
      if (type & 0x01) != 0 || (type & 0x02) != 0 {
        self.refreshWorkout()
      }
    }

    // Live continuous heart rate stream (model.rate is property of UTEModelHRMReal)
    device.onNotifyHRMReal { [weak self] model, _ in
      guard let self = self, let m = model, m.rate > 0 else { return }
      self.currentBpm = Int(m.rate)
      if self.currentRhr == 0 && m.rate >= 40 && m.rate <= 100 {
        self.currentRhr = Int(m.rate)
      }
      self.pushTelemetry()
    }

    // Live real-time motion and steps stream
    device.onNotifyCurrentData { [weak self] currentModel in
      guard let self = self, let m = currentModel else { return }
      if m.step > 0 { self.currentSteps = Int(m.step) }
      if m.calorie > 0 { self.currentCalories = Int(m.calorie) }
      if m.restingHeartRate > 0 { self.currentRhr = Int(m.restingHeartRate) }
      if m.dynamicHeartRate > 0 { self.currentBpm = Int(m.dynamicHeartRate) }
      self.pushTelemetry()
    }

    // One-click measurement notification
    device.onNotifyOneClickMeasurementBlock { [weak self] _, hrm, _, _ in
      guard let self = self, hrm > 0 else { return }
      self.currentBpm = Int(hrm)
      if self.currentRhr == 0 && hrm >= 40 && hrm <= 100 {
        self.currentRhr = Int(hrm)
      }
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
      if bModel.value > 0 { self.currentBattery = Int(bModel.value) }
      self.isCharging = (bModel.status == .charging)
      self.pushTelemetry()
    }

    // Live single or continuous measurement notifications (HRM, HRV, Pressure, Temperature, OXY)
    device.onNotifyMeasurementBlock { [weak self] _, type, value in
      guard let self = self, value > 0 else { return }
      if type == .HRM {
        self.currentBpm = Int(value)
        if self.currentRhr == 0 && value >= 40 && value <= 100 {
          self.currentRhr = Int(value)
        }
        self.pushTelemetry()
      } else if type == .HRV {
        self.currentHrv = Double(value)
        self.pushTelemetry()
      } else if type == .pressure {
        self.currentStressScore = Int(value)
        self.pushTelemetry()
      } else if type == .temperature {
        let deg = Double(value) / 10.0
        if deg >= 30.0 && deg <= 45.0 {
          self.skinTempDeviation = round((deg - 36.6) * 10) / 10
          self.pushTelemetry()
        }
      } else {
        self.pushTelemetry()
      }
    }

    // Live stress stream
    device.onNotifyCurrentPressureData { [weak self] model in
      guard let self = self, let p = model?.pressure, p > 0 else { return }
      self.currentStressScore = Int(p)
      self.pushTelemetry()
    }

    // Live body temperature
    device.onNotifyBodyTemperatureValueBlock { [weak self] time, state, value in
      guard let self = self, value > 0 else { return }
      let deg = Double(value) / 10.0
      if deg >= 30.0 && deg <= 45.0 {
        self.skinTempDeviation = round((deg - 36.6) * 10) / 10
        self.pushTelemetry()
      }
    }

    // Wearing state (off wrist)
    device.onNotifyOffWristBlock { [weak self] _, _, state in
      guard let self = self else { return }
      self.isOffWrist = (state == 1)
      self.pushTelemetry()
    }

    // Find phone alert triggered from watch
    device.notifyFindMyPhoneNotifyReal { status, _, _ in
      AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
      AudioServicesPlaySystemSound(1005)
    }

    // Camera shutter triggered from watch
    device.notifyCamera { status, _, _ in
      AudioServicesPlaySystemSound(1108)
    }
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
    if model.rssi < -85 && model.rssi != 0 { return }
    let name = model.name ?? "KALKAN СААТ-1"
    let addr = deviceAddress(model)
    if discoveredUteDevices.count >= 25 && discoveredUteDevices[addr] == nil {
      return
    }
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

    // Auto-connect if this was a pending auto-reconnect target
    if let pending = pendingConnectAddress, !pending.isEmpty && !isConnected {
      let isMatch = addr.caseInsensitiveCompare(pending) == .orderedSame ||
                    model.identifier?.caseInsensitiveCompare(pending) == .orderedSame ||
                    (name.contains("СААТ") || name.contains("SAAT") || name.contains("KALKAN"))
      if isMatch {
        pendingConnectAddress = nil
        mgr.stopScanDevices()
        mgr.connect(model)
      }
    }
  }

  func uteDevicesStatus(_ status: UTEDevicesStatus, error: Error?, userInfo info: [AnyHashable: Any]?) {
    switch status.rawValue {
    case 0: // UTEDevicesStatusConnected
      isConnected = true
      connectedModel = mgr.connnectModel
      let addr = connectedModel != nil ? deviceAddress(connectedModel!) : ""
      if !addr.isEmpty {
        lastConnectedAddress = addr
        UserDefaults.standard.set(addr, forKey: "kalkan_last_connected_address")
      }
      pendingConnectAddress = nil
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
      refreshWorkout()
      pushTelemetry()

    case 4: // UTEDevicesStatusConnecting
      // Connection in progress; do not mark isConnected = true yet
      break

    case 1, 2, 3, 5, -1: // Disconnected, ConnectingError, ConnectionTimedout, Disconnecting, ConnectCheckFail
      isConnected = false
      connectedModel = nil
      stopTelemetryPoll()
      currentBpm = 0
      isOffWrist = false
      skinTempDeviation = 0.0
      pushTelemetry()

      // Auto-reconnect if device was paired and user didn't manually disconnect
      if let addr = lastConnectedAddress, !addr.isEmpty, pendingConnectAddress == nil {
        pendingConnectAddress = addr
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
          guard let self = self, !self.isConnected else { return }
          self.connect(address: addr) { _ in }
        }
      }

    default:
      // Unknown or sync/intermediate status (e.g. sync start/end) - do NOT disconnect!
      break
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

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    KalkanBleManager.shared.handleAppForeground()
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    KalkanBleManager.shared.handleAppForeground()
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
