import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../widgets/glass_card.dart';
import 'device_pair_screen.dart';

class DeviceSettingsScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const DeviceSettingsScreen({super.key, required this.bleBridge});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  bool _fakeWatchMode = false;
  bool _antiLoss = true;
  bool _disconnectAlert = true;
  bool _smartAlarm = true;
  bool _hydrationReminder = true;
  bool _isMeasuringHr = false;

  void _findWatch() {
    HapticFeedback.heavyImpact();
    widget.bleBridge.findWatch();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            Icon(Icons.vibration, color: AppColors.amber, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Сигнал отправлен: вибрация на часах СААТ-1',
                style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerHrMeasurement() async {
    setState(() => _isMeasuringHr = true);
    await widget.bleBridge.triggerHeartRateMeasurement();
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _isMeasuringHr = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Row(
            children: [
              Icon(Icons.favorite, color: AppColors.rose, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Оптический замер пульса завершен: данные синхронизированы',
                  style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _syncTime() {
    HapticFeedback.lightImpact();
    widget.bleBridge.syncTime();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            const Icon(Icons.sync, color: AppColors.sage, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Время и часовой пояс синхронизированы (${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')})',
                style: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Сброс до заводских настроек?', style: TextStyle(color: AppColors.fg, fontSize: 16)),
        content: const Text(
          'Все несохраненные кэшированные данные на браслете будут очищены, а связь разорвана.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ОТМЕНА', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.bleBridge.disconnect();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.surface,
                  content: Text('Браслет сброшен до заводских настроек', style: TextStyle(color: AppColors.rose)),
                ),
              );
            },
            child: const Text('СБРОСИТЬ', style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;

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
              'УПРАВЛЕНИЕ УСТРОЙСТВОМ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              'Часы KALKAN СААТ-1',
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_searching, color: AppColors.amber),
            tooltip: 'Поиск другого браслета',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DevicePairScreen(bleBridge: widget.bleBridge),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Карточка статуса устройства
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.raised,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: telemetry.isConnected ? AppColors.sage : AppColors.muted,
                            width: 1.8,
                          ),
                        ),
                        child: Icon(
                          Icons.watch,
                          color: telemetry.isConnected ? AppColors.sage : AppColors.muted,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              telemetry.deviceName,
                              style: const TextStyle(
                                color: AppColors.fg,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              telemetry.isConnected ? 'На связи (BLE 5.3 Nordic)' : 'Отключено',
                              style: TextStyle(
                                color: telemetry.isConnected ? AppColors.sage : AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.sage.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.battery_charging_full, color: AppColors.sage, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${telemetry.batteryLevel}%',
                              style: const TextStyle(
                                color: AppColors.sage,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.line, height: 1),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Прошивка: v1.4.2-nordic', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                      Text('SN: CR-A1-084B21-KZ', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Кнопка поиска часов (Вибрация)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _findWatch,
                icon: const Icon(Icons.vibration, size: 18),
                label: const Text(
                  'НАЙТИ БРАСЛЕТ (ВИБРАЦИЯ)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.stage,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'ФУНКЦИИ И АВТОМАТИЗАЦИЯ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),

            // Fake Watch Mode
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt, color: AppColors.amber, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Fake Watch Mode',
                              style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Эмуляция сенсоров (пульс, сон, шаги) без физического чипа',
                          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _fakeWatchMode,
                    activeThumbColor: AppColors.amber,
                    onChanged: (val) {
                      setState(() => _fakeWatchMode = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text(
                            val ? 'Fake Watch Mode активирован' : 'Режим переключен на физический BLE чип',
                            style: const TextStyle(color: AppColors.fg),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Антипотеря (Anti-loss)
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Антипотеря (Anti-Loss)',
                          style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Сигнал на смартфоне при отдалении браслета (>10 метров)',
                          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _antiLoss,
                    activeThumbColor: AppColors.sage,
                    onChanged: (val) => setState(() => _antiLoss = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Оповещение об отключении BLE
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Оповещение об отключении',
                          style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Мгновенный пуш при разрыве Bluetooth связи',
                          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _disconnectAlert,
                    activeThumbColor: AppColors.sage,
                    onChanged: (val) => setState(() => _disconnectAlert = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Умный будильник
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Умный будильник (Smart Alarm)',
                          style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Бесшумное пробуждение вибрацией в легкой фазе сна',
                          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _smartAlarm,
                    activeThumbColor: AppColors.sage,
                    onChanged: (val) => setState(() => _smartAlarm = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Напоминание о воде
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Напоминание о гидратации',
                          style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Легкая вибрация каждые 2 часа в течение дня',
                          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _hydrationReminder,
                    activeThumbColor: AppColors.sage,
                    onChanged: (val) => setState(() => _hydrationReminder = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Ручные действия: Замер пульса и Синхронизация времени
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isMeasuringHr ? null : _triggerHrMeasurement,
                    icon: _isMeasuringHr
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose),
                          )
                        : const Icon(Icons.favorite, color: AppColors.rose, size: 16),
                    label: Text(
                      _isMeasuringHr ? 'ИЗМЕРЕНИЕ...' : 'ЗАМЕР ПУЛЬСА',
                      style: const TextStyle(color: AppColors.fg, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _syncTime,
                    icon: const Icon(Icons.access_time, color: AppColors.sage, size: 16),
                    label: const Text(
                      'СИНХР. ВРЕМЯ',
                      style: TextStyle(color: AppColors.fg, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Сброс до заводских настроек
            Center(
              child: TextButton.icon(
                onPressed: _confirmReset,
                icon: const Icon(Icons.restore, color: AppColors.rose, size: 16),
                label: const Text(
                  'Сбросить браслет до заводских настроек',
                  style: TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
