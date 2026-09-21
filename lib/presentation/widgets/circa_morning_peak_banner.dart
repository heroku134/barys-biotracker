import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import 'circa_morning_briefing_dialog.dart';

/// Анимированный утренний «пик» (Morning Peak Reveal)
/// При первом входе за день дарит пользователю яркий дофаминовый триггер:
/// выезжающую сверху плашку с haptic-волной и показателем Recovery.
class CircaMorningPeakBanner extends StatefulWidget {
  final BleTelemetry telemetry;
  final PersonalBaseline baseline;
  final int recoveryScore;

  const CircaMorningPeakBanner({
    super.key,
    required this.telemetry,
    required this.baseline,
    this.recoveryScore = 91,
  });

  @override
  State<CircaMorningPeakBanner> createState() => _CircaMorningPeakBannerState();
}

class _CircaMorningPeakBannerState extends State<CircaMorningPeakBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    // Запускаем через 350мс после монтирования экрана для максимального кинематографичного эффекта
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        // Короткая приятная тактильная волна Apple Haptic
        HapticFeedback.mediumImpact();
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() => _isDismissed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surface,
                AppColors.raised.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.sage.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.sage.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.selectionClick();
                CircaMorningBriefingDialog.show(context, widget.telemetry, widget.baseline);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Золотой чип утреннего пика с пульсирующим солнцем
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sage.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.recoveryScore}%',
                          style: const TextStyle(
                            color: AppColors.sage,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),

                    // Текст утреннего пика
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.sage,
                                ),
                              ),
                              SizedBox(width: 6),
                              const Text(
                                'УТРЕННИЙ ПИК ВОССТАНОВЛЕНИЯ · 07:15',
                                style: TextStyle(
                                  color: AppColors.sage,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3),
                          const Text(
                            'ЦНС готова к максимальной адаптации и нагрузкам дня',
                            style: TextStyle(
                              color: AppColors.fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Кнопка подробнее
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: AppColors.muted),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Скрыть',
                      onPressed: _dismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
