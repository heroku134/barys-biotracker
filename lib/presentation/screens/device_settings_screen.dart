import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../data/services/paired_pulse.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../widgets/kalkan_ui.dart';
import '../widgets/kalkan_chrome.dart';
import 'device_pair_screen.dart';


class DeviceSettingsScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const DeviceSettingsScreen({super.key, required this.bleBridge});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  bool _antiLoss = true;
  bool _callAlert = true;
  bool _notificationAccessGranted = true;
  bool _isMeasuringHr = false;
  int _hrIntervalMinutes = 15;
  bool _continuousHr = false;
  bool _smartAlarm = false;
  bool _hydrationReminder = false;

  @override
  void initState() {
    super.initState();
    _loadHrSettings();
  }

  Future<void> _loadHrSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final access = await widget.bleBridge.isNotificationListenerGranted();
      if (mounted) {
        setState(() {
          _hrIntervalMinutes = prefs.getInt('kalkan_hr_interval_minutes') ?? 15;
          _continuousHr = prefs.getBool('kalkan_hr_continuous_enabled') ?? false;
          _callAlert = prefs.getBool('kalkan_call_remind_enabled') ?? true;
          _antiLoss = prefs.getBool('kalkan_disconnect_alert_enabled') ?? true;
          _smartAlarm = prefs.getBool('kalkan_smart_alarm_enabled') ?? false;
          _hydrationReminder = prefs.getBool('kalkan_hydration_reminder_enabled') ?? false;
          _notificationAccessGranted = access;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleAntiLoss(bool value) async {
    setState(() => _antiLoss = value);
    await widget.bleBridge.setDisconnectRemind(value);
  }

  Future<void> _toggleSmartAlarm(bool value) async {
    setState(() => _smartAlarm = value);
    await widget.bleBridge.setSmartAlarm(value);
  }

  Future<void> _toggleHydrationReminder(bool value) async {
    setState(() => _hydrationReminder = value);
    await widget.bleBridge.setHydrationReminder(value);
  }

  Future<void> _toggleCallAlert(bool value) async {
    setState(() => _callAlert = value);
    await widget.bleBridge.setCallRemindEnable(value);
  }

  Future<void> _updateHrInterval(int minutes) async {
    setState(() => _hrIntervalMinutes = minutes);
    await widget.bleBridge.configureHeartRateMonitoring(
      intervalMinutes: minutes,
      continuous: _continuousHr,
    );
  }

  Future<void> _toggleContinuousHr(bool value) async {
    setState(() => _continuousHr = value);
    await widget.bleBridge.configureHeartRateMonitoring(
      intervalMinutes: _hrIntervalMinutes,
      continuous: value,
    );
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.cardRadius)),
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
            onPressed: () async {
              Navigator.of(context).pop();
              await widget.bleBridge.resetToFactorySettings();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surface,
                    content: Text(
                      tr('Браслет сброшен до заводских настроек', 'Билерик баштапкы абалга кайтарылды', 'Watch reset to factory settings'),
                      style: const TextStyle(color: AppColors.rose),
                    ),
                  ),
                );
              }
            },
            child: Text(tr('Сбросить', 'Кайтаруу'), style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static const Map<String, String> _enDict = {
    'Сброс до заводских настроек?': 'Reset to factory settings?',
    'Отмена': 'Cancel',
    'Сбросить': 'Reset',
    'Браслет сброшен до заводских настроек': 'Watch reset to factory settings',
    'Мониторинг пульса': 'Heart Rate Monitoring',
    'Интервал автозамера в покое и движении': 'Auto-measurement interval in rest and motion',
    'мин': 'min',
    'Непрерывный замер': 'Continuous HR',
    'Высокий расход батареи (~1-2 дня)': 'High battery drain (~1-2 days)',
    'Часы': 'Watch',
    'Часы КАЛКАН СААТ-1': 'KALKAN SAAT-1 Watch',
    'Поиск другого браслета': 'Search for another band',
    'На связи': 'Connected',
    'Отключено': 'Disconnected',
    'Прошивка: v1.2.4': 'Firmware: v1.2.4',
    'Обновить': 'Update',
    'Найти браслет': 'Find band',
    'Функции часов': 'Watch features',
    'Антипотеря': 'Anti-loss',
    'Сигнал, если браслет дальше 10 метров': 'Alert if band is farther than 10m',
    'Оповещение об отключении': 'Disconnect alert',
    'Пуш при разрыве Bluetooth': 'Push notification when Bluetooth drops',
    'Умный будильник': 'Smart alarm',
    'Вибрация в лёгкой фазе сна': 'Vibration during light sleep phase',
    'Напоминание пить воду': 'Hydration reminder',
    'Вибрация каждые 2 часа': 'Vibrate every 2 hours',
    'Измерение…': 'Measuring…',
    'Замер пульса': 'Measure pulse',
    'Синхр. время': 'Sync time',
    'Сбросить браслет': 'Reset band',
  };

  String tr(String r, String k, [String? e]) {
    final lang = AppLocaleNotifier.current;
    if (lang == AppLanguage.kyrgyz) return k;
    if (lang == AppLanguage.english) return e ?? _enDict[r] ?? r;
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;

    final palette = KalkanColors.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      appBar: KalkanAppBar(
        eyebrow: tr('УСТРОЙСТВО', 'ТҮЗМӨК'),
        title: tr('Часы КАЛКАН СААТ-1', 'КАЛКАН СААТ-1 сааты'),
        implyLeading: true,
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
            KalkanCard(
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
                            color: telemetry.isConnected ? AppColors.sage : AppColors.rose,
                            width: 1.8,
                          ),
                        ),
                        child: Icon(
                          telemetry.isConnected ? Icons.watch : Icons.watch_off_outlined,
                          color: telemetry.isConnected ? AppColors.sage : AppColors.rose,
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
                              style: TextStyle(
                                color: palette.fg,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              telemetry.isConnected ? tr('На связи', 'Туташкан') : tr('Отключено', 'Өчүк'),
                              style: TextStyle(
                                color: telemetry.isConnected ? AppColors.sage : AppColors.rose,
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
                          color: (!telemetry.isConnected
                                  ? AppColors.rose
                                  : (telemetry.isCharging ? AppColors.amber : AppColors.sage))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                          border: Border.all(
                            color: (!telemetry.isConnected
                                    ? AppColors.rose
                                    : (telemetry.isCharging ? AppColors.amber : AppColors.sage))
                                .withValues(alpha: 0.4),
                            width: KalkanUi.hairline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              !telemetry.isConnected
                                  ? Icons.bluetooth_disabled
                                  : (telemetry.isCharging ? Icons.battery_charging_full : Icons.battery_std),
                              color: !telemetry.isConnected
                                  ? AppColors.rose
                                  : (telemetry.isCharging ? AppColors.amber : AppColors.sage),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              !telemetry.isConnected
                                  ? tr('Нет сигнала', 'Сигнал жок', 'No signal')
                                  : (telemetry.isCharging
                                      ? (telemetry.batteryLevel > 0
                                          ? '${telemetry.batteryLevel}% ⚡ ${tr('Зарядка', 'Заряддалууда', 'Charging')}'
                                          : '⚡ ${tr('Зарядка…', 'Заряддалууда…', 'Charging…')}')
                                      : (telemetry.batteryLevel > 0
                                          ? '${telemetry.batteryLevel}%'
                                          : tr('Подключено', 'Туташты', 'Connected'))),
                              style: TextStyle(
                                color: !telemetry.isConnected
                                    ? AppColors.rose
                                    : (telemetry.isCharging ? AppColors.amber : AppColors.sage),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                ],
              ),
            ),
            if (telemetry.isConnected && !telemetry.isAncsAuthorized) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KalkanUi.cardRadius),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.4),
                    width: KalkanUi.hairline,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_off_outlined, color: AppColors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr(
                              'Уведомления iOS не передаются',
                              'iOS билдирүүлөрү өткөрүлбөйт',
                              'iOS Notifications not shared',
                            ),
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'Чтобы часы получали звонки и SMS, откройте Настройки iOS ➔ Bluetooth ➔ выберите часы ➔ включите «Делиться системными уведомлениями».',
                        'Саат чалууларды жана SMSтерди алышы үчүн, iOS Орнотуулар ➔ Bluetooth ➔ саатты тандап ➔ «Системалык билдирүүлөр менен бөлүшүү» күйгүзүңүз.',
                        'To receive calls and messages on the watch, open iOS Settings ➔ Bluetooth ➔ tap your watch ➔ enable "Share System Notifications".',
                      ),
                      style: TextStyle(
                        color: palette.secondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => widget.bleBridge.openAppSettings(),
                      borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                        ),
                        child: Text(
                          tr('Открыть Настройки', 'Орнотууларды ачуу', 'Open Settings'),
                          style: const TextStyle(
                            color: AppColors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                  minimumSize: const Size(44, KalkanUi.minTapTarget),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
                  elevation: 0,
                ),
              ),
            ),
            if (!telemetry.isConnected)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: KalkanCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: AppColors.rose.withValues(alpha: 0.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.rose.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                            ),
                            child: const Icon(Icons.bluetooth_disabled, color: AppColors.rose, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('СВЯЗЬ С СААТ-1 ПОТЕРЯНА', 'СААТ-1 МЕНЕН БАЙЛАНЫШ ҮЗҮЛДҮ', 'CONNECTION TO SAAT-1 LOST'),
                                  style: AppTypography.eyebrow(AppColors.rose),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr('Ошибка подключения BLE', 'BLE туташуу катасы', 'BLE Connection Error'),
                                  style: AppTypography.bodySemibold(palette.fg),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr(
                          '• Убедитесь, что Bluetooth включён на телефоне.\n• Держите часы СААТ-1 рядом (в пределах 2 метров).\n• Если часы подключены к другому устройству — отключите их.',
                          '• Телефондо Bluetooth күйгүзүлгөнүн текшериңиз.\n• Саатты жакын кармаңыз (2 метр аралыкта).\n• Башка түзмөккө туташкан болсо — өчүрүңүз.',
                          '• Ensure Bluetooth is enabled on your phone.\n• Keep SAAT-1 watch close (within 2 meters).\n• If connected to another device, disconnect first.',
                        ),
                        style: AppTypography.caption(palette.secondary).copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                CircaHaptics.selectionClick();
                                final lastAddr = await widget.bleBridge.getLastPairedAddress();
                                if (lastAddr != null && lastAddr.isNotEmpty) {
                                  await widget.bleBridge.connect(lastAddr);
                                } else {
                                  await widget.bleBridge.startScan();
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(tr('Повторная попытка подключения к СААТ-1…', 'СААТ-1ге кайра туташуу аракети…', 'Reconnecting to SAAT-1…')),
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.sage,
                                side: const BorderSide(color: AppColors.sage),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
                              ),
                              child: Text(tr('Повторить подключение', 'Кайра туташуу', 'Retry Connect')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                CircaHaptics.selectionClick();
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => DevicePairScreen(bleBridge: widget.bleBridge)),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
                              ),
                              child: Text(tr('Поиск другого', 'Башка издөө', 'Pair Another')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            Text(
              tr('МОНИТОРИНГ ЗДОРОВЬЯ', 'ДЕН СООЛУКТУ КӨЗӨМӨЛДӨӨ', 'HEALTH MONITORING'),
              style: TextStyle(
                color: palette.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),

            // Настройка интервала замера пульса
            KalkanCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('Интервал замера пульса', 'Пульсту өлчөө интервалы', 'Heart Rate Interval'),
                              style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('Автозамер в покое и движении (15 мин сохраняет батарею 7-10 дней)', 'Тынч жана кыймылда автоөлчөө (15 мүн батареяны 7-10 күн сактайт)', 'Auto-measurement in rest/motion (15m saves battery 7-10d)'),
                              style: TextStyle(color: palette.secondary, fontSize: 11, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$_hrIntervalMinutes ${tr('мин', 'мүн', 'min')}',
                        style: const TextStyle(color: AppColors.sage, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [15, 30, 60, 1].map((interval) {
                      final isSelected = _hrIntervalMinutes == interval;
                      final label = interval == 15
                          ? '15 ${tr('мин', 'мүн', 'min')} ★'
                          : '$interval ${tr('мин', 'мүн', 'min')}';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: InkWell(
                            onTap: () => _updateHrInterval(interval),
                            borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.sage.withValues(alpha: 0.2) : AppColors.raised,
                                borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                                border: Border.all(
                                  color: isSelected ? AppColors.sage : AppColors.line,
                                  width: isSelected ? 1.5 : KalkanUi.hairline,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.sage : palette.secondary,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: AppColors.line, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('Непрерывный замер', 'Үзгүлтүксүз өлчөө', 'Continuous HR'),
                              style: TextStyle(color: palette.fg, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              tr('Быстрый разряд батареи (~1-2 дня)', 'Батареяны тез сарптайт (~1-2 күн)', 'High battery drain (~1-2 days)'),
                              style: TextStyle(color: palette.secondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _continuousHr,
                        activeThumbColor: AppColors.rose,
                        onChanged: _toggleContinuousHr,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              tr('Функции часов', 'Сааттын функциялары'),
              style: TextStyle(
                color: palette.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),

            // Антипотеря (Anti-loss & Disconnect alert)
            KalkanCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Антипотеря и разрыв связи', 'Жоготууга каршы жана үзүлүү эскертүүсү', 'Anti-loss & disconnect alert'),
                          style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('Вибрация браслета при потере Bluetooth-связи', 'Bluetooth үзүлгөндө билерик титирейт', 'Band vibration upon Bluetooth disconnect'),
                          style: TextStyle(color: palette.secondary, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _antiLoss,
                    activeThumbColor: AppColors.sage,
                    onChanged: _toggleAntiLoss,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Умный будильник (Smart alarm)
            KalkanCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Умный будильник', 'Акылдуу ойготкуч', 'Smart alarm'),
                          style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('Бесшумная тактильная вибрация в 07:00 для мягкого пробуждения', 'Жумшак ойгонуу үчүн саат 07:00дө үнсүз титирөө', 'Silent haptic vibration at 07:00 for gentle wake-up'),
                          style: TextStyle(color: palette.secondary, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _smartAlarm,
                    activeThumbColor: AppColors.sage,
                    onChanged: _toggleSmartAlarm,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Напоминание о воде (Hydration reminder)
            KalkanCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Напоминание о воде', 'Суу ичүүнү эскертүү', 'Hydration reminder'),
                          style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('Мягкий вибросигнал каждые 2 часа с 09:00 до 21:00', '09:00дөн 21:00гө чейин ар 2 саатта жумшак титирөө', 'Gentle haptic vibration every 2 hours (09:00–21:00)'),
                          style: TextStyle(color: palette.secondary, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _hydrationReminder,
                    activeThumbColor: AppColors.sage,
                    onChanged: _toggleHydrationReminder,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Входящие звонки и сообщения (Whoop haptics)
            KalkanCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('Входящие звонки и пуши', 'Чалуулар жана билдирүүлөр', 'Calls & notifications'),
                              style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('Вибрация браслета при звонках и сообщениях', 'Чалуу жана SMS келгенде билерик титирейт', 'Band vibration for calls & messages'),
                              style: TextStyle(color: palette.secondary, fontSize: 11, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _callAlert,
                        activeThumbColor: AppColors.sage,
                        onChanged: _toggleCallAlert,
                      ),
                    ],
                  ),
                  if (!_notificationAccessGranted && _callAlert) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        await widget.bleBridge.openNotificationListenerSettings();
                        await Future.delayed(const Duration(seconds: 1));
                        final acc = await widget.bleBridge.isNotificationListenerGranted();
                        if (mounted) setState(() => _notificationAccessGranted = acc);
                      },
                      borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                          border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: AppColors.amber, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tr('Разрешить доступ к уведомлениям', 'Билдирүүлөргө уруксат берүү', 'Enable notification access in settings'),
                                style: const TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.amber, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                      minimumSize: const Size(44, KalkanUi.minTapTarget),
                      side: BorderSide(color: AppColors.line, width: KalkanUi.hairline),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
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
                      minimumSize: const Size(44, KalkanUi.minTapTarget),
                      side: BorderSide(color: AppColors.line, width: KalkanUi.hairline),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
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
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, KalkanUi.minTapTarget),
                ),
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
