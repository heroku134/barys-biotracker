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
  bool _deviceFound = true; // Для демонстрации браслет найден
  bool _isConnecting = false;
  final String _selectedDevice = 'CIRCA One (CR-A1-084B21)';

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _deviceFound = false;
    });

    widget.bleBridge.startScan();

    // Симуляция поиска эфира BLE
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      setState(() {
        _isScanning = false;
        _deviceFound = true;
      });
    }
  }

  Future<void> _connect(bool isDemo) async {
    setState(() => _isConnecting = true);
    await widget.bleBridge.connect('CR-A1-084B21');
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _isConnecting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.sage, size: 20),
            const SizedBox(width: 10),
            Text(
              isDemo ? 'Демо-браслет подключен' : 'Браслет CIRCA One на связи (BLE 5.3)',
              style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stage,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BLUETOOTH BLE',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              'Поиск браслета',
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Анимированный радар CIRCA
              Center(
                child: CircaBandRadar(
                  size: 200,
                  isScanning: _isScanning,
                  isConnected: widget.bleBridge.currentTelemetry.isConnected,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _isScanning
                    ? 'СКАНИРОВАНИЕ РАДИОЭФИРА...'
                    : (_deviceFound ? 'НАЙДЕНО УСТРОЙСТВО' : 'УСТРОЙСТВО НЕ НАЙДЕНО'),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'CIRCA One — ультраминималистичный браслет без дисплея. Поднесите датчики к смартфону.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Список найденных устройств
              Expanded(
                child: ListView(
                  children: [
                    if (_deviceFound)
                      GlassCard(
                        onTap: () => _connect(false),
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
                              child: const Icon(Icons.bluetooth_searching, color: AppColors.sage, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDevice,
                                    style: const TextStyle(
                                      color: AppColors.fg,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Row(
                                    children: [
                                      Text(
                                        'Сигнал: −54 dBm',
                                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                                      ),
                                      SizedBox(width: 8),
                                      Text('•', style: TextStyle(color: AppColors.faint, fontSize: 11)),
                                      SizedBox(width: 8),
                                      Text(
                                        'UTE Nordic SDK',
                                        style: TextStyle(color: AppColors.sage, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _isConnecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
                                  )
                                : const Icon(Icons.chevron_right, color: AppColors.muted),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Кнопки действий
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _startScan,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _isScanning ? 'ПОИСК В ЭФИРЕ...' : 'ИСКАТЬ СНОВА',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.fg,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _connect(true),
                      icon: const Icon(Icons.bolt, color: AppColors.stage, size: 18),
                      label: const Text(
                        'ПОДКЛЮЧИТЬ FAKE WATCH MODE',
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
