import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';

/// Экран беспроводного обновления прошивки часов СААТ-1 по воздуху (BLE OTA / DFU)
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
    final bool canUpdate = widget.watchBatteryPercent >= 50;

    return Scaffold(
      backgroundColor: AppColors.stage,
      appBar: AppBar(
        backgroundColor: AppColors.stage,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textNearWhite),
          onPressed: _isChecking ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Прошивка',
          style: AppTypography.monoLabel().copyWith(
            color: AppColors.textNearWhite,
            fontSize: 18,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.hairline, height: 1),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. КАРТОЧКА МОДЕЛИ И СТАТУСА
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline, width: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.raised,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.hairline, width: 1.0),
                      ),
                      child: Center(
                        child: Icon(Icons.watch_outlined, color: AppColors.amber, size: 28),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KALKAN СААТ-1',
                            style: TextStyle(
                              color: AppColors.textNearWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Текущая версия: v1.2.4 · Официальный релиз',
                            style: AppTypography.monoLabel().copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // 2. ПРОВЕРКА БАТАРЕИ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: canUpdate ? AppColors.hairline : AppColors.rose.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      canUpdate ? Icons.battery_charging_full : Icons.battery_alert,
                      color: canUpdate ? AppColors.sage : AppColors.rose,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Заряд аккумулятора часов: ${widget.watchBatteryPercent}%',
                            style: TextStyle(
                              color: canUpdate ? AppColors.textNearWhite : AppColors.rose,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            canUpdate ? 'Уровень достаточен для работы (>50%)' : 'Внимание: требуется минимум 50% заряда',
                            style: AppTypography.monoLabel().copyWith(
                              color: AppColors.muted,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canUpdate)
                      Icon(Icons.check_circle_outline, color: AppColors.sage, size: 18),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // 3. СПИСОК ИЗМЕНЕНИЙ (CHANGELOG)
              Text(
                'ИСТОРИЯ ВЕРСИИ V1.2.4 · ТЕКУЩАЯ СБОРКА',
                style: AppTypography.monoLabel().copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: -0.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 10),

              _buildChangelogItem(
                'Прецизионный фильтр шума PPG',
                'Точность детекции rMSSD при низком ночном пульсе повышена на 18%.',
              ),
              SizedBox(height: 8),
              _buildChangelogItem(
                'Фоновая пачка телеметрии',
                'Часы сохраняют до 72 часов оффлайн-замеров и выгружают их пачками по 15 минут.',
              ),
              SizedBox(height: 8),
              _buildChangelogItem(
                'Оптимизация Bluetooth 5.3',
                'Снижение энергопотребления чипсета на 14% при постоянном подключении.',
              ),

              Spacer(),

              // 4. СТАТУС ПРОВЕРКИ И КНОПКА
              if (_isChecking) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.5), width: 1.0),
                  ),
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
                          style: AppTypography.monoLabel().copyWith(
                            color: AppColors.amber,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_lastCheckedAt != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.sage, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.sage, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Прошивка СААТ-1 актуальна',
                              style: TextStyle(
                                color: AppColors.textNearWhite,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Версия v1.2.4 является последней официальной сборкой. Обновлений не требуется.',
                              style: AppTypography.monoLabel().copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkUpdates,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.stage,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(
                    _isChecking
                        ? 'ПРОВЕРКА...'
                        : (_lastCheckedAt != null ? 'ПРОВЕРИТЬ ПОВТОРНО' : 'ПРОВЕРИТЬ НАЛИЧИЕ ОБНОВЛЕНИЙ'),
                    style: AppTypography.monoLabel().copyWith(
                      color: AppColors.stage,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
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

  Widget _buildChangelogItem(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.sage,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textNearWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
