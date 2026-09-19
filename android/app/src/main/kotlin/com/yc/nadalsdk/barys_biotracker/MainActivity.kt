package com.yc.nadalsdk.barys_biotracker

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.yc.nadalsdk.bean.Notify
import com.yc.nadalsdk.ble.open.UteBleClient
import com.yc.nadalsdk.ble.open.UteBleConnection
import com.yc.nadalsdk.ble.open.UteBleDevice
import com.yc.nadalsdk.listener.BleConnectStateListener
import com.yc.nadalsdk.listener.DeviceNotifyListener
import com.yc.nadalsdk.scan.UteScanCallback
import com.yc.nadalsdk.scan.UteScanDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.nadal.ble/methods"
    private val EVENT_CHANNEL = "com.nadal.ble/telemetry"

    private var uteBleClient: UteBleClient? = null
    private var uteBleConnection: UteBleConnection? = null
    private var telemetryEventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var currentBpm: Int = 72
    private var currentSteps: Int = 6840
    private var currentCalories: Int = 420
    private var currentBattery: Int = 84
    private var currentDeviceName: String = "UTE Watch"
    private var isConnected: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            uteBleClient = UteBleClient.initialize(applicationContext)
            uteBleConnection = uteBleClient?.getUteBleConnection()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. MethodChannel для команд управления
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "startScan" -> {
                        startBleScan(result)
                    }
                    "stopScan" -> {
                        uteBleClient?.cancelScan()
                        result.success(true)
                    }
                    "connect" -> {
                        val address = call.argument<String>("address")
                        if (!address.isNullOrEmpty()) {
                            connectDevice(address, result)
                        } else {
                            result.error("INVALID_ADDRESS", "Device address is null", null)
                        }
                    }
                    "disconnect" -> {
                        uteBleClient?.disconnect()
                        isConnected = false
                        pushTelemetry()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. EventChannel для непрерывного потока телеметрии в Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    telemetryEventSink = events
                    setupDeviceListeners()
                    pushTelemetry()
                }

                override fun onCancel(arguments: Any?) {
                    telemetryEventSink = null
                }
            })
    }

    private fun startBleScan(result: MethodChannel.Result) {
        if (uteBleClient == null) {
            result.error("NOT_INITIALIZED", "UteBleClient is null", null)
            return
        }

        uteBleClient?.scanDevice(object : UteScanCallback {
            override fun onScanning(scanDevice: UteScanDevice?) {
                // Устройство найдено в эфире
            }

            override fun onScanComplete(scanDevices: MutableList<UteScanDevice?>?) {
                // Сканирование завершено
            }

            override fun onScanFailed(errorCode: Int) {
                // Ошибка сканирования
            }
        }, 15000L)
        result.success(true)
    }

    private fun connectDevice(address: String, result: MethodChannel.Result) {
        uteBleConnection = uteBleClient?.getUteBleConnection()
        uteBleConnection?.setConnectStateListener(object : BleConnectStateListener {
            override fun onConnecteStateChange(state: Int) {
                when (state) {
                    BleConnectStateListener.STATE_CONNECTED -> {
                        isConnected = true
                        currentDeviceName = "UTE Barys Watch"
                        pushTelemetry()
                    }
                    BleConnectStateListener.STATE_DISCONNECTED -> {
                        isConnected = false
                        pushTelemetry()
                    }
                }
            }
        })

        uteBleConnection = uteBleClient?.connect(address)
        result.success(true)
    }

    private fun setupDeviceListeners() {
        uteBleConnection?.setDeviceNotifyListener(object : DeviceNotifyListener {
            override fun onNotify(device: UteBleDevice, notify: Notify) {
                // Обработка данных с датчиков браслета
                pushTelemetry()
            }
        })
    }

    private fun pushTelemetry() {
        mainHandler.post {
            val telemetry = mapOf(
                "heartRate" to currentBpm,
                "steps" to currentSteps,
                "calories" to currentCalories,
                "batteryLevel" to currentBattery,
                "hrv" to 65.0,
                "sleepMinutes" to 450,
                "deepSleepMinutes" to 110,
                "isConnected" to isConnected,
                "deviceName" to currentDeviceName
            )
            telemetryEventSink?.success(telemetry)
        }
    }
}
