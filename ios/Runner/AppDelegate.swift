import Flutter
import UIKit
import UserNotifications
import BackgroundTasks
import CoreBluetooth
import AudioToolbox
import HealthKit

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(UTEBluetoothRYApi)
import UTEBluetoothRYApi
#else
#error("UTEBluetoothRYApi framework is required for building KALKAN SPORT iOS")
#endif

class KalkanBleManager: NSObject, CBCentralManagerDelegate, UTEBluetoothDelegate, FlutterStreamHandler {
  static let shared = KalkanBleManager()

  private var centralManager: CBCentralManager?
  private var scanSink: FlutterEventSink?
  private var telemetrySink: FlutterEventSink?

  private var isScanning = false
  private var discoveredUteDevices: [String: UTEModelDevice] = [:]
  private var connectedModel: UTEModelDevice?
  private var pendingConnectAddress: String?
  private var connectingUteModel: UTEModelDevice?

  private var mgr: UTEBluetoothMgr { UTEBluetoothMgr.sharedInstance() }
  private var device: UTEDeviceMgr { mgr.mgrDevice }
  private func sdkOk(_ code: Int) -> Bool { code == 100000 }

  private var isConnected = false
  private var currentDeviceName = ""
  private var pollTimer: Timer?
  private var isStreamsBound = false
  private var isSdkBluetoothReady = false
  private var pendingSdkReadyBlocks: [() -> Void] = []

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
  private var currentRespiratoryRate: Double = 0.0
  private var currentBloodOxygen: Int = 0
  var isAncsAuthorized: Bool = true
  private var findDeviceAutoStopWorkItem: DispatchWorkItem?

  private var lastConnectedAddress: String?
  private var pendingConnectResult: FlutterResult?
  private var pendingPermissionResult: FlutterResult?
  private var connectTimeoutWorkItem: DispatchWorkItem?
  private var isManualDisconnect = false

