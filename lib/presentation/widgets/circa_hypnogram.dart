import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/models/telemetry.dart';
import 'kalkan_ui.dart';

/// Карточка потребности во сне с честным отображением гипнограммы (без генерации фейковых фаз)
class CircaHypnogram extends StatelessWidget {
  final SleepAnalysisResult sleepResult;

  const CircaHypnogram({
    super.key,
    required this.sleepResult,
  });

  static void showSleepBreakdownSheet(BuildContext context, SleepAnalysisResult sleepResult) {
    CircaHypnogram(sleepResult: sleepResult)._showDetailsModal(context);
  }

  void _showDetailsModal(BuildContext context) {
    CircaHaptics.selectionClick();
    final palette = KalkanColors.of(context);
    final needHours = sleepResult.sleepNeedMinutes ~/ 60;
    final needMinutes = sleepResult.sleepNeedMinutes % 60;
    final actualHours = sleepResult.actualSleepMinutes ~/ 60;
    final actualMinutes = sleepResult.actualSleepMinutes % 60;
    final coveragePercent = (sleepResult.sleepPerformanceScore).clamp(0, 100);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(KalkanUi.cardRadius)),
          border: Border(top: BorderSide(color: palette.hairline, width: KalkanUi.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ручка шторки
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.secondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Заголовок модального окна с кнопкой закрытия
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleNotifier.pick(
                            'АРХИТЕКТУРА И ПОТРЕБНОСТЬ ВО СНЕ',
                            'УЙКУ АРХИТЕКТУРАСЫ ЖАНА МУКТАЖДЫК',
                            'SLEEP ARCHITECTURE & NEED',
                          ),
                          style: AppTypography.monoLabel(AppColors.amber).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppLocaleNotifier.pick('Сон', 'Уйку', 'Sleep')}: $actualHoursч $actualMinutesм / $needHoursч $needMinutesм',
                          style: AppTypography.bodySemibold(palette.fg),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.secondary, size: 22),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Декомпозиция Sleep Need: База + Долг + За Strain = Итого
                Text(
                  AppLocaleNotifier.pick(
                    'РАСЧЁТ ПОТРЕБНОСТИ ВО СНЕ (SLEEP NEED)',
                    'УЙКУГА МУКТАЖДЫКТЫ ЭСЕПТӨӨ',
                    'SLEEP NEED BREAKDOWN',
                  ),
                  style: AppTypography.monoLabel(palette.secondary).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: palette.raised,
                    borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                    border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNeedItem(palette, AppLocaleNotifier.pick('База', 'База', 'Base'), '${sleepResult.baselineNeedMinutes ~/ 60}ч ${sleepResult.baselineNeedMinutes % 60}м'),
                      Text('+', style: TextStyle(color: palette.secondary, fontSize: 13)),
                      _buildNeedItem(palette, AppLocaleNotifier.pick('Долг 14д', 'Карыз 14к', 'Debt 14d'), '+${sleepResult.sleepDebtPortionMinutes}м'),
                      Text('+', style: TextStyle(color: palette.secondary, fontSize: 13)),
                      _buildNeedItem(palette, AppLocaleNotifier.pick('За Strain', 'Strain үчүн', 'For Strain'), '+${sleepResult.strainSurchargeMinutes}м'),
                      Text('=', style: TextStyle(color: palette.secondary, fontSize: 13)),
                      _buildNeedItem(palette, AppLocaleNotifier.pick('Итого', 'Жыйынтык', 'Total'), '$needHoursч $needMinutesм', isHighlight: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4 фактора восстановления сном
                Text(
                  AppLocaleNotifier.pick(
                    'ФАКТОРЫ ВОССТАНОВЛЕНИЯ СНОМ',
                    'УЙКУ МЕНЕН КАЛЫБЫНА КЕЛҮҮ ФАКТОРЛОРУ',
                    'SLEEP RESTORATION FACTORS',
                  ),
                  style: AppTypography.monoLabel(palette.secondary).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildFactorPill(palette, AppLocaleNotifier.pick('Длительность', 'Узактык', 'Duration'), '${sleepResult.durationFactor}%'),
                    const SizedBox(width: 8),
                    _buildFactorPill(palette, AppLocaleNotifier.pick('Эффективность', 'Натыйжалуулук', 'Efficiency'), '${sleepResult.efficiencyFactor}%'),
                    const SizedBox(width: 8),
                    _buildFactorPill(palette, AppLocaleNotifier.pick('Режим', 'Режим', 'Consistency'), '${sleepResult.consistencyFactor}%'),
                    const SizedBox(width: 8),
                    _buildFactorPill(palette, AppLocaleNotifier.pick('Релаксация', 'Релаксация', 'Restorative'), '${sleepResult.restorativeFactor}%'),
                  ],
                ),
                const SizedBox(height: 20),

                // Секция гипнограммы
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocaleNotifier.pick(
                        'ГИПНОГРАММА НОЧИ (ПО СЕНСОРУ)',
                        'ТҮНКҮ ГИПНОГРАММА (СЕНСОР БОЮНЧА)',
                        'NIGHT HYPNOGRAM (SENSOR)',
                      ),
                      style: AppTypography.monoLabel(palette.secondary).copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${AppLocaleNotifier.pick('Отбой', 'Жатуу', 'Bedtime')}: ${sleepResult.optimalBedtime}',
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Контейнер гипнограммы: честный empty при отсутствии эпох
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.raised,
                    borderRadius: BorderRadius.circular(KalkanUi.cardRadius),
                    border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
                  ),
                  child: sleepResult.hypnogram.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Серая полоса сна без фаз
                            Container(
                              width: double.infinity,
                              height: 12,
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                                border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: (coveragePercent / 100).clamp(0.08, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: palette.secondary.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              AppLocaleNotifier.pick(
                                'Ночь без фаз — часы не отдали гипнограмму',
                                'Фазаларсыз түн — саат гипнограмманы берген жок',
                                'Night without sleep stages — watch did not provide hypnogram',
                              ),
                              style: AppTypography.bodySemibold(palette.fg),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocaleNotifier.pick(
                                'Оптический датчик СААТ-1 зафиксировал общее время отдыха ($actualHoursч $actualMinutesм), но не передал непрерывную разбивку на фазы (глубокий / REM). Серая полоса честно отображает несегментированный сон. Приложение намеренно не генерирует искусственный 90-минутный цикл.',
                                'СААТ-1 оптикалык сенсору жалпы эс алуу убактысын ($actualHoursс $actualMinutesм) жазды, бирок фазаларга (терең / REM) бөлүнүүнү берген жок. Боз тилке бөлүштүрүлбөгөн уйкуну ачык көрсөтөт. Тиркеме жасалма 90 мүнөттүк циклди жаратпайт.',
                                'The SAAT-1 optical sensor recorded total rest duration ($actualHours h $actualMinutes m), but continuous phase epochs (Deep / REM) were not received. The gray bar displays unsegmented sleep authentically. The app deliberately avoids generating an artificial 90-minute cycle.',
                              ),
                              style: AppTypography.caption(palette.secondary),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(
                              height: 80,
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: _HypnogramPainter(epochs: sleepResult.hypnogram),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildLegendItem('Глубокий', AppColors.sage, palette),
                                _buildLegendItem('REM (быстрый)', AppColors.amber, palette),
                                _buildLegendItem('Легкий', palette.secondary, palette),
                                _buildLegendItem('Пробуждения', AppColors.rose, palette),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),

                // Кнопка закрытия
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.raised,
                      foregroundColor: palette.fg,
                      minimumSize: const Size(0, KalkanUi.minTapTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                        side: BorderSide(color: palette.hairline, width: KalkanUi.hairline),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      AppLocaleNotifier.pick('ЗАКРЫТЬ', 'ЖАБУУ', 'CLOSE'),
                      style: AppTypography.monoLabel(palette.fg).copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final needHours = sleepResult.sleepNeedMinutes ~/ 60;
    final needMinutes = sleepResult.sleepNeedMinutes % 60;
    final actualHours = sleepResult.actualSleepMinutes ~/ 60;
    final actualMinutes = sleepResult.actualSleepMinutes % 60;
    final coveragePercent = (sleepResult.sleepPerformanceScore).clamp(0, 100);

    return KalkanCard(
      padding: const EdgeInsets.all(KalkanUi.cardPadding),
      onTap: () => _showDetailsModal(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок карточки
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sleepBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocaleNotifier.pick('ПОТРЕБНОСТЬ ВО СНЕ', 'УЙКУГА МУКТАЖДЫК', 'SLEEP NEED'),
                    style: AppTypography.monoLabel(palette.secondary).copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.raised,
                  borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                  border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bedtime_outlined, size: 12, color: AppColors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${AppLocaleNotifier.pick('Отбой', 'Жатуу', 'Bedtime')}: ${sleepResult.optimalBedtime}',
                      style: TextStyle(
                        color: palette.fg,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Фактический сон vs Потребность
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$actualHoursч $actualMinutesм',
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              Text(
                ' / $needHoursч $needMinutesм',
                style: TextStyle(
                  color: palette.secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (coveragePercent >= 80 ? AppColors.sage : AppColors.amber).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                  border: Border.all(
                    color: (coveragePercent >= 80 ? AppColors.sage : AppColors.amber).withValues(alpha: 0.5),
                    width: KalkanUi.hairline,
                  ),
                ),
                child: Text(
                  '$coveragePercent% ${AppLocaleNotifier.pick('ПОКРЫТИЯ', 'КАМСЫЗДОО', 'COVERAGE')}',
                  style: TextStyle(
                    color: coveragePercent >= 80 ? AppColors.sage : AppColors.amber,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Честное отображение: серая полоса сна при отсутствии детальных фаз
          if (sleepResult.hypnogram.isEmpty) ...[
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (coveragePercent / 100).clamp(0.08, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.secondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: palette.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppLocaleNotifier.pick(
                      'Ночь без фаз — часы не отдали гипнограмму',
                      'Фазаларсыз түн — саат гипнограмманы берген жок',
                      'Night without sleep stages — watch did not provide hypnogram',
                    ),
                    style: AppTypography.caption(palette.secondary),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Реальные фазы только при наличии фактических эпох от сенсора
            Builder(builder: (_) {
              final deepMinutes = sleepResult.hypnogram
                  .where((e) => e.stage == SleepStageType.deep)
                  .fold<int>(0, (sum, e) => sum + e.durationMinutes);
              final remMinutes = sleepResult.hypnogram
                  .where((e) => e.stage == SleepStageType.rem)
                  .fold<int>(0, (sum, e) => sum + e.durationMinutes);
              final lightMinutes = sleepResult.hypnogram
                  .where((e) => e.stage == SleepStageType.light)
                  .fold<int>(0, (sum, e) => sum + e.durationMinutes);

              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                    child: LinearProgressIndicator(
                      value: (coveragePercent / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: palette.raised,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        coveragePercent >= 80 ? AppColors.sage : AppColors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPhaseSummary('Глубокий', '${(deepMinutes / 60).toStringAsFixed(1)}ч', AppColors.sage, palette),
                      _buildPhaseSummary('REM (быстрый)', '${(remMinutes / 60).toStringAsFixed(1)}ч', AppColors.amber, palette),
                      _buildPhaseSummary('Легкий', '${(lightMinutes / 60).toStringAsFixed(1)}ч', palette.secondary, palette),
                    ],
                  ),
                ],
              );
            }),
          ],
          const SizedBox(height: 12),

          // Ссылка на подробный разбор
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: palette.raised,
              borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
              border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.query_stats, size: 14, color: AppColors.amber),
                    const SizedBox(width: 6),
                    Text(
                      AppLocaleNotifier.pick('Подробный разбор факторов сна', 'Уйку факторлорун кеңири талдоо', 'Detailed sleep factors analysis'),
                      style: TextStyle(
                        color: palette.fg,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right, size: 16, color: palette.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPhaseSummary(String label, String value, Color dotColor, KalkanColors palette) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(color: palette.secondary, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(color: palette.fg, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  static Widget _buildNeedItem(KalkanColors palette, String label, String val, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: palette.secondary, fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            color: isHighlight ? AppColors.amber : palette.fg,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static Widget _buildFactorPill(KalkanColors palette, String title, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
          border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(color: palette.fg, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.secondary, fontSize: 8.5),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildLegendItem(String label, Color color, KalkanColors palette) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: palette.secondary, fontSize: 9)),
      ],
    );
  }
}

class _HypnogramPainter extends CustomPainter {
  final List<SleepEpoch> epochs;

  _HypnogramPainter({required this.epochs});

  @override
  void paint(Canvas canvas, Size size) {
    if (epochs.isEmpty) return;

    final totalDuration = epochs.fold<int>(0, (sum, e) => sum + e.durationMinutes);
    if (totalDuration <= 0) return;

    // Уровни по Y: Awake (верх), REM, Light, Deep (низ)
    double getY(SleepStageType stage) {
      switch (stage) {
        case SleepStageType.awake:
          return size.height * 0.12;
        case SleepStageType.rem:
          return size.height * 0.38;
        case SleepStageType.light:
          return size.height * 0.65;
        case SleepStageType.deep:
          return size.height * 0.90;
      }
    }

    Color getColor(SleepStageType stage) {
      switch (stage) {
        case SleepStageType.awake:
          return AppColors.rose;
        case SleepStageType.rem:
          return AppColors.amber;
        case SleepStageType.light:
          return AppColors.muted;
        case SleepStageType.deep:
          return AppColors.sage;
      }
    }

    var currentMinutes = 0;
    final path = Path();

    for (var i = 0; i < epochs.length; i++) {
      final ep = epochs[i];
      final startX = (currentMinutes / totalDuration) * size.width;
      final endX = ((currentMinutes + ep.durationMinutes) / totalDuration) * size.width;
      final y = getY(ep.stage);

      if (i == 0) {
        path.moveTo(startX, y);
      } else {
        path.lineTo(startX, y);
      }
      path.lineTo(endX, y);

      // Заливка сегмента фазы
      final rect = Rect.fromLTRB(startX, y, endX, size.height);
      final fillPaint = Paint()..color = getColor(ep.stage).withValues(alpha: 0.18);
      canvas.drawRect(rect, fillPaint);

      currentMinutes += ep.durationMinutes;
    }

    // Отрисовка ступенчатой линии гипнограммы
    final linePaint = Paint()
      ..color = AppColors.fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _HypnogramPainter oldDelegate) => true;
}
