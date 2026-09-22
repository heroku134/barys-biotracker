import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../data/services/paired_pulse.dart';
import '../../core/app_language.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/demo_mode_store.dart';
import '../widgets/glass_card.dart';
import 'device_pair_screen.dart';
import 'firmware_update_screen.dart';

class DeviceSettingsScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const DeviceSettingsScreen({super.key, required this.bleBridge});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  bool _antiLoss = true;
  bool _disconnectAlert = true;
  bool _smartAlarm = true;
  bool _hydrationReminder = true;
  bool _isMeasuringHr = false;

  void _findWatch() {
    PairedPulse.play(widget.bleBridge, kind: PairedPulseKind.find);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
        SnackBar(
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
            Icon(Icons.sync, color: AppColors.sage, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Время и часовой пояс синхронизированы (${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')})',
                style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
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
        title: Text(tr('Сброс до заводских настроек?', 'Баштапкы абалга кайтаруу?'), style: TextStyle(color: AppColors.fg, fontSize: 16)),
        content: Text(
          'Все несохраненные кэшированные данные на браслете будут очищены, а связь разорвана.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('Отмена', 'Жок'), style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.bleBridge.disconnect();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surface,
                  content: Text('Браслет сброшен до заводских настроек', style: TextStyle(color: AppColors.rose)),
                ),
              );
            },
            child: Text(tr('Сбросить', 'Кайтаруу'), style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  bool get _ru => AppLocaleNotifier.current != AppLanguage.kyrgyz;
  String tr(String r, String k) => _ru ? r : k;

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;

    return Scaffold(
      backgroundColor: AppColors.stage,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.fg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Часы', 'Саат'),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              tr('Часы КАЛКАН СААТ-1', 'КАЛКАН СААТ-1 сааты'),
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.bluetooth_searching, color: AppColors.amber),
            tooltip: tr('Поиск другого браслета', 'Башка билерикти издөө'),
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
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              telemetry.deviceName,
                              style: TextStyle(
                                color: AppColors.fg,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              telemetry.isConnected ? tr('На связи', 'Туташкан') : tr('Отключено', 'Өчүк'),
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
                            Icon(Icons.battery_charging_full, color: AppColors.sage, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '${telemetry.batteryLevel}%',
                              style: TextStyle(
                                color: AppColors.sage,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Divider(color: AppColors.line, height: 1),
                  SizedBox(height: 12),
                  InkWell(
                    onTap: () => FirmwareUpdateScreen.open(context, watchBattery: telemetry.batteryLevel),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(tr('Прошивка: v1.2.4', 'Прошивка: v1.2.4'), style: TextStyle(color: AppColors.muted, fontSize: 11)),
                              SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  'v1.3.0 OTA',
                                  style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(tr('Обновить', 'Жаңыртуу'), style: const TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios, size: 9, color: AppColors.amber),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),

            // Кнопка поиска часов (Вибрация)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _findWatch,
                icon: Icon(Icons.vibration, size: 18),
                label: Text(
                  tr('Найти браслет', 'Билерикти табуу'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: -0.1),
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
            SizedBox(height: 20),

            Text(
              tr('Функции часов', 'Сааттын функциялары'),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 10),

            // Fake Watch Mode
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt, color: AppColors.amber, size: 16),
                            SizedBox(width: 6),
                            Text(
                              tr('Демо-режим', 'Демо режим'),
                              style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr('Эмуляция сенсоров без часов', 'Сенсорлорду эмуляциялоо'),
                          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: DemoModeStore.enabled.value,
                    activeThumbColor: AppColors.amber,
                    onChanged: (val) async {
                      await DemoModeStore.setEnabled(val);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text(
                            val ? tr('Эмуляция включена', 'Эмуляция күйдү') : tr('Физические часы', 'Чыныгы саат'),
                            style: TextStyle(color: AppColors.fg),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),

            // Антипотеря (Anti-loss)
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Антипотеря', 'Жоготууга каршы'),
                          style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr('Сигнал, если браслет дальше 10 метров', 'Билерик 10 метрден алыс болсо сигнал'),
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
            SizedBox(height: 10),

            // Оповещение об отключении BLE
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Оповещение об отключении', 'Үзүлгөндө эскертме'),
                          style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr('Пуш при разрыве Bluetooth', 'Bluetooth үзүлгөндө билдирме'),
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
            SizedBox(height: 10),

            // Умный будильник
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Умный будильник', 'Акылдуу ойготкуч'),
                          style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr('Вибрация в лёгкой фазе сна', 'Жеңил уйку фазасында титирөө'),
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
            SizedBox(height: 10),

            // Напоминание о воде
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Напоминание пить воду', 'Суу ичүү эскертмеси'),
                          style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr('Вибрация каждые 2 часа', 'Ар 2 саатта титирөө'),
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
            SizedBox(height: 14),

            // Ручные действия: Замер пульса и Синхронизация времени
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isMeasuringHr ? null : _triggerHrMeasurement,
                    icon: _isMeasuringHr
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose),
                          )
                        : Icon(Icons.favorite, color: AppColors.rose, size: 16),
                    label: Text(
                      _isMeasuringHr ? tr('Измерение…', 'Өлчөө…') : tr('Замер пульса', 'Пульсту өлчөө'),
                      style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _syncTime,
                    icon: Icon(Icons.access_time, color: AppColors.sage, size: 16),
                    label: Text(
                      tr('Синхр. время', 'Убакытты шайкештирүү'),
                      style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),

            // Сброс до заводских настроек
            Center(
              child: TextButton.icon(
                onPressed: _confirmReset,
                icon: Icon(Icons.restore, color: AppColors.rose, size: 16),
                label: Text(
                  tr('Сбросить браслет', 'Билерикти баштапкы абалга'),
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