  private func resolvePendingConnect(success: Bool, errorMessage: String? = nil) {
    connectTimeoutWorkItem?.cancel()
    connectTimeoutWorkItem = nil
    let targetModel = connectingUteModel
    connectingUteModel = nil

    if !success {
      pendingConnectAddress = nil
      if let model = targetModel {
        _ = mgr.disconnectDevices(model)
      }
      if mgr.isScanning && !isScanning {
        mgr.stopScanDevices()
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
    restoreLatestSnapshot()
    if centralManager == nil {
      centralManager = CBCentralManager(
        delegate: self,
        queue: .main,
        options: [
          CBCentralManagerOptionShowPowerAlertKey: true
        ]
      )
    }
    mgr.initUTEMgr()
    mgr.delegate = self
    mgr.isScanRepeat = true
    lastConnectedAddress = UserDefaults.standard.string(forKey: "kalkan_last_connected_address")
  }

  private func restoreLatestSnapshot() {
    guard let cached = UserDefaults.standard.dictionary(forKey: "kalkan_latest_telemetry_snapshot") else { return }
    if let bpm = cached["heartRate"] as? Int, bpm > 0 { currentBpm = bpm }
    if let st = cached["steps"] as? Int, st > 0 { currentSteps = st }
    if let cal = cached["calories"] as? Int, cal > 0 { currentCalories = cal }
    if let bat = cached["batteryLevel"] as? Int, bat > 0 { currentBattery = bat }
    if let ch = cached["isCharging"] as? Bool { isCharging = ch }
    if let hrv = cached["hrv"] as? Double, hrv > 0 { currentHrv = hrv }
    if let rhr = cached["restingHeartRate"] as? Int, rhr > 0 { currentRhr = rhr }
    if let sl = cached["sleepMinutes"] as? Int, sl > 0 { currentSleepMinutes = sl }
    if let dsl = cached["deepSleepMinutes"] as? Int, dsl > 0 { currentDeepSleepMinutes = dsl }
    if let rsl = cached["remSleepMinutes"] as? Int, rsl > 0 { currentRemSleepMinutes = rsl }
    if let tib = cached["timeInBedMinutes"] as? Int, tib > 0 { timeInBedMinutes = tib }
    if let eff = cached["sleepEfficiency"] as? Double, eff > 0 { currentSleepEfficiency = eff }
    if let hyp = cached["sleepHypnogram"] as? [[String: Any]], !hyp.isEmpty { currentHypnogram = hyp }
    if let sc = cached["currentStressScore"] as? Int, sc > 0 { currentStressScore = sc }
    if let sk = cached["skinTempDeviation"] as? Double { skinTempDeviation = sk }
    if let rr = cached["respiratoryRate"] as? Double, rr > 0 {
      currentRespiratoryRate = rr
    } else if currentRhr > 0 {
      currentRespiratoryRate = deriveRespiratoryRate(rhr: currentRhr, hrv: currentHrv)
    }
    if let oxy = cached["bloodOxygen"] as? Int, oxy > 0 { currentBloodOxygen = oxy }
    if let ancs = cached["isAncsAuthorized"] as? Bool { isAncsAuthorized = ancs }
    if let dev = cached["deviceName"] as? String, !dev.isEmpty { currentDeviceName = dev }
  }

  private func deriveRespiratoryRate(rhr: Int, hrv: Double) -> Double {
    guard rhr > 0 else { return 0.0 }
    let clampedRhr = min(100, max(40, rhr))
    let baseRr = 14.0 + Double(clampedRhr - 60) * 0.08
    let clampedHrv = min(150.0, max(10.0, hrv > 0 ? hrv : 50.0))
    let hrvAdjustment = (clampedHrv - 50.0) * 0.03
    let derived = min(22.0, max(11.0, baseRr - hrvAdjustment))
    return round(derived * 10.0) / 10.0
  }

  private func runWhenSdkReady(_ action: @escaping () -> Void) {
    if isSdkBluetoothReady || mgr.isOpenBluetooth {
      action()
    } else {
      pendingSdkReadyBlocks.append(action)
      // Safety timeout: execute if SDK callback doesn't arrive within 2.5s and BT is powered on
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
        guard let self = self else { return }
        if !self.pendingSdkReadyBlocks.isEmpty {
          let b = self.pendingSdkReadyBlocks.removeFirst()
          b()
        }
      }
    }
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
    // If UTE SDK already maintains an active connection, refresh data & streams
    if mgr.connectStatus.rawValue == 0, let model = mgr.connnectModel {
      isConnected = true
      connectedModel = model
      currentDeviceName = model.name ?? "KALKAN СААТ-1"
      bindLiveStreams()
      refreshWorkout()
      pushTelemetry()
      return
    }
    // Reconnection is orchestrator-driven by Dart UteBleBridge to prevent native race conditions
  }

  func isBluetoothEnabled() -> Bool {
    guard let cm = centralManager else { return mgr.isOpenBluetooth }
    return cm.state == .poweredOn
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
        pendingPermissionResult?(FlutterError(code: "CANCELLED", message: "Superseded by newer permission request", details: nil))
        pendingPermissionResult = result
        if centralManager == nil {
          centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [
              CBCentralManagerOptionShowPowerAlertKey: true
            ]
          )
        }
        return
      @unknown default:
        break
      }
    }
    result("granted")
  }

  func startScan(result: @escaping FlutterResult) {
    guard isBluetoothEnabled() else {
      result(FlutterError(code: "BLUETOOTH_DISABLED", message: "Bluetooth is powered off", details: nil))
      return
    }
    guard checkPermissions() == "granted" else {
      result(FlutterError(code: "PERMISSION_DENIED", message: "Bluetooth permission not granted", details: nil))
      return
    }

    runWhenSdkReady { [weak self] in
      guard let self = self else { return }
      self.isScanning = true
      self.discoveredUteDevices.removeAll()
      self.mgr.delegate = self
      self.mgr.isScanRepeat = true
      self.mgr.startScanDevices()
      result(true)
    }
  }

  func stopScan(result: @escaping FlutterResult) {
    isScanning = false
    mgr.stopScanDevices()
    DispatchQueue.main.async { [weak self] in
      self?.scanSink?(["isScanComplete": true])
    }
    result(true)
  }

  func connect(address: String, result: @escaping FlutterResult) {
    isManualDisconnect = false
    guard isBluetoothEnabled() else {
      result(FlutterError(code: "BLUETOOTH_DISABLED", message: "Bluetooth is powered off", details: nil))
      return
    }
    guard checkPermissions() == "granted" else {
      result(FlutterError(code: "PERMISSION_DENIED", message: "Bluetooth permission not granted", details: nil))
      return
    }

    runWhenSdkReady { [weak self] in
      guard let self = self else { return }
      self.performConnect(address: address, result: result)
    }
  }

  private func performConnect(address: String, result: @escaping FlutterResult) {
    if isConnected {
      if let model = mgr.connnectModel, (deviceAddress(model).caseInsensitiveCompare(address) == .orderedSame || model.identifier?.caseInsensitiveCompare(address) == .orderedSame || model.addressStr?.caseInsensitiveCompare(address) == .orderedSame) {
        result(true)
        return
      }
    }

    resolvePendingConnect(success: false, errorMessage: "Superceded by new connection request")
    pendingConnectResult = result
    let timeoutItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      if self.pendingConnectResult != nil {
        if self.mgr.isScanning && !self.isScanning {
          self.mgr.stopScanDevices()
        }
        self.resolvePendingConnect(success: false, errorMessage: "Connection to \(address) timed out after 15 seconds")
      }
    }
    connectTimeoutWorkItem = timeoutItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 15.0, execute: timeoutItem)

    if mgr.connectStatus == .connected, let model = mgr.connnectModel {
      if deviceAddress(model).caseInsensitiveCompare(address) == .orderedSame || model.identifier?.caseInsensitiveCompare(address) == .orderedSame || model.addressStr?.caseInsensitiveCompare(address) == .orderedSame {
        isConnected = true
        connectedModel = model
        currentDeviceName = model.name ?? "KALKAN СААТ-1"
        bindLiveStreams()
        applyDeviceHardwareSettings()
        refreshWorkout()
        pushTelemetry()
        resolvePendingConnect(success: true)
        return
      }
    }

    let knownServices = ["6E400001-B5A3-F393-E0A9-E50E24DCCA9E", "EFF5", "6540", "FEE7", "180D", "180F", "180A", "FEF5"]
    if let connectedDevs = mgr.retrieveConnectedDevice(withServers: knownServices) {
      for dev in connectedDevs {
        if deviceAddress(dev).caseInsensitiveCompare(address) == .orderedSame || dev.identifier?.caseInsensitiveCompare(address) == .orderedSame {
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
        if deviceAddress(dev).caseInsensitiveCompare(address) == .orderedSame ||
           dev.identifier?.caseInsensitiveCompare(address) == .orderedSame ||
           dev.addressStr?.caseInsensitiveCompare(address) == .orderedSame {
          targetUte = dev
          break
        }
      }
    }

    // If not in current scan cache (e.g. app restart), instantiate model with identifier
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

    if mgr.isScanning && !isScanning {
      mgr.stopScanDevices()
    }
    resolvePendingConnect(success: false, errorMessage: "Device \(address) not found")
  }

  func cancelConnect(result: @escaping FlutterResult) {
    if mgr.isScanning && !isScanning {
      mgr.stopScanDevices()
    }
    resolvePendingConnect(success: false, errorMessage: "Cancelled by client")
    result(true)
  }

  func disconnect(forget: Bool = false, result: @escaping FlutterResult) {
    isManualDisconnect = true
    findDeviceAutoStopWorkItem?.cancel()
    findDeviceAutoStopWorkItem = nil
    if mgr.isScanning && !isScanning {
      mgr.stopScanDevices()
    }
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
      currentRespiratoryRate = 0.0
      currentBloodOxygen = 0
    }
    pendingConnectAddress = nil
    if let model = connectedModel {
      _ = mgr.disconnectDevices(model)
    }
    connectedModel = nil

    isConnected = false
    isCharging = false
    isStreamsBound = false
    stopTelemetryPoll()
    currentBpm = 0
    isOffWrist = false
    skinTempDeviation = 0.0
    pushTelemetry(immediate: true)
    result(true)
  }

  func resetFactory(result: @escaping FlutterResult) {
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    device.resetFactory(0) { [weak self] code, _ in
      guard let self = self else { return }
      self.disconnect(forget: true) { _ in }
      result(true)
    }
  }

  func configureHeartRateMonitoring(intervalMinutes: Int, continuous: Bool, result: @escaping FlutterResult) {
    UserDefaults.standard.set(intervalMinutes, forKey: "kalkan_hr_interval_minutes")
    UserDefaults.standard.set(continuous, forKey: "kalkan_hr_continuous_enabled")
    if isConnected {
      applyDeviceHardwareSettings(intervalMinutes: intervalMinutes, continuousHr: continuous)
    }
    result(true)
  }

  private func applyDeviceHardwareSettings(intervalMinutes: Int? = nil, continuousHr: Bool? = nil) {
    let savedInterval = UserDefaults.standard.integer(forKey: "kalkan_hr_interval_minutes")
    let interval = intervalMinutes ?? (savedInterval > 0 ? savedInterval : 15) // 15m default to save battery
    let continuous = continuousHr ?? UserDefaults.standard.bool(forKey: "kalkan_hr_continuous_enabled")

    device.setAutoHeartRate(true) { _, _ in }
    device.setAutoHeartRateInterval(interval) { _ in }
    device.setContinueMeasureHeartRateSwitch(continuous) { _, _ in }
    device.setProfessionalSleep(true) { _, _ in }
  }

  func findDevice(enable: Bool = true, result: @escaping FlutterResult) {
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    findDeviceAutoStopWorkItem?.cancel()
    findDeviceAutoStopWorkItem = nil

    let cmd = enable ? 1 : 0
    device.setFindWearCmd(cmd) { [weak self] code, _ in
      guard let self = self else { return }
      if self.sdkOk(Int(code)) {
        if enable {
          let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isConnected else { return }
            self.device.setFindWearCmd(0) { _, _ in }
          }
          self.findDeviceAutoStopWorkItem = item
          DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: item)
        }
        result(true)
      } else {
        result(FlutterError(code: "COMMAND_FAILED", message: "setFindWearCmd failed with code \(code)", details: nil))
      }
    }
  }

  func measureHeartRate(result: @escaping FlutterResult) {
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    // Do NOT enable continuous measurement switch here! Measure on-demand optical HRM cleanly.
    device.click(.HRM) { [weak self] code in
      guard let self = self else { return }
      if self.sdkOk(Int(code)) {
        result(true)
      } else {
        self.device.oneClickMeasurement { [weak self] fallbackCode in
          guard let self = self else { return }
          if self.sdkOk(Int(fallbackCode)) {
            result(true)
          } else {
            result(FlutterError(code: "MEASUREMENT_FAILED", message: "Failed to trigger heart rate measurement (code \(fallbackCode))", details: nil))
          }
        }
      }
    }
  }

  func syncTime(result: @escaping FlutterResult) {
    guard isConnected else {
      result(FlutterError(code: "NOT_CONNECTED", message: "Watch not connected", details: nil))
      return
    }
    let seconds = Int(Date().timeIntervalSince1970)
    let totalOffsetSec = TimeZone.current.secondsFromGMT()
    let timeZone = totalOffsetSec / 3600
    let minuteOffset = (abs(totalOffsetSec) % 3600) / 60
    device.setTimeClock(seconds, timeZone: timeZone, minuteOffset: minuteOffset) { [weak self] code, _ in
      guard let self = self else { return }
      if self.sdkOk(Int(code)) {
        result(true)
      } else {
        result(FlutterError(code: "SYNC_TIME_FAILED", message: "setTimeClock failed with code \(code)", details: nil))
      }
    }
  }

  func setDisconnectRemind(enable: Bool, result: @escaping FlutterResult) {
    guard isConnected else {
      result(false)
      return
    }
    device.setDisconnectRemind(enable) { [weak self] code, _ in
      guard let self = self else { return }
      result(self.sdkOk(Int(code)) || code == 0)
    }
  }

  func setSmartAlarm(enable: Bool, hour: Int, minute: Int, result: @escaping FlutterResult) {
    guard isConnected else {
      result(false)
      return
    }
    let clock = UTEModelClock()
    clock.index = 1
    clock.enable = enable
    clock.timeHour = hour
    clock.timeMin = minute
    device.setAlarmArrayModel([clock]) { [weak self] code, _ in
      guard let self = self else { return }
      result(self.sdkOk(Int(code)) || code == 0)
    }
  }

  func setHydrationReminder(enable: Bool, intervalMinutes: Int, result: @escaping FlutterResult) {
    guard isConnected else {
      result(false)
      return
    }
    let water = UTEModelWaterClock()
    water.status = enable ? 1 : 0
    water.startHH = 8
    water.startMM = 0
    water.endHH = 22
    water.endMM = 0
    water.cycle = intervalMinutes
    device.setWaterClock(water) { code in
      result(code == 100000 || code == 0)
    }
  }

  func setCallRemindEnable(enable: Bool, result: @escaping FlutterResult) {
    guard isConnected else {
      result(false)
      return
    }
    device.incomingEnable(enable) { code in
      result(code == 100000 || code == 0)
    }
  }

  func clearAccountData(result: @escaping FlutterResult) {
    guard isConnected else {
      result(false)
      return
    }
    device.resetFactory(0) { [weak self] code, _ in
      guard let self = self else { return }
      result(self.sdkOk(Int(code)) || code == 0)
    }
  }

  func setUserProfile(heightCm: Int, weightKg: Int, age: Int, gender: String, stepGoal: Int, calorieGoal: Int, result: @escaping FlutterResult) {
    guard isConnected else {
      result(false)
      return
    }
    let person = UTEModelPersonInfo()
    person.height = heightCm
    person.weight = weightKg
    person.age = age
    person.gender = (gender.lowercased() == "female" || gender.lowercased() == "2") ? 2 : 1
    device.setUserPhysicalInfoModel(person) { [weak self] code, _ in
      guard let self = self else { return }
      let goal = UTEModelSportGoal()
      goal.goalType = 1
      goal.motionType = 1
      goal.goalStep = stepGoal
      goal.goalCalorie = calorieGoal
      self.device.setMotionGoalModel([goal]) { gCode, _ in
        result(self.sdkOk(Int(code)) || self.sdkOk(Int(gCode)) || code == 0 || gCode == 0)
      }
    }
  }

  func getWorkoutHistory(result: @escaping FlutterResult) {
    guard isConnected else {
      result([])
      return
    }
    let nowSec = Int(Date().timeIntervalSince1970)
    let startSec = nowSec - 7 * 24 * 3600
    device.getRecordList(startSec, endTime: nowSec) { [weak self] recordModel, code, _ in
      guard let self = self, let recordModel = recordModel, let list = recordModel.recordItemList, list.count > 0 else {
        result([])
        return
      }
      var workouts: [[String: Any]] = []
      let group = DispatchGroup()
      for item in list {
        group.enter()
        let recId = ((item as AnyObject).value(forKey: "ID") as? Int) ?? 0
        self.device.getRecordSummary(recId) { summary, _, _ in
          defer { group.leave() }
          guard let s = summary as AnyObject? else { return }
          let st = (s.value(forKey: "startTime") as? Int) ?? 0
          let et = (s.value(forKey: "endTime") as? Int) ?? 0
          let dur = (s.value(forKey: "totalTime") as? Int) ?? 0
          let cal = (s.value(forKey: "calorie") as? Int) ?? 0
          let dist = (s.value(forKey: "distance") as? Double) ?? Double((s.value(forKey: "distance") as? Int) ?? 0)
          let stp = (s.value(forKey: "step") as? Int) ?? 0
          let maxH = (s.value(forKey: "hrABSMaxPeak") as? Int) ?? 0
          let minH = (s.value(forKey: "hrABSMinPeak") as? Int) ?? 0
          let typ = (s.value(forKey: "type") as? Int) ?? 0
          workouts.append([
            "startTime": st,
            "endTime": et,
            "duration": dur,
            "calories": cal,
            "distance": dist,
            "steps": stp,
            "heart": maxH > 0 ? (maxH + minH) / 2 : 0,
            "maxHeart": maxH,
            "minHeart": minH,
            "sportsType": typ
          ])
        }
      }
      group.notify(queue: .main) {
        result(workouts)
      }
    }
  }

  func getHeartRateHistory(result: @escaping FlutterResult) {
    result([])
  }

  // MARK: - CBCentralManagerDelegate

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if let pendingResult = pendingPermissionResult {
      pendingPermissionResult = nil
      pendingResult(checkPermissions())
    }
    switch central.state {
    case .poweredOn:
      pushTelemetry(immediate: true)
    case .unknown, .poweredOff, .unsupported, .unauthorized, .resetting:
      resolvePendingConnect(success: false, errorMessage: "Bluetooth powered off or unauthorized")
      if isConnected {
        isConnected = false
      }
      pushTelemetry(immediate: true)
    @unknown default:
      break
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
      "respiratoryRate": self.currentRespiratoryRate,
      "bloodOxygen": self.currentBloodOxygen,
      "isAncsAuthorized": self.isAncsAuthorized
    ]
    self.telemetrySink?(snapshot)
    UserDefaults.standard.set(snapshot, forKey: "kalkan_latest_telemetry_snapshot")
  }

  func performBackgroundSync(completion: @escaping (Bool) -> Void) {
    guard isConnected else {
      completion(true)
      return
    }
    pullNightAndDay()
    refreshWorkout()
    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
      self?.pushTelemetry()
      completion(true)
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

  // MARK: - UTE SDK Device Identifier Resolution

  /// Returns the persistent peripheral identifier (UUID) as the primary key on iOS.
  /// Falls back to addressStr (MAC) if present. Never generates a random UUID!
  private func deviceAddress(_ model: UTEModelDevice) -> String {
    if let s = model.identifier, !s.isEmpty { return s }
    if let s = model.addressStr, !s.isEmpty { return s }
    return ""
  }

  // MARK: - Scientific Sleep Processing & Primary Session Isolation

  private final class ParsedSleepSession {
    var epochs: [[String: Any]] = []
    var startSec: Int = 0
    var endSec: Int = 0
    var totalSleepMinutes: Int = 0
    var deepSleepMinutes: Int = 0
    var lightSleepMinutes: Int = 0
    var remSleepMinutes: Int = 0
    var awakeMinutes: Int = 0

    init(startSec: Int, endSec: Int) {
      self.startSec = startSec
      self.endSec = endSec
    }

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

  func pullNightAndDay() {
    let now = Int(Date().timeIntervalSince1970)
    let start = now - 36 * 3600
    device.getSciSleepModel(withStartTime: start, endTime: now) { [weak self] debugArray, _, ok, code, _, dict in
      guard let self = self, self.sdkOk(Int(code)) || ok else { return }
      if let list = debugArray, list.count > 0 {
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

          if let session = currentSession {
            let stage: String
            switch item.sleepType {
            case 1:
              stage = "deep"
              session.deepSleepMinutes += effectiveDur
              session.totalSleepMinutes += effectiveDur
            case 2, 5, 6:
              stage = "light"
              session.lightSleepMinutes += effectiveDur
              session.totalSleepMinutes += effectiveDur
            case 4:
              stage = "rem"
              session.remSleepMinutes += effectiveDur
              session.totalSleepMinutes += effectiveDur
            case 3, 7, 8:
              stage = "awake"
              session.awakeMinutes += effectiveDur
            default:
              stage = "light"
              session.lightSleepMinutes += effectiveDur
              session.totalSleepMinutes += effectiveDur
            }

            if effectiveDur > 0 {
              session.epochs.append([
                "stage": stage,
                "startTime": Int64(startSec) * 1000,
                "endTime": Int64(endSec) * 1000,
                "durationMinutes": effectiveDur
              ])
            }

            if endSec > session.endSec {
              session.endSec = endSec
            }
          }

          sessionCursorSec = max(sessionCursorSec, endSec)

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

        // 4. Select single primary night sleep session
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
        let windowStartSec = cycleStartSec - 2 * 3600

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

      // Fallback: parse discrete session from uteDict
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

  // BLE-05: 30-second cadence instead of battery-draining polling
  private func startTelemetryPoll() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.isConnected else { return }
      self.pollTimer?.invalidate()
      self.pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
        self?.refreshWorkout()
      }
    }
  }

  private func stopTelemetryPoll() {
    DispatchQueue.main.async { [weak self] in
      self?.pollTimer?.invalidate()
      self?.pollTimer = nil
    }
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

  private func bindLiveStreams() {
    guard !isStreamsBound else { return }
    isStreamsBound = true

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

    // Heart rate alarm trigger notification (m.rate is threshold value triggering alarm)
    device.onNotifyHRMReal { [weak self] model, _ in
      guard let self = self, let m = model, m.rate > 0 else { return }
      self.currentBpm = Int(m.rate)
      self.pushTelemetry()
    }

    // Live real-time minute data stream (steps, dynamic/resting heart rate, calories)
    device.onNotifyCurrentData { [weak self] currentModel in
      guard let self = self, let m = currentModel else { return }
      if m.step > 0 { self.currentSteps = Int(m.step) }
      if m.calorie > 0 { self.currentCalories = Int(m.calorie) }
      if m.restingHeartRate > 0 {
        self.currentRhr = Int(m.restingHeartRate)
        self.currentRespiratoryRate = self.deriveRespiratoryRate(rhr: self.currentRhr, hrv: self.currentHrv)
      }
      if m.dynamicHeartRate > 0 { self.currentBpm = Int(m.dynamicHeartRate) }
      self.pushTelemetry()
    }

    // Live workout sport real data stream (continuous heart rate and motion during workout)
    device.onNotifySportRealData { [weak self] model, _ in
      guard let self = self, let m = model else { return }
      if m.heartRate > 0 { self.currentBpm = Int(m.heartRate) }
      if m.step > 0 { self.currentSteps = Int(m.step) }
      if m.calorie > 0 { self.currentCalories = Int(m.calorie) }
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
        if self.currentRhr > 0 {
          self.currentRespiratoryRate = self.deriveRespiratoryRate(rhr: self.currentRhr, hrv: self.currentHrv)
        }
        self.pushTelemetry()
      } else if type == .pressure {
        self.currentStressScore = Int(value)
        self.pushTelemetry()
      } else if type == .temperature {
        let tempC: Double = value > 1000 ? Double(value) / 100.0 : (value > 100 ? Double(value) / 10.0 : Double(value))
        if tempC >= 30.0 && tempC <= 45.0 {
          self.skinTempDeviation = round((tempC - 36.6) * 100.0) / 100.0
          self.pushTelemetry()
        }
      } else if type == .OXY {
        let oxy = Int(value)
        if oxy >= 70 && oxy <= 100 {
          self.currentBloodOxygen = oxy
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

    // Live body temperature notification
    device.onNotifyBodyTemperatureValueBlock { [weak self] time, state, value in
      guard let self = self, value > 0 else { return }
      let tempC: Double = value > 1000 ? Double(value) / 100.0 : (value > 100 ? Double(value) / 10.0 : Double(value))
      if tempC >= 30.0 && tempC <= 45.0 {
        self.skinTempDeviation = round((tempC - 36.6) * 100.0) / 100.0
        self.pushTelemetry()
      }
    }

    // Wearing state (off wrist): state 0 = off-wrist (снято), state 1 = on-wrist (надето)
    device.onNotifyOffWristBlock { [weak self] _, _, state in
      guard let self = self else { return }
      self.isOffWrist = (state == 0)
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

  // MARK: - UTEBluetoothDelegate

  func uteBluetoothStatus(_ status: UTEBluetoothStatus) {
    switch status.rawValue {
    case 0: // UTEBluetoothStatusOpen
      isSdkBluetoothReady = true
      let blocks = pendingSdkReadyBlocks
      pendingSdkReadyBlocks.removeAll()
      for b in blocks { b() }
    case 1, 2, 3, 4, 5: // Close, Resetting, Unsupported, Unauthorized, Unknown
      isSdkBluetoothReady = false
      if status.rawValue == 4 {
        resolvePendingConnect(success: false, errorMessage: "UTE SDK Bluetooth unauthorized")
      }
    default:
      break
    }
  }

  func uteDiscoverDevices(_ model: UTEModelDevice?) {
    guard let model = model else { return }
    let rawName = model.name ?? ""
    let cleanName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    let isKalkan = isKalkanDevice(cleanName)
    let displayName = !cleanName.isEmpty ? cleanName : (isKalkan ? "KALKAN СААТ-1" : "BLE Устройство")
    let addr = deviceAddress(model)
    if addr.isEmpty { return }

    if discoveredUteDevices.count >= 100 && discoveredUteDevices[addr] == nil {
      return
    }
    discoveredUteDevices[addr] = model
    if let id = model.identifier, !id.isEmpty {
      discoveredUteDevices[id] = model
    }
    if let mac = model.addressStr, !mac.isEmpty {
      discoveredUteDevices[mac] = model
    }
    DispatchQueue.main.async { [weak self] in
      self?.scanSink?([
        "name": displayName,
        "address": addr,
        "rssi": model.rssi,
        "isKalkan": isKalkan
      ])
    }

    // Auto-connect ONLY if this was an explicit pending connect target matching the exact address/identifier
    if let pending = pendingConnectAddress, !pending.isEmpty && !isConnected {
      let isMatch = addr.caseInsensitiveCompare(pending) == .orderedSame ||
                    model.identifier?.caseInsensitiveCompare(pending) == .orderedSame ||
                    model.addressStr?.caseInsensitiveCompare(pending) == .orderedSame
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
      if mgr.isScanning && !isScanning {
        mgr.stopScanDevices()
      }
      resolvePendingConnect(success: true)
      currentDeviceName = connectedModel?.name ?? "KALKAN СААТ-1"

      // Handshake: query supported services
      device.querySupportService([1, 5, 12, 14, 17]) { _ in }

      // Sync time
      let now = Int(Date().timeIntervalSince1970)
      let totalOffsetSec = TimeZone.current.secondsFromGMT()
      let timeZone = totalOffsetSec / 3600
      let minuteOffset = (abs(totalOffsetSec) % 3600) / 60
      device.setTimeClock(now, timeZone: timeZone, minuteOffset: minuteOffset) { _, _ in }

      bindLiveStreams()
      applyDeviceHardwareSettings()
      pullNightAndDay()
      startTelemetryPoll()
      refreshWorkout()
      pushTelemetry(immediate: true)

    case 4: // UTEDevicesStatusConnecting
      // Connection in progress; do not mark isConnected = true yet
      break

    case 5: // UTEDevicesStatusDisconnecting
      // Disconnection in progress; ignore to avoid dual reconnect race
      break

    case 1, 2, 3, -1: // Disconnected, ConnectingError, ConnectionTimedout, ConnectCheckFail
      var errorMsg = "UTE connection status error: \(status.rawValue)"
      if let nsError = error as NSError? {
        errorMsg += " (code: \(nsError.code), \(nsError.localizedDescription))"
        if nsError.code == 14 || nsError.code == 15 {
          errorMsg = "PEER_REMOVED_PAIRING: Please remove KALKAN from iOS Settings -> Bluetooth -> Forget This Device (code \(nsError.code))"
        }
      }
      resolvePendingConnect(success: false, errorMessage: errorMsg)
      isConnected = false
      connectedModel = nil
      isStreamsBound = false
      stopTelemetryPoll()
      currentBpm = 0
      isOffWrist = false
      skinTempDeviation = 0.0
      pendingConnectAddress = nil
      if mgr.isScanning && !isScanning {
        mgr.stopScanDevices()
      }
      // BLE-04: Preserve accumulated metrics: steps, calories, battery, hrv, rhr, sleep, hypnogram, deviceName
      pushTelemetry(immediate: true)

    default:
      // Unknown or sync/intermediate status (e.g. sync start/end) - do NOT disconnect!
      break
    }
  }

  func uteANCSAuthorization(_ ancsAuthorized: Bool) {
    isAncsAuthorized = ancsAuthorized
    pushTelemetry()
  }
}

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
    // Avoid double trigger with applicationDidBecomeActive
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
      result(false)
    }

    let healthChannel = FlutterMethodChannel(
      name: "sport.kalkan.biotracker/health",
      binaryMessenger: messenger
    )
    healthChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(KalkanHealthManager.shared.isAvailable())
      case "requestPermissions":
        KalkanHealthManager.shared.requestPermissions(result: result)
      case "exportWorkout":
        let args = (call.arguments as? [String: Any]) ?? [:]
        KalkanHealthManager.shared.exportWorkout(args: args, result: result)
      case "fetchNightSleepStages":
        let args = call.arguments as? [String: Any]
        KalkanHealthManager.shared.fetchNightSleepStages(args: args, result: result)
      case "getConnectedSources":
        KalkanHealthManager.shared.getConnectedSources(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
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
      case "resetFactory":
        KalkanBleManager.shared.resetFactory(result: result)
      case "configureHeartRateMonitoring":
        let interval = (call.arguments as? [String: Any])?["intervalMinutes"] as? Int ?? 15
        let continuous = (call.arguments as? [String: Any])?["continuous"] as? Bool ?? false
        KalkanBleManager.shared.configureHeartRateMonitoring(intervalMinutes: interval, continuous: continuous, result: result)
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
        let enable = (call.arguments as? [String: Any])?["enable"] as? Bool ?? true
        KalkanBleManager.shared.findDevice(enable: enable, result: result)
      case "measureHeartRate":
        KalkanBleManager.shared.measureHeartRate(result: result)
      case "syncTime":
        KalkanBleManager.shared.syncTime(result: result)
      case "setDisconnectRemind":
        let enable = (call.arguments as? [String: Any])?["enable"] as? Bool ?? true
        KalkanBleManager.shared.setDisconnectRemind(enable: enable, result: result)
      case "setSmartAlarm":
        let enable = (call.arguments as? [String: Any])?["enable"] as? Bool ?? false
        let hour = (call.arguments as? [String: Any])?["hour"] as? Int ?? 7
        let minute = (call.arguments as? [String: Any])?["minute"] as? Int ?? 0
        KalkanBleManager.shared.setSmartAlarm(enable: enable, hour: hour, minute: minute, result: result)
      case "setHydrationReminder":
        let enable = (call.arguments as? [String: Any])?["enable"] as? Bool ?? false
        let interval = (call.arguments as? [String: Any])?["intervalMinutes"] as? Int ?? 120
        KalkanBleManager.shared.setHydrationReminder(enable: enable, intervalMinutes: interval, result: result)
      case "setCallRemindEnable":
        let enable = (call.arguments as? [String: Any])?["enable"] as? Bool ?? true
        KalkanBleManager.shared.setCallRemindEnable(enable: enable, result: result)
      case "clearAccountData":
        KalkanBleManager.shared.clearAccountData(result: result)
      case "setUserProfile":
        let heightCm = (call.arguments as? [String: Any])?["heightCm"] as? Int ?? 175
        let weightKg = (call.arguments as? [String: Any])?["weightKg"] as? Int ?? 72
        let age = (call.arguments as? [String: Any])?["age"] as? Int ?? 28
        let gender = (call.arguments as? [String: Any])?["gender"] as? String ?? "male"
        let stepGoal = (call.arguments as? [String: Any])?["stepGoal"] as? Int ?? 10000
        let calorieGoal = (call.arguments as? [String: Any])?["calorieGoal"] as? Int ?? 650
        KalkanBleManager.shared.setUserProfile(heightCm: heightCm, weightKg: weightKg, age: age, gender: gender, stepGoal: stepGoal, calorieGoal: calorieGoal, result: result)
      case "getWorkoutHistory":
        KalkanBleManager.shared.getWorkoutHistory(result: result)
      case "pullNightAndDay", "syncSleepData":
        KalkanBleManager.shared.pullNightAndDay()
        result(true)
      case "getHeartRateHistory":
        KalkanBleManager.shared.getHeartRateHistory(result: result)
      case "isNotificationListenerGranted":
        result(KalkanBleManager.shared.isAncsAuthorized)
      case "openNotificationListenerSettings":
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
        } else {
          result(false)
        }
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

// MARK: - KalkanHealthManager (Apple HealthKit Integration)

class KalkanHealthManager: NSObject {
  static let shared = KalkanHealthManager()
  private let healthStore = HKHealthStore()

  func isAvailable() -> Bool {
    return HKHealthStore.isHealthDataAvailable()
  }

  func requestPermissions(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(false)
      return
    }

    var readTypes: Set<HKObjectType> = []
    if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      readTypes.insert(sleepType)
    }
    readTypes.insert(HKObjectType.workoutType())
    if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
      readTypes.insert(hrType)
    }
    if let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
      readTypes.insert(rhrType)
    }
    if let calType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
      readTypes.insert(calType)
    }

    var writeTypes: Set<HKSampleType> = []
    writeTypes.insert(HKObjectType.workoutType())
    if let calType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
      writeTypes.insert(calType)
    }

    healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
      DispatchQueue.main.async {
        result(success && error == nil)
      }
    }
  }

  func exportWorkout(args: [String: Any], result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(false)
      return
    }

    let sportId = args["sportId"] as? String ?? "other"
    let startTimeMs = args["startTimeMs"] as? Int ?? Int(Date().timeIntervalSince1970 * 1000)
    let durationSeconds = args["durationSeconds"] as? Int ?? 0
    let calories = args["calories"] as? Double ?? Double(args["calories"] as? Int ?? 0)
    let distanceMeters = args["distanceMeters"] as? Double ?? 0.0

    let startDate = Date(timeIntervalSince1970: Double(startTimeMs) / 1000.0)
    let endDate = startDate.addingTimeInterval(Double(durationSeconds))

    let activityType: HKWorkoutActivityType
    switch sportId.lowercased() {
    case "running", "run", "runoutdoor", "runtreadmill":
      activityType = .running
    case "cycling", "cycle", "cyclingoutdoor", "cyclingindoor":
      activityType = .cycling
    case "swimming", "swim", "swimmingpool", "swimmingopenwater":
      activityType = .swimming
    case "walking", "walk", "walkoutdoor":
      activityType = .walking
    case "hiit", "crossfit":
      activityType = .highIntensityIntervalTraining
    case "yoga":
      activityType = .yoga
    case "strength", "gym":
      activityType = .traditionalStrengthTraining
    default:
      activityType = .other
    }

    let energyBurned = calories > 0 ? HKQuantity(unit: .kilocalorie(), doubleValue: calories) : nil
    let distance = distanceMeters > 0 ? HKQuantity(unit: .meter(), doubleValue: distanceMeters) : nil

    let workout = HKWorkout(
      activityType: activityType,
      start: startDate,
      end: endDate,
      duration: Double(durationSeconds),
      totalEnergyBurned: energyBurned,
      totalDistance: distance,
      metadata: [HKMetadataKeyWorkoutBrandName: "KALKAN SPORT"]
    )

    healthStore.save(workout) { success, error in
      DispatchQueue.main.async {
        result(success && error == nil)
      }
    }
  }

  func fetchNightSleepStages(args: [String: Any]?, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
      result(nil)
      return
    }

    let now = Date()
    let calendar = Calendar.current
    let targetDateMs = args?["targetDateMs"] as? Int
    let baseDate = targetDateMs != nil ? Date(timeIntervalSince1970: Double(targetDateMs!) / 1000.0) : now

    // Window: 6:00 PM previous day to 2:00 PM target day
    var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
    components.hour = 14
    components.minute = 0
    let windowEnd = calendar.date(from: components) ?? baseDate
    let windowStart = calendar.date(byAdding: .hour, value: -20, to: windowEnd) ?? baseDate.addingTimeInterval(-20 * 3600)

    let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

    let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
      guard let catSamples = samples as? [HKCategorySample], !catSamples.isEmpty, error == nil else {
        DispatchQueue.main.async { result(nil) }
        return
      }

      var deepMinutes = 0
      var remMinutes = 0
      var lightMinutes = 0
      var awakeMinutes = 0
      var firstSleep: Date?
      var lastSleep: Date?

      for s in catSamples {
        let dur = Int(s.endDate.timeIntervalSince(s.startDate) / 60.0)
        if dur <= 0 { continue }

        if #available(iOS 16.0, *) {
          switch s.value {
          case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            deepMinutes += dur
            firstSleep = firstSleep == nil ? s.startDate : min(firstSleep!, s.startDate)
            lastSleep = lastSleep == nil ? s.endDate : max(lastSleep!, s.endDate)
          case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            remMinutes += dur
            firstSleep = firstSleep == nil ? s.startDate : min(firstSleep!, s.startDate)
            lastSleep = lastSleep == nil ? s.endDate : max(lastSleep!, s.endDate)
          case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            lightMinutes += dur
            firstSleep = firstSleep == nil ? s.startDate : min(firstSleep!, s.startDate)
            lastSleep = lastSleep == nil ? s.endDate : max(lastSleep!, s.endDate)
          case HKCategoryValueSleepAnalysis.awake.rawValue:
            awakeMinutes += dur
          default:
            lightMinutes += dur
            firstSleep = firstSleep == nil ? s.startDate : min(firstSleep!, s.startDate)
            lastSleep = lastSleep == nil ? s.endDate : max(lastSleep!, s.endDate)
          }
        } else {
          if s.value == HKCategoryValueSleepAnalysis.awake.rawValue {
            awakeMinutes += dur
          } else {
            lightMinutes += dur
            firstSleep = firstSleep == nil ? s.startDate : min(firstSleep!, s.startDate)
            lastSleep = lastSleep == nil ? s.endDate : max(lastSleep!, s.endDate)
          }
        }
      }

      let sleepMins = deepMinutes + remMinutes + lightMinutes
      let totalMins = sleepMins + awakeMinutes
      if sleepMins == 0 {
        DispatchQueue.main.async { result(nil) }
        return
      }

      let efficiency = totalMins > 0 ? Double(sleepMins) / Double(totalMins) : 1.0
      let startTs = Int((firstSleep ?? windowStart).timeIntervalSince1970 * 1000)
      let endTs = Int((lastSleep ?? windowEnd).timeIntervalSince1970 * 1000)

      let res: [String: Any] = [
        "deepMinutes": deepMinutes,
        "remMinutes": remMinutes,
        "lightMinutes": lightMinutes,
        "awakeMinutes": awakeMinutes,
        "totalMinutes": sleepMins,
        "efficiency": efficiency,
        "sleepStartMs": startTs,
        "sleepEndMs": endTs
      ]

      DispatchQueue.main.async {
        result(res)
      }
    }

    self.healthStore.execute(query)
  }

  func getConnectedSources(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result([])
      return
    }
    result(["Apple Health (HealthKit)"])
  }
}

