import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../domain/models/telemetry.dart';
import 'kalkan_ui.dart';
import 'live_pulse_wave.dart';

class CircaLivePulseCard extends StatefulWidget {
  final UteBleBridge bleBridge;

  const CircaLivePulseCard({
    super.key,
    required this.bleBridge,
  });

  @override
  State<CircaLivePulseCard> createState() => _CircaLivePulseCardState();
}

class _CircaLivePulseCardState extends State<CircaLivePulseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseAnim;
  bool _isMeasuring = false;
  Timer? _measureTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    _pulseAnim.dispose();
    super.dispose();
  }

  Future<void> _startMeasurement() async {
    if (_isMeasuring) return;
    CircaHaptics.selectionClick();

    setState(() {
      _isMeasuring = true;
      _secondsRemaining = 25;
    });

    try {
      await widget.bleBridge.triggerHeartRateMeasurement();
    } catch (_) {}

    _measureTimer?.cancel();
    _measureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _isMeasuring = false;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);

    return StreamBuilder<BleTelemetry>(
      stream: widget.bleBridge.telemetryStream,
      initialData: widget.bleBridge.currentTelemetry,
      builder: (context, snapshot) {
        final telemetry = snapshot.data ?? widget.bleBridge.currentTelemetry;
        final hr = telemetry.heartRate;
        final rhr = telemetry.restingHeartRate;
        final isConnected = telemetry.isConnected;

        return KalkanCard(
          padding: const EdgeInsets.all(KalkanUi.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Верхний бар карточки: Название, пульсирующий статус
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) {
                          final scale = isConnected ? 1.0 + (_pulseAnim.value * 0.18) : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: Icon(
                              Icons.favorite,
                              color: isConnected ? AppColors.rose : palette.secondary,
                              size: 16,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocaleNotifier.pick('LIVE ПУЛЬС', 'ЖАНДУУ ПУЛЬС', 'LIVE PULSE'),
                        style: TextStyle(
                          color: palette.fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? (_isMeasuring
                              ? AppColors.amber.withValues(alpha: 0.15)
                              : AppColors.sage.withValues(alpha: 0.15))
                          : palette.raised,
                      borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                      border: Border.all(
                        color: isConnected
                            ? (_isMeasuring
                                ? AppColors.amber.withValues(alpha: 0.4)
                                : AppColors.sage.withValues(alpha: 0.4))
                            : palette.hairline,
                        width: KalkanUi.hairline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected
                                ? (_isMeasuring ? AppColors.amber : AppColors.sage)
                                : palette.secondary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          !isConnected
                              ? AppLocaleNotifier.pick('Офлайн', 'Офлайн', 'Offline')
                              : (_isMeasuring
                                  ? AppLocaleNotifier.pick('Замер ($_secondsRemaining с)', 'Өлчөө ($_secondsRemaining с)', 'Measuring ($_secondsRemaining s)')
                                  : AppLocaleNotifier.pick('В реальном времени', 'Реалдуу убакытта', 'Real-time')),
                          style: TextStyle(
                            color: isConnected
                                ? (_isMeasuring ? AppColors.amber : AppColors.sage)
                                : palette.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Основные показатели: текущий BPM и покой (RHR)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    hr > 0 ? '$hr' : '—',
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'bpm',
                    style: TextStyle(
                      color: palette.secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppLocaleNotifier.pick('В покое', 'Тынчтыкта', 'Resting'),
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rhr > 0 ? '$rhr bpm' : '—',
                        style: TextStyle(
                          color: palette.fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Анимированная кардио-волна
              ClipRRect(
                borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                child: Container(
                  height: 60,
                  width: double.infinity,
                  color: palette.raised.withValues(alpha: 0.4),
                  child: LivePulseWaveWidget(
                    bpm: hr > 0 ? hr : 70,
                    height: 60,
                  ),
                ),
              ),

              if (_isMeasuring) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.3),
                      width: KalkanUi.hairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors, color: AppColors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocaleNotifier.pick(
                            'Зелёный PPG датчик активирован. Держите руку неподвижно…',
                            'Жашыл PPG сенсору иштеп жатат. Колду кыймылдатпаңыз…',
                            'Green PPG sensor active. Keep wrist steady…',
                          ),
                          style: TextStyle(
                            color: palette.fg,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Кнопка быстрого замера пульса
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (!isConnected || _isMeasuring) ? null : _startMeasurement,
                  icon: _isMeasuring
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.rose,
                          ),
                        )
                      : const Icon(Icons.favorite_border, size: 16),
                  label: Text(
                    _isMeasuring
                        ? AppLocaleNotifier.pick('Идёт замер ($_secondsRemaining с)…', 'Өлчөө жүрүп жатат ($_secondsRemaining с)…', 'Measuring ($_secondsRemaining s)…')
                        : AppLocaleNotifier.pick('Запустить замер пульса', 'Пульсту өлчөө', 'Measure Pulse Now'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose,
                    side: BorderSide(
                      color: isConnected ? AppColors.rose.withValues(alpha: 0.5) : palette.hairline,
                      width: KalkanUi.hairline,
                    ),
                    minimumSize: const Size(44, KalkanUi.minTapTarget),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
