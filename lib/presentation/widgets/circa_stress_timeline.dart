import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../core/circa_haptics.dart';
import '../../domain/intelligence/stress_engine.dart';
import 'circa_day_story_dialog.dart';
import 'glass_card.dart';

class CircaStressTimeline extends StatefulWidget {
  final StressDaySummary stressSummary;

  const CircaStressTimeline({
    super.key,
    required this.stressSummary,
  });

  @override
  State<CircaStressTimeline> createState() => _CircaStressTimelineState();
}

class _CircaStressTimelineState extends State<CircaStressTimeline> {
  late List<StressTimeSlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = List.from(widget.stressSummary.timeline);
    _loadCustomTags();
  }

  @override
  void didUpdateWidget(covariant CircaStressTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stressSummary != widget.stressSummary) {
      _slots = List.from(widget.stressSummary.timeline);
      _loadCustomTags();
    }
  }

  Future<void> _loadCustomTags() async {
    bool hasUpdates = false;
    final updatedSlots = <StressTimeSlot>[];

    for (final slot in _slots) {
      final savedTag = await StressEngine.getSlotTag(slot.id);
      if (savedTag != null && savedTag.isNotEmpty) {
        hasUpdates = true;
        updatedSlots.add(slot.copyWith(
          userTag: savedTag,
          contextTitle: savedTag,
        ));
      } else {
        updatedSlots.add(slot);
      }
    }

    if (hasUpdates && mounted) {
      setState(() {
        _slots = updatedSlots;
      });
    }
  }

  Future<void> _updateTag(String slotId, String newTag) async {
    await StressEngine.saveSlotTag(slotId, newTag);
    if (mounted) {
      setState(() {
        _slots = _slots.map((s) {
          if (s.id == slotId) {
            return s.copyWith(userTag: newTag, contextTitle: newTag);
          }
          return s;
        }).toList();
      });
    }
  }

  void _openTagPicker(StressTimeSlot slot) async {
    HapticFeedback.mediumImpact();
    final controller = TextEditingController(text: slot.userTag ?? '');

    const presets = [
      'Переговоры',
      'Дедлайн',
      'Дорога / Пробка',
      'Кофеин',
      'Тренировка',
      'Конфликт',
      'Соцсети',
      'Медитация',
      'Обед / Пища',
    ];

    final newTag = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.lineStrong, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'РАЗМЕТКА СОБЫТИЯ (${slot.timeRange})',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: slot.level.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: slot.level.color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${slot.stressScore}% стресс',
                      style: TextStyle(
                        color: slot.level.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Укажи причину — через 30 дней ИИ Барыса начнет предсказывать пики стресса:',
                style: TextStyle(color: AppColors.fg, fontSize: 13, height: 1.3),
              ),
              SizedBox(height: 14),

              // Быстрый выбор
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((tag) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(sheetContext).pop(tag);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.raised,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(color: AppColors.fg, fontSize: 12),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 14),

              // Поле ручного ввода
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: TextStyle(color: AppColors.fg, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Или своя причина (например, «Звонок инвестору»)...',
                        hintStyle: TextStyle(color: AppColors.muted, fontSize: 11),
                        filled: true,
                        fillColor: AppColors.raised,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.sage),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(sheetContext).pop(controller.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: Text(
                      'ОК',
                      style: TextStyle(color: AppColors.stage, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (newTag != null && newTag.isNotEmpty) {
      await _updateTag(slot.id, newTag);
    }
  }

  void _triggerBreathingPause() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.sage, width: 1.2),
        ),
        content: Row(
          children: [
            Icon(Icons.air, color: AppColors.sage, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ДЫХАТЕЛЬНАЯ ПАУЗА 4-6 АКТИВИРОВАНА',
                    style: TextStyle(
                      color: AppColors.sage,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Вдох через нос на 4 счёта ... медленный выдох ртом на 6 счетов.',
                    style: TextStyle(color: AppColors.fg, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.stressSummary;

    // Ищем слот пикового стресса для предиктивной аналитики
    final peakSlot = _slots.firstWhere(
      (s) => s.stressScore >= 70,
      orElse: () => _slots[2],
    );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Заголовок монитора
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: summary.currentLevel.color,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'МОНИТОР СТРЕССА (ВСР + ЧСС)',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.currentLevel.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  summary.currentLevel.label,
                  style: TextStyle(
                    color: summary.currentLevel.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // 2. Сводка: Восстановление vs Стресс (строгая палитра Sage / Rose)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ВОССТАНОВЛЕНИЕ',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${summary.minutesInRestoration ~/ 60}ч ${summary.minutesInRestoration % 60}м',
                        style: TextStyle(
                          color: AppColors.sage,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ВЫСОКИЙ СТРЕСС',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${summary.minutesInHighStress} мин',
                        style: TextStyle(
                          color: AppColors.rose,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),

          // 3. Каталог дня: Интерактивный Story-формат «День в 5 событиях»
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final updatedSummary = StressDaySummary(
                currentStressScore: summary.currentStressScore,
                currentLevel: summary.currentLevel,
                minutesInHighStress: summary.minutesInHighStress,
                minutesInRestoration: summary.minutesInRestoration,
                timeline: _slots,
              );
              CircaDayStoryDialog.show(
                context,
                stressSummary: updatedSummary,
                onTagUpdated: _updateTag,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.amber.withValues(alpha: 0.12),
                    AppColors.raised,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.amber, width: 1.5),
                      image: DecorationImage(
                        image: AssetImage(AvatarVisualState.genderedPath('assets/images/hero_barys_normal.jpg')),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'День в событиях',
                              style: TextStyle(
                                color: AppColors.fg,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.auto_stories, color: AppColors.amber, size: 12),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Story-просмотр дня с реакциями Барыса',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.amber,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // 4. Хронологическая лента дня с разметкой
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ХРОНОЛОГИЯ СТРЕССА СЕГОДНЯ',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              Text(
                'Тап для разметки',
                style: TextStyle(
                  color: AppColors.sage.withValues(alpha: 0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          for (final slot in _slots)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openTagPicker(slot),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: slot.userTag != null
                        ? AppColors.raised.withValues(alpha: 0.7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: slot.userTag != null
                        ? Border.all(color: slot.level.color.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Время слота
                      Container(
                        width: 76,
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          slot.timeRange.split(' — ')[0],
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Индикатор стресса (кружок со свечением)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 3, right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: slot.level.color,
                          boxShadow: [
                            BoxShadow(
                              color: slot.level.color.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),

                      // Описание, метка и шкала
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          slot.contextTitle,
                                          style: TextStyle(
                                            color: AppColors.fg,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (slot.userTag != null) ...[
                                        SizedBox(width: 6),
                                        Icon(Icons.edit, color: AppColors.muted, size: 10),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '${slot.stressScore}%',
                                  style: TextStyle(
                                    color: slot.level.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 3),

                            // Микро-шкала прогресса стресса (строго Sage/Amber/Rose)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: slot.stressScore / 100.0,
                                minHeight: 3,
                                backgroundColor: AppColors.line,
                                valueColor: AlwaysStoppedAnimation<Color>(slot.level.color),
                              ),
                            ),
                            SizedBox(height: 4),

                            Text(
                              slot.physiologicalNote,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showStressDetailModal(BuildContext context, StressTimeSlot slot) {
    CircaHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt, color: AppColors.rose, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ПЕРСОНАЛЬНЫЙ ПАТТЕРН СТРЕССА',
                        style: TextStyle(color: AppColors.rose, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Пик кортизола в 13:30 (${slot.userTag ?? 'Переговоры / Дедлайн'})',
                        style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                'На основе разметки за 30 дней в 13:30 регулярно фиксируется острый пик кортизола. Прогноз на завтра: вероятность стресса >75% равна 84%.',
                style: TextStyle(color: AppColors.fg, fontSize: 12, height: 1.4),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Рекомендация СААТ-1: за 10 минут до пиковой встречи переключитесь на дыхательный цикл 4-6 для активации парасимпатической нервной системы (блуждающего нерва).',
              style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.35, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _triggerBreathingPause();
                },
                icon: Icon(Icons.air, size: 16, color: AppColors.stage),
                label: Text(
                  'НАЧАТЬ ДЫХАТЕЛЬНУЮ ПАУЗУ 4-6',
                  style: TextStyle(color: AppColors.stage, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
