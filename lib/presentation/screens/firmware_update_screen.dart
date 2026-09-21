import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isUpdating = false;
  bool _isUpdated = false;
  double _progress = 0.0;
  int _transferredBlocks = 0;
  final int _totalBlocks = 380;
  Timer? _updateTimer;

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startOtaUpdate() {
    if (widget.watchBatteryPercent < 50) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Заряд часов ниже 50%! Подключите СААТ-1 к магнитной зарядке перед прошивкой.',
            style: TextStyle(color: AppColors.rose),
          ),
        ),
      );
      return;
    }

    CircaHaptics.workoutStart();
    setState(() {
      _isUpdating = true;
      _progress = 0.0;
      _transferredBlocks = 0;
    });

    _updateTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      setState(() {
        _transferredBlocks += 4;
        _progress = (_transferredBlocks / _totalBlocks).clamp(0.0, 1.0);

        if (_transferredBlocks >= _totalBlocks) {
          _updateTimer?.cancel();
          _isUpdating = false;
          _isUpdated = true;
          CircaHaptics.success();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canUpdate = widget.watchBatteryPercent >= 50;

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textNearWhite),
          onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          'ОБНОВЛЕНИЕ ПРОШИВКИ',
          style: AppTypography.monoLabel.copyWith(
            color: AppColors.textNearWhite,
            fontSize: 12,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w700,
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
                      child: const Center(
                        child: Icon(Icons.watch_outlined, color: AppColors.amber, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KALKAN СААТ-1',
                            style: const TextStyle(
                              color: AppColors.textNearWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Текущая версия: v1.2.4 · Доступна: v1.3.0',
                            style: AppTypography.monoLabel.copyWith(
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Заряд аккумулятора часов: ${widget.watchBatteryPercent}%',
                            style: TextStyle(
                              color: canUpdate ? AppColors.textNearWhite : AppColors.rose,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            canUpdate ? 'Уровень достаточен для DFU (>50%)' : 'Внимание: требуется минимум 50% заряда',
                            style: AppTypography.monoLabel.copyWith(
                              color: AppColors.muted,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canUpdate)
                      const Icon(Icons.check_circle_outline, color: AppColors.sage, size: 18),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. СПИСОК ИЗМЕНЕНИЙ (CHANGELOG)
              Text(
                'ЧТО НОВОГО В V1.3.0 · PRECISION CORE',
                style: AppTypography.monoLabel.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),

              _buildChangelogItem(
                'Прецизионный фильтр шума PPG',
                'Точность детекции rMSSD при низком ночном пульсе повышена на 18%.',
              ),
              const SizedBox(height: 8),
              _buildChangelogItem(
                'Фоновая пачка телеметрии',
                'Часы сохраняют до 72 часов оффлайн-замеров и выгружают их пачками по 15 минут.',
              ),
              const SizedBox(height: 8),
              _buildChangelogItem(
                'Оптимизация Bluetooth 5.3',
                'Снижение энергопотребления чипсета на 14% при постоянном подключении.',
              ),

              const Spacer(),

              // 4. ПРОГРЕСС ИЛИ КНОПКА ЗАПУСКА
              if (_isUpdating) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.5), width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ПЕРЕДАЧА ПРОШИВКИ (BLE DFU)',
                            style: AppTypography.monoLabel.copyWith(
                              color: AppColors.amber,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: AppColors.textNearWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppColors.raised,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.amber),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Блок $_transferredBlocks / $_totalBlocks (CRC32 OK)',
                            style: AppTypography.monoLabel.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 9.5,
                            ),
                          ),
                          Text(
                            '26.4 kB/s',
                            style: AppTypography.monoLabel.copyWith(
                              color: AppColors.sage,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_isUpdated) ...[
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
                              'СААТ-1 успешно обновлен!',
                              style: TextStyle(
                                color: AppColors.textNearWhite,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Часы перезагружены и работают на версии v1.3.0',
                              style: AppTypography.monoLabel.copyWith(
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
                  onPressed: (_isUpdating || _isUpdated || !canUpdate) ? null : _startOtaUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.stage,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(
                    _isUpdated
                        ? 'ОБНОВЛЕНИЕ ЗАВЕРШЕНО'
                        : (_isUpdating ? 'ПЕРЕДАЧА ДАННЫХ...' : 'НАЧАТЬ ОБНОВЛЕНИЕ ПО ВОЗДУХУ'),
                    style: AppTypography.monoLabel.copyWith(
                      color: AppColors.stage,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
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
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textNearWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
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
