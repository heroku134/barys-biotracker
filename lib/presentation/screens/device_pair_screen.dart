import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../widgets/circa_band_radar.dart';
import '../widgets/glass_card.dart';
import '../widgets/kalkan_ui.dart';

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
  bool _showAllDevices = false;
  List<DiscoveredBleDevice> _devices = [];
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    _isBluetoothEnabled = widget.bleBridge.isBluetoothEnabledNotifier.value;
    widget.bleBridge.isBluetoothEnabledNotifier.addListener(_onBluetoothStateChanged);
    _checkAndStart();
  }

  void _onBluetoothStateChanged() {
    if (!mounted) return;
    final enabled = widget.bleBridge.isBluetoothEnabledNotifier.value;
    if (_isBluetoothEnabled != enabled) {
      setState(() => _isBluetoothEnabled = enabled);
      if (enabled && !_isScanning) {
        _checkAndStart();
      }
    }
  }

  Future<void> _checkAndStart() async {
    // 1. Проверяем Bluetooth
    final btEnabled = await widget.bleBridge.isBluetoothEnabled();
    if (!mounted) return;
    setState(() => _isBluetoothEnabled = btEnabled);

    if (!btEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.rose,
          content: Text(
            'Внимание: Bluetooth выключен на телефоне. Включите Bluetooth для поиска часов.',
            style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    // 2. Проверяем геолокацию (критично для Android <12)
    final locEnabled = await widget.bleBridge.isLocationServiceEnabled();
    if (!locEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.rose,
          content: const Text(
            'Для поиска BLE-устройств необходимо включить службы геолокации.',
            style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
          ),
          action: SnackBarAction(
            label: 'Включить',
            textColor: Colors.white,
            onPressed: () => widget.bleBridge.openLocationSettings(),
          ),
        ),
      );
      return;
    }

    // 3. Проверяем и запрашиваем разрешения
    final status = await widget.bleBridge.checkPermissionStatus();
    if (status != BlePermissionStatus.granted) {
      final reqStatus = await widget.bleBridge.requestPermissionStatus();
      if (!mounted) return;
      if (reqStatus == BlePermissionStatus.permanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.rose,
            content: const Text(
              'Разрешение на Bluetooth отключено. Предоставьте доступ в настройках.',
              style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
            ),
            action: SnackBarAction(
              label: 'Настройки',
              textColor: Colors.white,
              onPressed: () => widget.bleBridge.openAppSettings(),
            ),
          ),
        );
        return;
      } else if (reqStatus != BlePermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.rose,
            content: Text(
              'Для поиска часов необходимо предоставить разрешение на доступ к Bluetooth.',
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
    if (_isScanning) return;
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

    try {
      await widget.bleBridge.startScan();
    } catch (_) {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }

    // Автоматический останов анимации и нативного сканирования через 15 секунд
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isScanning) {
        widget.bleBridge.stopScan();
        setState(() => _isScanning = false);
      }
    });
  }

  Future<void> _connect(DiscoveredBleDevice device) async {
    // Останавливаем нативный скан перед соединением для чистоты радиоэфира
    await widget.bleBridge.stopScan();
    if (mounted) setState(() => _isScanning = false);

    setState(() {
      _isConnecting = true;
      _connectingAddress = device.address;
    });

    final connected = await widget.bleBridge.connect(device.address);

    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _connectingAddress = null;
    });

    if (connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.sage, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Часы ${device.name.isNotEmpty ? device.name : "СААТ-1"} успешно подключены',
                  style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.rose, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Не удалось установить соединение. Убедитесь, что часы заряжены и находятся рядом.',
                  style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
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
    widget.bleBridge.isBluetoothEnabledNotifier.removeListener(_onBluetoothStateChanged);
    _scanSub?.cancel();
    widget.bleBridge.stopScan();
    super.dispose();
  }

  Widget _buildDeviceCard(DiscoveredBleDevice dev) {
    final isItemConnecting = _isConnecting && _connectingAddress == dev.address;
    final displayName = dev.name.isNotEmpty
        ? dev.name
        : (dev.isKalkanBand ? 'KALKAN СААТ-1' : 'BLE Устройство');

    return GlassCard(
      onTap: _isConnecting ? null : () => _connect(dev),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dev.isKalkanBand
                  ? AppColors.sage.withValues(alpha: 0.15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
              border: Border.all(
                color: dev.isKalkanBand
                    ? AppColors.sage.withValues(alpha: 0.3)
                    : AppColors.line,
                width: KalkanUi.hairline,
              ),
            ),
            child: Icon(
              _getRssiIcon(dev.rssi),
              color: _getRssiColor(dev.rssi),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: AppColors.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (dev.isKalkanBand) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.sage.withValues(alpha: 0.3), width: KalkanUi.hairline),
                        ),
                        child: const Text(
                          'KALKAN',
                          style: TextStyle(
                            color: AppColors.sage,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      dev.address,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: AppColors.faint, fontSize: 11)),
                    const SizedBox(width: 8),
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
          const SizedBox(width: 8),
          isItemConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
                )
              : const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDevices = _devices.isNotEmpty;
    final kalkanDevices = _devices.where((d) => d.isKalkanBand).toList();
    final otherDevices = _devices.where((d) => !d.isKalkanBand).toList();

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
          padding: const EdgeInsets.symmetric(horizontal: KalkanUi.pagePadding, vertical: 12),
          child: Column(
            children: [
              if (!_isBluetoothEnabled)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(KalkanUi.cardRadius),
                    border: Border.all(color: AppColors.rose.withValues(alpha: 0.4), width: KalkanUi.hairline),
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
                    ? ListView(
                        children: [
                          if (kalkanDevices.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 2),
                              child: Row(
                                children: [
                                  const Text(
                                    'УСТРОЙСТВА KALKAN',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${kalkanDevices.length})',
                                    style: const TextStyle(color: AppColors.faint, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            ...kalkanDevices.map((d) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildDeviceCard(d),
                                )),
                          ],
                          if (otherDevices.isNotEmpty) ...[
                            if (kalkanDevices.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Center(
                                  child: TextButton.icon(
                                    onPressed: () => setState(() => _showAllDevices = !_showAllDevices),
                                    icon: Icon(
                                      _showAllDevices ? Icons.expand_less : Icons.expand_more,
                                      size: 16,
                                      color: AppColors.muted,
                                    ),
                                    label: Text(
                                      _showAllDevices
                                          ? 'Скрыть сторонние устройства'
                                          : 'Показать все устройства (${otherDevices.length})',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_showAllDevices || kalkanDevices.isEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 6),
                                child: Row(
                                  children: [
                                    const Text(
                                      'ДРУГИЕ BLE УСТРОЙСТВА',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${otherDevices.length})',
                                      style: const TextStyle(color: AppColors.faint, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              ...otherDevices.map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildDeviceCard(d),
                                  )),
                            ],
                          ],
                        ],
                      )
                    : Center(
                        child: Text(
                          _isScanning
                              ? 'Идет поиск устройств KALKAN по Bluetooth...'
                              : 'В радиусе действия устройства не обнаружены.\nНажмите «Искать снова».',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
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
                        minimumSize: const Size(44, KalkanUi.minTapTarget),
                        side: BorderSide(color: AppColors.line, width: KalkanUi.hairline),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
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
