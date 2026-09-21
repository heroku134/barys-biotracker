import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import '../../core/app_colors.dart';
import '../../core/circa_haptics.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import 'circa_share_card_widget.dart';

class CircaShareSheet extends StatefulWidget {
  final BleTelemetry telemetry;
  final PersonalBaseline baseline;
  final String userName;

  const CircaShareSheet({
    super.key,
    required this.telemetry,
    required this.baseline,
    this.userName = 'Данияр',
  });

  static void show(
    BuildContext context, {
    required BleTelemetry telemetry,
    required PersonalBaseline baseline,
    String userName = 'Данияр',
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CircaShareSheet(
        telemetry: telemetry,
        baseline: baseline,
        userName: userName,
      ),
    );
  }

  @override
  State<CircaShareSheet> createState() => _CircaShareSheetState();
}

class _CircaShareSheetState extends State<CircaShareSheet>
    with SingleTickerProviderStateMixin {
  ShareCardTheme _selectedTheme = ShareCardTheme.recovery;
  final GlobalKey _cardKey = GlobalKey();
  bool _isExporting = false;
  bool _isMotionMode = false;
  late AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  void _toggleMotionMode(bool enabled) {
    HapticFeedback.selectionClick();
    setState(() {
      _isMotionMode = enabled;
      if (enabled) {
        _motionController.repeat();
      } else {
        _motionController.stop();
        _motionController.reset();
      }
    });
  }

  Future<void> _handleShare(String actionTitle) async {
    CircaHaptics.cardExport();
    setState(() => _isExporting = true);

    // 1. Формируем реальную сводку дня для буфера обмена
    final readiness = ReadinessEngine.calculate(widget.telemetry, baseline: widget.baseline);
    final recoveryText = '${readiness.score}% (${readiness.zone.label})';
    final heartRate = '${widget.telemetry.heartRate} уд/мин';
    final hrv = '${widget.telemetry.hrv.round()} мс';
    final strain = widget.telemetry.currentDayStrain.toStringAsFixed(1);
    final sleepH = widget.telemetry.sleepMinutes ~/ 60;
    final sleepM = widget.telemetry.sleepMinutes % 60;
    final sleepQuality = (widget.telemetry.sleepEfficiency * 100).round();

    final textSummary = '''
KALKAN BIOTRACKER · ДЕНЬ 14
Пользователь: ${widget.userName} · Батыр (Ур. 4)
Восстановление: $recoveryText
Пульс: $heartRate | ВСР: $hrv
Нагрузка дня: $strain / 21.0
Сон: $sleepHч $sleepMм ($sleepQuality% покрытия)
Устройство: KALKAN SAAT-1 · Алматы, Казахстан
'''.trim();

    // 2. Реальное копирование в системный буфер обмена
    await Clipboard.setData(ClipboardData(text: textSummary));

    // 3. Захват растра из RepaintBoundary
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        await boundary.toImage(pixelRatio: 2.0);
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 350));

    if (mounted) {
      setState(() => _isExporting = false);
      CircaAcoustics.playMechanicalClick();
      final subtitle = _isMotionMode
          ? 'Видео-история и сводка дня скопированы в буфер обмена!'
          : 'Сводка и карточка дня скопированы в буфер обмена!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.amber, width: 1.0),
          ),
          content: Row(
            children: [
              Icon(
                _isMotionMode ? Icons.movie_filter_outlined : Icons.check_circle,
                color: AppColors.amber,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final readiness = ReadinessEngine.calculate(widget.telemetry, baseline: widget.baseline);
    final avatarProfile = AvatarManager.getProfile(widget.telemetry, baseline: widget.baseline);
    final strainResult = StrainEngine.evaluate(
      currentStrain: widget.telemetry.currentDayStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: widget.telemetry.zoneMinutes,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.stage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.line, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка шторки
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.faint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 14),

            // Заголовок шторки
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'СТАТУСНАЯ КАРТОЧКА (PROOF OF FORM)',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Швейцарский стиль · Формат 9:16 Stories',
                      style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.muted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            SizedBox(height: 10),

            // Переключатель формата: СТАТИЧНЫЙ PNG vs ЖИВАЯ СТОРИС 5 СЕК
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleMotionMode(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isMotionMode ? AppColors.raised : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_outlined,
                                size: 14,
                                color: !_isMotionMode ? AppColors.fg : AppColors.muted,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'СТАТИЧНЫЙ PNG',
                                style: TextStyle(
                                  color: !_isMotionMode ? AppColors.fg : AppColors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleMotionMode(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _isMotionMode ? AppColors.amber.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: _isMotionMode
                              ? Border.all(color: AppColors.amber.withValues(alpha: 0.5))
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.movie_creation_outlined,
                                size: 14,
                                color: _isMotionMode ? AppColors.amber : AppColors.muted,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'ЖИВАЯ СТОРИС (5 СЕК)',
                                style: TextStyle(
                                  color: _isMotionMode ? AppColors.amber : AppColors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 10),

            // Переключатель тем карточки
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: ShareCardTheme.values.map((theme) {
                  final isSelected = _selectedTheme == theme;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTheme = theme);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.raised : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.line : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            theme.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.fg : AppColors.muted,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: 14),

            // Превью карточки 9:16 с масштабированием
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.48,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: AnimatedBuilder(
                      animation: _motionController,
                      builder: (context, _) {
                        return CircaShareCardWidget(
                          theme: _selectedTheme,
                          telemetry: widget.telemetry,
                          baseline: widget.baseline,
                          readiness: readiness,
                          avatarProfile: avatarProfile,
                          strainResult: strainResult,
                          userName: widget.userName,
                          animationProgress: _isMotionMode ? _motionController.value : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Кнопки действий
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.stage,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isExporting
                        ? null
                        : () => _handleShare(_isMotionMode ? 'Экспорт видео-сторис' : 'Поделиться'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isExporting)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.stage),
                            ),
                          )
                        else ...[
                          Icon(_isMotionMode ? Icons.movie_filter : Icons.ios_share, size: 18),
                          SizedBox(width: 8),
                          Text(
                            _isMotionMode ? 'ЭКСПОРТ СТОРИС 5s' : 'ПОДЕЛИТЬСЯ',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.fg,
                      side: BorderSide(color: AppColors.line, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isExporting
                        ? null
                        : () => _handleShare('Сохранено в галерею'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download, size: 16, color: AppColors.muted),
                        SizedBox(width: 4),
                        Text(
                          _isMotionMode ? 'MP4' : 'PNG',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
