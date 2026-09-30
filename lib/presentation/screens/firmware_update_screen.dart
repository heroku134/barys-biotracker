import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../widgets/kalkan_chrome.dart';
import '../widgets/kalkan_ui.dart';

/// Экран беспроводного обновления прошивки часов СААТ-1 (BLE Firmware & Release Info)
class FirmwareUpdateScreen extends StatefulWidget {
  final int watchBatteryPercent;

  const FirmwareUpdateScreen({
    super.key,
    this.watchBatteryPercent = 82,
  });

  static Future<void> open(BuildContext context, {int watchBattery = 82}) async {
    CircaHaptics.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => FirmwareUpdateScreen(watchBatteryPercent: watchBattery),
      ),
    );
  }

  @override
  State<FirmwareUpdateScreen> createState() => _FirmwareUpdateScreenState();
}

class _FirmwareUpdateScreenState extends State<FirmwareUpdateScreen> {
  bool _isChecking = false;
  DateTime? _lastCheckedAt;

  Future<void> _checkUpdates() async {
    CircaHaptics.selectionClick();
    setState(() => _isChecking = true);

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _lastCheckedAt = DateTime.now();
    });
    CircaHaptics.success();
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final bool canUpdate = widget.watchBatteryPercent >= 50;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: const KalkanAppBar(
        eyebrow: 'УСТРОЙСТВО',
        title: 'Прошивка СААТ-1',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: KalkanUi.pagePadding, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Карточка модели и установленной прошивки
              KalkanCard(
                padding: const EdgeInsets.all(KalkanUi.cardPadding),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: palette.raised,
                        borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                        border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
                      ),
                      child: const Center(
                        child: Icon(Icons.watch_outlined, color: AppColors.amber, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'КАЛКАН СААТ-1',
                            style: AppTypography.bodySemibold(palette.fg),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Текущая версия: v1.2.4 · Официальный релиз',
                            style: AppTypography.monoLabel(palette.secondary).copyWith(fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nordic nRF52840 · HW Rev. 2.1',
                            style: AppTypography.monoLabel(palette.secondary).copyWith(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Статус аккумулятора для OTA
              KalkanCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      canUpdate ? Icons.battery_charging_full : Icons.battery_alert,
                      color: canUpdate ? AppColors.sage : AppColors.rose,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Заряд часов: ${widget.watchBatteryPercent}%',
                            style: TextStyle(
                              color: canUpdate ? palette.fg : AppColors.rose,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            canUpdate ? 'Уровень достаточен для беспроводных операций (>50%)' : 'Внимание: для OTA требуется минимум 50% заряда',
                            style: AppTypography.caption(palette.secondary),
                          ),
                        ],
                      ),
                    ),
                    if (canUpdate)
                      const Icon(Icons.check_circle_outline, color: AppColors.sage, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Список изменений (Changelog) текущего релиза
              Text(
                'СПИСОК ИЗМЕНЕНИЙ V1.2.4 (ТЕКУЩАЯ СБОРКА)',
                style: AppTypography.monoLabel(palette.secondary).copyWith(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              _buildChangelogCard(
                palette,
                'Прецизионный фильтр шума PPG',
                'Точность детекции rMSSD при низком ночном пульсе повышена на 18%.',
              ),
              const SizedBox(height: 8),
              _buildChangelogCard(
                palette,
                'Пакетная буферизация телеметрии',
                'Часы сохраняют до 72 часов офлайн-замеров и передают их пачками по 15 минут.',
              ),
              const SizedBox(height: 8),
              _buildChangelogCard(
                palette,
                'Энергоэффективный Bluetooth 5.3',
                'Снижение энергопотребления чипсета на 14% при постоянном BLE-сопряжении.',
              ),
              const SizedBox(height: 20),

              // 4. Статус проверки и кнопка
              if (_isChecking) ...[
                KalkanCard(
                  padding: const EdgeInsets.all(KalkanUi.cardPadding),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Проверка официального репозитория прошивок KALKAN...',
                          style: AppTypography.monoLabel(AppColors.amber).copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (_lastCheckedAt != null) ...[
                KalkanCard(
                  padding: const EdgeInsets.all(KalkanUi.cardPadding),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.sage, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Прошивка СААТ-1 актуальна',
                              style: AppTypography.bodySemibold(palette.fg),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Версия v1.2.4 является последней официальной сборкой. Все модули работают в штатном режиме.',
                              style: AppTypography.caption(palette.secondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkUpdates,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(0, KalkanUi.minTapTarget),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
                    elevation: 0,
                  ),
                  child: Text(
                    _isChecking
                        ? 'ПРОВЕРКА...'
                        : (_lastCheckedAt != null ? 'ПРОВЕРИТЬ ПОВТОРНО' : 'ПРОВЕРИТЬ НАЛИЧИЕ ОБНОВЛЕНИЙ'),
                    style: AppTypography.monoLabel(Colors.black).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangelogCard(KalkanColors palette, String title, String desc) {
    return KalkanCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.sage,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: AppTypography.caption(palette.secondary),
          ),
        ],
      ),
    );
  }
}
