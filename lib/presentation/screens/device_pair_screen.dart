import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../widgets/circa_band_radar.dart';
import '../widgets/glass_card.dart';

class DevicePairScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const DevicePairScreen({super.key, required this.bleBridge});

  @override
  State<DevicePairScreen> createState() => _DevicePairScreenState();
}

class _DevicePairScreenState extends State<DevicePairScreen> {
  bool _isScanning = false;
  bool _isBluetoothEnabled = true;
  bool _isConnecting = false;
  String? _connectingAddress;
  List<DiscoveredBleDevice> _devices = [];
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    _checkAndStart();
  }

  Future<void> _checkAndStart() async {
    // 1. Проверяем Bluetooth
    final btEnabled = await widget.bleBridge.isBluetoothEnabled();
    if (!mounted) return;
    setState(() => _isBluetoothEnabled = btEnabled);

    if (!btEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.rose,
          content: Text(
            'Внимание: Bluetooth выключен на телефоне. Включите Bluetooth для поиска часов.',
            style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    // 2. Проверяем и запрашиваем разрешения
    final hasPerms = await widget.bleBridge.checkPermissions();
    if (!hasPerms) {
      final granted = await widget.bleBridge.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.rose,
            content: Text(
              'Для поиска часов необходимо предоставить разрешение на доступ к Bluetooth и геолокации.',
              style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
            ),
          ),
        );
        return;
      }
    }

    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices = widget.bleBridge.discoveredDevices;
    });

    _scanSub?.cancel();
    _scanSub = widget.bleBridge.scanResultsStream.listen((list) {
      if (mounted) {
        setState(() {
          _devices = list;
        });
      }
    });

    await widget.bleBridge.startScan();

    // Автоматический останов анимации сканирования через 15 секунд
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isScanning) {
        setState(() => _isScanning = false);
      }
    });
  }

  Future<void> _connect(DiscoveredBleDevice? device, bool isDemo) async {
    setState(() {
      _isConnecting = true;
      _connectingAddress = isDemo ? 'DEMO-CIRC-01' : device?.address;
    });

    if (isDemo) {
      widget.bleBridge.activateSimulatorMode();
      await Future.delayed(const Duration(milliseconds: 600));
    } else if (device != null) {
      await widget.bleBridge.connect(device.address);
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _connectingAddress = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.sage, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                isDemo
                    ? 'Демо-часы успешно подключены (Симулятор)'
                    : 'Часы ${device?.name ?? "СААТ-1"} подключены по BLE 5.3!',
                style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  IconData _getRssiIcon(int rssi) {
    if (rssi >= -65) return Icons.network_cell;
    if (rssi >= -80) return Icons.network_cell;
    return Icons.network_cell_outlined;
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -65) return AppColors.sage;
    if (rssi >= -80) return AppColors.amber;
    return AppColors.muted;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    widget.bleBridge.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDevices = _devices.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.stage,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Поиск браслета',
          style: TextStyle(
            color: AppColors.fg,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              if (!_isBluetoothEnabled)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bluetooth_disabled, color: AppColors.rose, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bluetooth выключен. Пожалуйста, включите его в настройках телефона.',
                          style: TextStyle(color: AppColors.fg, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 10),
              // Анимированный радар поиска
              Center(
                child: CircaBandRadar(
                  size: 190,
                  isScanning: _isScanning,
                  isConnected: widget.bleBridge.currentTelemetry.isConnected,
                ),
              ),
              SizedBox(height: 14),

              Text(
                _isScanning
                    ? 'СКАНИРОВАНИЕ РАДИОЭФИРА...'
                    : (hasDevices ? 'НАЙДЕНЫ УСТРОЙСТВА (${_devices.length})' : 'УСТРОЙСТВА НЕ НАЙДЕНЫ'),
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Включите часы и поднесите их близко к смартфону.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 18),

              // Список найденных устройств
              Expanded(
                child: hasDevices
                    ? ListView.separated(
                        itemCount: _devices.length,
                        separatorBuilder: (context, index) => SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final dev = _devices[index];
                          final isItemConnecting = _isConnecting && _connectingAddress == dev.address;

                          return GlassCard(
                            onTap: _isConnecting ? null : () => _connect(dev, false),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.sage.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.sage.withValues(alpha: 0.3)),
                                  ),
                                  child: Icon(
                                    _getRssiIcon(dev.rssi),
                                    color: _getRssiColor(dev.rssi),
                                    size: 22,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dev.name.isNotEmpty ? dev.name : 'UTE Smart Watch',
                                        style: TextStyle(
                                          color: AppColors.fg,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            dev.address,
                                            style: TextStyle(color: AppColors.muted, fontSize: 11),
                                          ),
                                          SizedBox(width: 8),
                                          Text('•', style: TextStyle(color: AppColors.faint, fontSize: 11)),
                                          SizedBox(width: 8),
                                          Text(
                                            '${dev.rssi} dBm',
                                            style: TextStyle(
                                              color: _getRssiColor(dev.rssi),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                isItemConnecting
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
                                      )
                                    : Icon(Icons.chevron_right, color: AppColors.muted),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          _isScanning
                              ? 'Идет поиск UTE / KALKAN устройств по Bluetooth...'
                              : 'В радиусе действия устройства не обнаружены.\nНажмите «Искать снова».',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
                        ),
                      ),
              ),

              // Кнопки действий
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _checkAndStart,
                      icon: Icon(Icons.refresh, size: 18),
                      label: Text(
                        _isScanning ? 'ПОИСК В ЭФИРЕ...' : 'ИСКАТЬ СНОВА',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.fg,
                        side: BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting ? null : () => _connect(null, true),
                      icon: Icon(Icons.bolt, color: AppColors.stage, size: 18),
                      label: Text(
                        'ПОДКЛЮЧИТЬ ДЕМО-РЕЖИМ (СИМУЛЯТОР)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: AppColors.stage,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
