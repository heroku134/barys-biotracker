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

  // BLE-05: Telemetry coalescing (1 Hz max) and non-draining polling controls
  private var lastPushTime: TimeInterval = 0
  private var pendingPushWorkItem: DispatchWorkItem?
  private var lastBatteryPollDate: Date?
  private var isPollingWorkout: Bool = false

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
  private var pendingConnectResult: FlutterResult?
  private var connectTimeoutWorkItem: DispatchWorkItem?
  private var isManualDisconnect = false
  #if canImport(UTEBluetoothRYApi)
  private var connectingUteModel: UTEModelDevice?
  #endif
  private var connectingPeripheral: CBPeripheral?

  private func resolvePendingConnect(success: Bool, errorMessage: String? = nil) {
    connectTimeoutWorkItem?.cancel()
    connectTimeoutWorkItem = nil
    #if canImport(UTEBluetoothRYApi)
    let targetModel = connectingUteModel
    connectingUteModel = nil
    #endif
    let targetPeriph = connectingPeripheral
    connectingPeripheral = nil

    if !success {
      pendingConnectAddress = nil
      #if canImport(UTEBluetoothRYApi)
      if let model = targetModel {
        _ = mgr.disconnectDevices(model)
      }
      #endif
      if let p = targetPeriph, !isConnected {
        centralManager?.cancelPeripheralConnection(p)
      }
      if centralManager?.isScanning == true && !isScanning {
        centralManager?.stopScan()
      }
    }
    if let result = pendingConnectResult {
      pendingConnectResult = nil
      if success {
        result(true)
      } else {
        result(FlutterError(code: "CONNECT_FAILED", message: errorMessage ?? "BLE connection failed", details: nil))
      }
    }
  }

  func initSdk() {
    if centralManager == nil {
      centralManager = CBCentralManager(
        delegate: self,
        queue: .main,
        options: [
          CBCentralManagerOptionRestoreIdentifierKey: "sport.kalkan.central_restore_id",
          CBCentralManagerOptionShowPowerAlertKey: true
        ]
      )
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

  private func isKalkanDevice(_ name: String) -> Bool {
    let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    if lower.isEmpty { return false }
    if lower.contains("kalkan") || lower.contains("саат") || lower.contains("saat") || lower.contains("nadal") {
      return true
    }
    if lower.hasPrefix("ute") || lower.contains(" ute") || lower.contains("ute-") || lower.contains("ute_") {
      return true
    }
    return false
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

    // 2. ONLY auto-reconnect to the specifically saved watch identifier:
    let savedAddress = lastConnectedAddress ?? UserDefaults.standard.string(forKey: "kalkan_last_connected_address")
    if let addr = savedAddress, !addr.isEmpty && !isConnected {
      let knownServices = ["6E400001-B5A3-F393-E0A9-E50E24DCCA9E", "EFF5", "6540", "FEE7", "180D", "180F", "180A", "FEF5", "FEE0", "FFE0", "FFE5"]
      if let connectedDevs = mgr.retrieveConnectedDevice(withServers: knownServices) {
        for dev in connectedDevs {
          if deviceAddress(dev) == addr || dev.identifier == addr {
            discoveredUteDevices[addr] = dev
            mgr.connect(dev)
            return
          }
        }
      }
      connect(address: addr) { _ in }
    }
    #endif

    // CoreBluetooth fallback: ONLY reconnect to saved address!
    if let cm = centralManager, cm.state == .poweredOn && !isConnected {
      let savedAddress = lastConnectedAddress ?? UserDefaults.standard.string(forKey: "kalkan_last_connected_address")
      if let addr = savedAddress, !addr.isEmpty, let uuid = UUID(uuidString: addr) {
        let connectedList = cm.retrievePeripherals(withIdentifiers: [uuid])
        if let dev = connectedList.first {
          discoveredPeripherals[dev.identifier.uuidString] = dev
          connect(address: dev.identifier.uuidString) { _ in }
        }
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

  func checkPermissions() -> String {
    if #available(iOS 13.1, *) {
      switch CBCentralManager.authorization {
      case .allowedAlways:
        return "granted"
      case .denied:
        return "permanentlyDenied"
      case .restricted:
        return "restricted"
      case .notDetermined:
        return "denied"
      @unknown default:
        return "denied"
      }
    } else {
      return "granted"
    }
  }

  func requestPermissions(result: @escaping FlutterResult) {
    if #available(iOS 13.1, *) {
      switch CBCentralManager.authorization {
      case .allowedAlways:
        result("granted")
        return
      case .denied:
        result("permanentlyDenied")
        return
      case .restricted:
        result("restricted")
        return
      case .notDetermined:
        break
      @unknown default:
        break
      }
    }
    // Cancel prior pending result to avoid hanging Flutter Futures
    pendingPermissionResult?(FlutterError(code: "CANCELLED", message: "Superseded by newer permission request", details: nil))
    pendingPermissionResult = result

    if centralManager == nil {
      centralManager = CBCentralManager(
        delegate: self,
        queue: .main,
        options: [
          CBCentralManagerOptionRestoreIdentifierKey: "sport.kalkan.central_restore_id",
          CBCentralManagerOptionShowPowerAlertKey: true
        ]
      )
    }
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
    isManualDisconnect = false
    if !isBluetoothEnabled() {
      result(FlutterError(code: "BLUETOOTH_DISABLED", message: "Bluetooth is powered off", details: nil))
      return
    }
    if checkPermissions() != "granted" {
      result(FlutterError(code: "PERMISSION_DENIED", message: "Bluetooth permission not granted", details: nil))
      return
    }

    if isConnected {
      #if canImport(UTEBluetoothRYApi)
      if let model = mgr.connnectModel, (deviceAddress(model) == address || model.identifier == address) {
        result(true)
        return
      }
      #endif
      if let p = connectedPeripheral, p.identifier.uuidString == address {
        result(true)
        return
      }
    }

    resolvePendingConnect(success: false, errorMessage: "Superceded by new connection request")
    pendingConnectResult = result
    let timeoutItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      if self.pendingConnectResult != nil {
        self.resolvePendingConnect(success: false, errorMessage: "Connection to \(address) timed out after 15 seconds")
      }
    }
    connectTimeoutWorkItem = timeoutItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 15.0, execute: timeoutItem)

    #if canImport(UTEBluetoothRYApi)
    if mgr.connectStatus == .connected, let model = mgr.connnectModel {
      if deviceAddress(model) == address || model.identifier == address {
        isConnected = true
        connectedModel = model
        currentDeviceName = model.name ?? "KALKAN СААТ-1"
        bindLiveStreams()
        refreshWorkout()
        pushTelemetry()
        resolvePendingConnect(success: true)
        return
      }
    }

    let knownServices = ["6E400001-B5A3-F393-E0A9-E50E24DCCA9E", "EFF5", "6540", "FEE7", "180D", "180F", "180A", "FEF5"]
    if let connectedDevs = mgr.retrieveConnectedDevice(withServers: knownServices) {
      for dev in connectedDevs {
        if deviceAddress(dev) == address || dev.identifier == address {
          discoveredUteDevices[address] = dev
          pendingConnectAddress = address
          connectingUteModel = dev
          mgr.connect(dev)
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
      connectingUteModel = model
      mgr.connect(model)
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
      connectingPeripheral = peripheral
      peripheral.delegate = self
      pendingConnectAddress = address
      centralManager?.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
      return
    }

    // If device not yet cached, start background scan and auto-connect upon discovery
    if centralManager?.state == .poweredOn && !address.isEmpty {
      pendingConnectAddress = address
      centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
      return
    }

    resolvePendingConnect(success: false, errorMessage: "Device \(address) not found")
  }

  func cancelConnect(result: @escaping FlutterResult) {
    resolvePendingConnect(success: false, errorMessage: "Cancelled by client")
    result(true)
  }

  func disconnect(forget: Bool = false, result: @escaping FlutterResult) {
    isManualDisconnect = true
    resolvePendingConnect(success: false, errorMessage: "Disconnected by user")
    if forget {
      lastConnectedAddress = nil
      UserDefaults.standard.removeObject(forKey: "kalkan_last_connected_address")
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
      currentDeviceName = ""
    }
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
    isOffWrist = false
    skinTempDeviation = 0.0
    pushTelemetry(immediate: true)
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

  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
      for p in peripherals {
        let id = p.identifier.uuidString
        discoveredPeripherals[id] = p
        p.delegate = self
        if p.state == .connected {
          connectedPeripheral = p
          isConnected = true
          currentDeviceName = p.name ?? "СААТ-1"
          #if canImport(UTEBluetoothRYApi)
          bindLiveStreams()
          pullNightAndDay()
          #endif
          pushTelemetry()
        }
      }
    }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if let pendingResult = pendingPermissionResult {
      pendingPermissionResult = nil
      pendingResult(checkPermissions())
    }
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
      pushTelemetry(immediate: true)
    case .poweredOff, .unsupported, .unauthorized, .resetting:
      resolvePendingConnect(success: false, errorMessage: "Bluetooth powered off or unauthorized")
      if isConnected {
        isConnected = false
      }
      pushTelemetry(immediate: true)
    @unknown default:
      break
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    let rawName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
    let cleanName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    let isKalkan = isKalkanDevice(cleanName)
    let displayName = !cleanName.isEmpty ? cleanName : (isKalkan ? "KALKAN СААТ-1" : "BLE Устройство")

    let address = peripheral.identifier.uuidString
    if discoveredPeripherals.count >= 100 && discoveredPeripherals[address] == nil {
      return
    }
    discoveredPeripherals[address] = peripheral

    DispatchQueue.main.async { [weak self] in
      self?.scanSink?([
        "name": displayName,
        "address": address,
        "rssi": RSSI.intValue,
        "isKalkan": isKalkan
      ])
    }

    if let pending = pendingConnectAddress, address.caseInsensitiveCompare(pending) == .orderedSame {
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
    resolvePendingConnect(success: false, errorMessage: error?.localizedDescription ?? "CoreBluetooth failed to connect")
    pushTelemetry(immediate: true)
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    resolvePendingConnect(success: false, errorMessage: error?.localizedDescription ?? "CoreBluetooth disconnected")
    isConnected = false
    connectedPeripheral = nil
    batteryCharacteristic = nil
    alertCharacteristic = nil
    writeCharacteristic = nil
    isCharging = false
    pollTimer?.invalidate()
    pollTimer = nil
    currentBpm = 0
    isOffWrist = false
    skinTempDeviation = 0.0
    // BLE-04: Preserve accumulated metrics: steps, calories, battery, hrv, rhr, sleep, hypnogram, deviceName
    pushTelemetry(immediate: true)
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
      let addr = peripheral.identifier.uuidString
      lastConnectedAddress = addr
      UserDefaults.standard.set(addr, forKey: "kalkan_last_connected_address")
      resolvePendingConnect(success: true)
      pushTelemetry(immediate: true)
    }

    #if !canImport(UTEBluetoothRYApi)
    // BLE-05: Handshake only for raw CoreBluetooth fallback (no dual-stack collision with UTE SDK)
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

    // BLE-05: Gentle 30s battery check for fallback (no duplicate 5s raw timer)
    if pollTimer == nil && isConnected {
      pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self, weak peripheral] _ in
        guard let self = self, let p = peripheral, self.isConnected else { return }
        if let bChar = self.batteryCharacteristic {
          p.readValue(for: bChar)
        }
      }
    }
    #endif
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

  // MARK: - Telemetry Push & FlutterStreamHandler (BLE-05: Coalesced 1 Hz max)

  private func pushTelemetry(immediate: Bool = false) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let now = Date().timeIntervalSince1970
      if immediate || (now - self.lastPushTime >= 1.0 && self.pendingPushWorkItem == nil) {
        self.pendingPushWorkItem?.cancel()
        self.pendingPushWorkItem = nil
        self.lastPushTime = now
        self.sendTelemetrySnapshot()
      } else if self.pendingPushWorkItem == nil {
        let delay = max(0.05, 1.0 - (now - self.lastPushTime))
        let item = DispatchWorkItem { [weak self] in
          guard let self = self else { return }
          self.pendingPushWorkItem = nil
          self.lastPushTime = Date().timeIntervalSince1970
          self.sendTelemetrySnapshot()
        }
        self.pendingPushWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
      }
    }
  }

  private func sendTelemetrySnapshot() {
    let snapshot: [String: Any] = [
      "isBluetoothEnabled": self.isBluetoothEnabled(),
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
      "timeInBedMinutes": self.timeInBedMinutes,
      "sleepEfficiency": self.currentSleepEfficiency,
      "sleepHypnogram": self.currentHypnogram,
      "currentStressScore": self.currentStressScore,
      "isOffWrist": self.isOffWrist,
      "skinTempDeviation": self.skinTempDeviation,
      "respiratoryRate": 0.0
    ]
    self.telemetrySink?(snapshot)
    UserDefaults.standard.set(snapshot, forKey: "kalkan_latest_telemetry_snapshot")
  }

  func performBackgroundSync(completion: @escaping (Bool) -> Void) {
    #if canImport(UTEBluetoothRYApi)
    guard isConnected else {
      let knownServices = ["6E400001-B5A3-F393-E0A9-E50E24DCCA9E", "EFF5", "6540", "FEE7", "180D", "180F", "180A", "FEF5"]
      if let connectedDevs = mgr.retrieveConnectedDevice(withServers: knownServices), let first = connectedDevs.first {
        mgr.connect(first)
      }
      completion(true)
      return
    }
    pullNightAndDay()
    refreshWorkout()
    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
      self?.pushTelemetry()
      completion(true)
    }
    #else
    completion(true)
    #endif
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

  // MARK: - Scientific Sleep Processing & Primary Session Isolation
  private struct ParsedSleepSession {
    var epochs: [[String: Any]] = []
    var startSec: Int = 0
    var endSec: Int = 0
    var totalSleepMinutes: Int = 0
    var deepSleepMinutes: Int = 0
    var lightSleepMinutes: Int = 0
    var remSleepMinutes: Int = 0
    var awakeMinutes: Int = 0

    var timeInBedMinutes: Int {
      let spanMinutes = max(0, (endSec - startSec) / 60)
      let sumMinutes = totalSleepMinutes + awakeMinutes
      return max(spanMinutes, sumMinutes)
    }

    var sleepEfficiency: Double {
      let inBed = timeInBedMinutes
      guard inBed > 0, totalSleepMinutes > 0 else { return 0.0 }
      let ratio = Double(totalSleepMinutes) / Double(inBed)
      return min(1.0, max(0.0, round(ratio * 100.0) / 100.0))
    }
  }

  private static let sleepDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone.current
    return df
  }()

  private func parseEpochDate(_ str: String?) -> Date? {
    guard let str = str?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else { return nil }
    let formats = [
      "yyyy-MM-dd-HH-mm",
      "yyyy-MM-dd HH:mm",
      "yyyy-MM-dd-HH-mm-ss",
      "yyyy-MM-dd HH:mm:ss",
      "yyyy/MM/dd HH:mm",
      "yyyy/MM/dd-HH-mm",
      "yyyy-MM-dd'T'HH:mm:ss"
    ]
    for fmt in formats {
      KalkanBleManager.sleepDateFormatter.dateFormat = fmt
      if let d = KalkanBleManager.sleepDateFormatter.date(from: str) {
        return d
      }
    }
    return nil
  }

  private func pullNightAndDay() {
    let now = Int(Date().timeIntervalSince1970)
    let start = now - 36 * 3600
    device.getSciSleepModel(withStartTime: start, endTime: now) { [weak self] debugArray, _, ok, code, _, dict in
      guard let self = self, self.sdkOk(Int(code)) || ok else { return }
      if let list = debugArray, !list.isEmpty {
        var sessions: [ParsedSleepSession] = []
        var currentSession: ParsedSleepSession? = nil
        var sessionCursorSec: Int = 0
        let nowSec = Int(Date().timeIntervalSince1970)

        for item in list {
          let dur = item.sleepTime
          // Skip placeholder items with zero duration unless explicit start/end markers
          if dur <= 0 && item.sleepType != 7 && item.sleepType != 8 {
            continue
          }

          // 1. Resolve epoch start timestamp
          let parsedStartDate = self.parseEpochDate(item.startTime)
          let parsedStartSec = parsedStartDate != nil ? Int(parsedStartDate!.timeIntervalSince1970) : nil
          let rawTimeStamp = item.timeStamp > 10_000_000_000 ? item.timeStamp / 1000 : item.timeStamp

          var startSec: Int
          if let parsed = parsedStartSec, parsed > 0 {
            if currentSession != nil && parsed < sessionCursorSec && (sessionCursorSec - parsed) <= 120 {
              startSec = sessionCursorSec
            } else {
              startSec = parsed
            }
          } else if rawTimeStamp > 0 {
            if currentSession == nil || rawTimeStamp > sessionCursorSec {
              startSec = rawTimeStamp
            } else {
              // item.timeStamp repeated across epochs indicates night session start time -> chain to cursor
              startSec = sessionCursorSec
            }
          } else {
            startSec = sessionCursorSec > 0 ? sessionCursorSec : (nowSec - max(1, dur) * 60)
          }

          // 2. Resolve epoch end timestamp
          let parsedEndDate = self.parseEpochDate(item.endTime)
          let parsedEndSec = parsedEndDate != nil ? Int(parsedEndDate!.timeIntervalSince1970) : nil

          var effectiveDur = dur
          var endSec: Int
          if let parsedEnd = parsedEndSec, parsedEnd > startSec {
            endSec = parsedEnd
            let spanDur = (endSec - startSec) / 60
            if effectiveDur <= 0 {
              effectiveDur = spanDur
            }
          } else if effectiveDur > 0 {
            endSec = startSec + effectiveDur * 60
          } else {
            endSec = startSec
          }

          // 3. Detect session boundaries:
          // - sleepType == 7: explicit sleep beginning marker
          // - Gap > 60 minutes between epochs
          let isNewSessionBreak = currentSession != nil && (
            item.sleepType == 7 ||
            (startSec - sessionCursorSec) > 3600
          )

          if isNewSessionBreak {
            if let cs = currentSession, cs.totalSleepMinutes > 0 || cs.awakeMinutes > 0 {
              sessions.append(cs)
            }
            currentSession = nil
          }

          if currentSession == nil {
            currentSession = ParsedSleepSession(startSec: startSec, endSec: endSec)
          }

          let stage: String
          switch item.sleepType {
          case 1:
            stage = "deep"
            currentSession?.deepSleepMinutes += effectiveDur
            currentSession?.totalSleepMinutes += effectiveDur
          case 2, 5, 6:
            stage = "light"
            currentSession?.lightSleepMinutes += effectiveDur
            currentSession?.totalSleepMinutes += effectiveDur
          case 4:
            stage = "rem"
            currentSession?.remSleepMinutes += effectiveDur
            currentSession?.totalSleepMinutes += effectiveDur
          case 3, 7, 8:
            stage = "awake"
            currentSession?.awakeMinutes += effectiveDur
          default:
            stage = "light"
            currentSession?.lightSleepMinutes += effectiveDur
            currentSession?.totalSleepMinutes += effectiveDur
          }

          if effectiveDur > 0 {
            currentSession?.epochs.append([
              "stage": stage,
              "startTime": Int64(startSec) * 1000,
              "endTime": Int64(endSec) * 1000,
              "durationMinutes": effectiveDur
            ])
          }

          currentSession?.endSec = max(currentSession?.endSec ?? 0, endSec)
          sessionCursorSec = max(sessionCursorSec, endSec)

          // Explicit sleep ending marker (sleepType == 8)
          if item.sleepType == 8 {
            if let cs = currentSession, cs.totalSleepMinutes > 0 || cs.awakeMinutes > 0 {
              sessions.append(cs)
            }
            currentSession = nil
          }
        }

        if let cs = currentSession, cs.totalSleepMinutes > 0 || cs.awakeMinutes > 0 {
          sessions.append(cs)
        }

        // 4. Select single primary night sleep session:
        // Calculate UTE sleep day window [20:00 yesterday .. 20:00 today) or [20:00 today .. 20:00 tomorrow)
        let cal = Calendar.current
        let currentDate = Date()
        let currentHour = cal.component(.hour, from: currentDate)
        let cycleStart: Date
        if currentHour < 20 {
          let yesterday = cal.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
          cycleStart = cal.date(bySettingHour: 20, minute: 0, second: 0, of: yesterday) ?? yesterday
        } else {
          cycleStart = cal.date(bySettingHour: 20, minute: 0, second: 0, of: currentDate) ?? currentDate
        }
        let cycleStartSec = Int(cycleStart.timeIntervalSince1970)
        // Allow 2-hour buffer (from 18:00) for early sleepers
        let windowStartSec = cycleStartSec - 2 * 3600

        // Sessions belonging to current sleep cycle window
        let candidates = sessions.filter { $0.endSec >= windowStartSec }
        let primaryCandidates = candidates.filter { $0.totalSleepMinutes >= 60 }

        let selectedSession: ParsedSleepSession? = primaryCandidates.max(by: { $0.totalSleepMinutes < $1.totalSleepMinutes })
          ?? candidates.max(by: { $0.totalSleepMinutes < $1.totalSleepMinutes })
          ?? sessions.last

        if let session = selectedSession, session.totalSleepMinutes > 0 || session.awakeMinutes > 0 {
          self.currentSleepMinutes = session.totalSleepMinutes
          self.currentDeepSleepMinutes = session.deepSleepMinutes
          self.currentRemSleepMinutes = session.remSleepMinutes
          self.timeInBedMinutes = session.timeInBedMinutes
          self.currentSleepEfficiency = session.sleepEfficiency
          self.currentHypnogram = session.epochs
          self.pushTelemetry()
          self.refreshWorkout()
          return
        }
      }

      // Fallback: parse discrete session from uteDict (never sum multiple days)
      if let session = self.extractSleepSession(from: dict), session.sleep > 0 {
        self.currentSleepMinutes = session.sleep
        self.currentDeepSleepMinutes = session.deep
        self.currentRemSleepMinutes = session.rem
        self.timeInBedMinutes = session.inBed
        self.currentSleepEfficiency = session.efficiency
        self.currentHypnogram = []
        self.pushTelemetry()
      }
    }
    refreshWorkout()
  }

  private func refreshWorkout() {
    guard isConnected else { return }
    if isPollingWorkout { return }
    isPollingWorkout = true

    let now = Date()
    // BLE-05: Battery query at most once every 5 minutes (300 seconds)
    if lastBatteryPollDate == nil || now.timeIntervalSince(lastBatteryPollDate!) >= 300 {
      lastBatteryPollDate = now
      device.getBatteryInfo { [weak self] percent, code, _ in
        if percent > 0 && percent <= 100 {
          self?.currentBattery = Int(percent)
          self?.pushTelemetry()
        }
      }
    }

    device.getCurrentDayTotalWorkoutData { [weak self] todayModel, code, _ in
      guard let self = self else { return }
      defer { self.isPollingWorkout = false }
      guard self.sdkOk(Int(code)), let model = todayModel else {
        self.pushTelemetry()
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
        if sleep > 0 && self.currentSleepMinutes == 0 {
          self.currentSleepMinutes = sleep
          self.timeInBedMinutes = sleep
        }
      }
      self.pushTelemetry()
    }
  }

  // BLE-05: 30-second cadence instead of battery-draining 8-second polling
  private func startTelemetryPoll() {
    stopTelemetryPoll()
    DispatchQueue.main.async { [weak self] in
      self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
        self?.refreshWorkout()
      }
    }
  }

  private func stopTelemetryPoll() {
    pollTimer?.invalidate()
    pollTimer = nil
  }

  private func extractSleepSession(from dict: [AnyHashable: Any]?) -> (sleep: Int, deep: Int, rem: Int, inBed: Int, efficiency: Double)? {
    guard let dict = dict else { return nil }

    var candidateArrays: [[Any]] = []
    if let dayByDay = dict[kSDKQuerySleepDayByDay] as? [Any] {
      candidateArrays.append(dayByDay)
    }
    if let dayByDayStr = dict["kSDKQuerySleepDayByDay"] as? [Any] {
      candidateArrays.append(dayByDayStr)
    }
    for (_, val) in dict {
      if let arr = val as? [Any] {
        candidateArrays.append(arr)
      }
    }

    var bestSession: (sleep: Int, deep: Int, rem: Int, inBed: Int, efficiency: Double)? = nil

    for arr in candidateArrays {
      for item in arr {
        guard let map = item as? [AnyHashable: Any] else { continue }

        var total = 0
        for key in ["sleepTime", "totalSleep", "sleepMinutes", "duration"] {
          if let n = map[key] as? NSNumber, n.intValue > 0 {
            total = n.intValue
            break
          }
        }
        if total > 1440 { total /= 60 }
        guard total > 0 && total <= 960 else { continue }

        var deep = 0
        for key in ["deepSleepTime", "deepTime", "deepSleep", "deep"] {
          if let n = map[key] as? NSNumber, n.intValue > 0 {
            deep = n.intValue
            break
          }
        }
        if deep > 1440 { deep /= 60 }

        var rem = 0
        for key in ["remSleepTime", "remTime", "remSleep", "rem"] {
          if let n = map[key] as? NSNumber, n.intValue > 0 {
            rem = n.intValue
            break
          }
        }
        if rem > 1440 { rem /= 60 }

        var awake = 0
        for key in ["awakeSleepTime", "awakeTime", "awakeSleep", "awake"] {
          if let n = map[key] as? NSNumber, n.intValue > 0 {
            awake = n.intValue
            break
          }
        }
        if awake > 1440 { awake /= 60 }

        let inBed = max(total, total + awake)
        let eff = inBed > 0 ? min(1.0, round((Double(total) / Double(inBed)) * 100.0) / 100.0) : 0.0

        if bestSession == nil || total > bestSession!.sleep {
          bestSession = (sleep: total, deep: deep, rem: rem, inBed: inBed, efficiency: eff)
        }
      }
    }

    return bestSession
  }

  private func sleepMinutes(from dict: [AnyHashable: Any]?) -> Int? {
    return extractSleepSession(from: dict)?.sleep
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
        self.pushTelemetry()
      } else if type == .HRV {
        self.currentHrv = Double(value)
        self.pushTelemetry()
      } else if type == .pressure {
        self.currentStressScore = Int(value)
        self.pushTelemetry()
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

    // Live body temperature notification
    device.onNotifyBodyTemperatureValueBlock { [weak self] time, state, value in
      guard let self = self, value > 0 else { return }
      // Spot skin temperature in Celsius: do not subtract synthetic 36.6 constant
      self.pushTelemetry()
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
    let rawName = model.name ?? ""
    let cleanName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    let isKalkan = isKalkanDevice(cleanName)
    let displayName = !cleanName.isEmpty ? cleanName : (isKalkan ? "KALKAN СААТ-1" : "BLE Устройство")
    let addr = deviceAddress(model)

    if discoveredUteDevices.count >= 100 && discoveredUteDevices[addr] == nil {
      return
    }
    discoveredUteDevices[addr] = model
    if let id = model.identifier {
      discoveredUteDevices[id] = model
    }
    DispatchQueue.main.async { [weak self] in
      self?.scanSink?([
        "name": displayName,
        "address": addr,
        "rssi": model.rssi,
        "isKalkan": isKalkan
      ])
    }

    // Auto-connect ONLY if this was a pending auto-reconnect target matching the exact address/identifier
    if let pending = pendingConnectAddress, !pending.isEmpty && !isConnected {
      let isMatch = addr.caseInsensitiveCompare(pending) == .orderedSame ||
                    model.identifier?.caseInsensitiveCompare(pending) == .orderedSame
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
      resolvePendingConnect(success: true)
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
      pushTelemetry(immediate: true)

    case 4: // UTEDevicesStatusConnecting
      // Connection in progress; do not mark isConnected = true yet
      break

    case 1, 2, 3, 5, -1: // Disconnected, ConnectingError, ConnectionTimedout, Disconnecting, ConnectCheckFail
      resolvePendingConnect(success: false, errorMessage: "UTE connection status error: \(status.rawValue)")
      isConnected = false
      connectedModel = nil
      stopTelemetryPoll()
      currentBpm = 0
      isOffWrist = false
      skinTempDeviation = 0.0
      pendingConnectAddress = nil
      pushTelemetry(immediate: true)

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
      guard let appRefreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: true)
        return
      }

      // Schedule next 15-minute background refresh
      let request = BGAppRefreshTaskRequest(identifier: "sport.kalkan.bio.refresh")
      request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
      try? BGTaskScheduler.shared.submit(request)

      var isCompleted = false
      appRefreshTask.expirationHandler = {
        if !isCompleted {
          isCompleted = true
          appRefreshTask.setTaskCompleted(success: false)
        }
      }

      // Execute actual telemetry backfill and buffer sync
      KalkanBleManager.shared.performBackgroundSync { success in
        if !isCompleted {
          isCompleted = true
          appRefreshTask.setTaskCompleted(success: success)
        }
      }
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
      case "cancelConnect":
        KalkanBleManager.shared.cancelConnect(result: result)
      case "disconnect":
        let forget = (call.arguments as? [String: Any])?["forget"] as? Bool ?? false
        KalkanBleManager.shared.disconnect(forget: forget, result: result)
      case "isLocationServiceEnabled":
        result(true)
      case "openAppSettings", "openLocationSettings":
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:]) { success in
            result(success)
          }
        } else {
          result(false)
        }
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
