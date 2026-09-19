import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../domain/intelligence/stress_engine.dart';

/// Интерактивный полноэкранный Story-формат «День в 5 событиях»
/// с карточками хроники, реакциями Барыса, разметкой и шерингом.
class CircaDayStoryDialog extends StatefulWidget {
  final StressDaySummary stressSummary;
  final Function(String slotId, String newTag)? onTagUpdated;

  const CircaDayStoryDialog({
    super.key,
    required this.stressSummary,
    this.onTagUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required StressDaySummary stressSummary,
    Function(String slotId, String newTag)? onTagUpdated,
  }) async {
    HapticFeedback.mediumImpact();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CircaDayStory',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim, secondaryAnim) {
        return CircaDayStoryDialog(
          stressSummary: stressSummary,
          onTagUpdated: onTagUpdated,
        );
      },
    );
  }

  @override
  State<CircaDayStoryDialog> createState() => _CircaDayStoryDialogState();
}

class _CircaDayStoryDialogState extends State<CircaDayStoryDialog>
    with SingleTickerProviderStateMixin {
  late List<StressTimeSlot> _slots;
  int _currentIndex = 0;
  late AnimationController _progressController;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _slots = List.from(widget.stressSummary.timeline);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextStory();
      }
    });

    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _goToNextStory() {
    if (_currentIndex < _slots.length - 1) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex++;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      // Завершение историй
      Navigator.of(context).pop();
    }
  }

  void _goToPreviousStory() {
    if (_currentIndex > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex--;
      });
      _progressController.reset();
      _progressController.forward();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _pause() {
    if (!_isPaused) {
      _isPaused = true;
      _progressController.stop();
    }
  }

  void _resume() {
    if (_isPaused) {
      _isPaused = false;
      _progressController.forward();
    }
  }

  void _openTagPicker(StressTimeSlot slot) async {
    _pause();
    final newTag = await _showStoryTagSheet(context, slot);
    if (newTag != null && newTag.isNotEmpty) {
      setState(() {
        final updated = slot.copyWith(userTag: newTag, contextTitle: newTag);
        _slots[_currentIndex] = updated;
      });
      await StressEngine.saveSlotTag(slot.id, newTag);
      widget.onTagUpdated?.call(slot.id, newTag);
    }
    _resume();
  }

  void _shareEvent(StressTimeSlot slot) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.sage, width: 1),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.sage, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Событие «${slot.contextTitle}» (${slot.stressScore}%) экспортировано в сторис',
                style: const TextStyle(color: AppColors.fg, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slots[_currentIndex];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (_) => _pause(),
          onTapUp: (_) => _resume(),
          onTapCancel: () => _resume(),
          child: Stack(
            children: [
              // Контент карточки истории
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Индикаторы прогресса (5 сегментов)
                    Row(
                      children: List.generate(_slots.length, (index) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, _) {
                                double value = 0.0;
                                if (index < _currentIndex) {
                                  value = 1.0;
                                } else if (index == _currentIndex) {
                                  value = _progressController.value;
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: AppColors.lineStrong,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      index == _currentIndex
                                          ? slot.level.color
                                          : AppColors.fg,
                                    ),
                                    minHeight: 3,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Верхняя панель: инфо о событии и закрытие
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: slot.level.color, width: 1.5),
                            image: DecorationImage(
                              image: AssetImage(slot.barysAsset),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CIRCA СУТОЧНАЯ ХРОНИКА',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                            Text(
                              'Событие ${_currentIndex + 1} из ${_slots.length}',
                              style: const TextStyle(
                                color: AppColors.fg,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.muted, size: 22),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Основная карточка события
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: slot.level.color.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: slot.level.color.withValues(alpha: 0.08),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Изображение маскота Барыса в текущем состоянии
                            Expanded(
                              flex: 5,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    slot.barysAsset,
                                    fit: BoxFit.cover,
                                  ),
                                  // Градиентная подложка
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          AppColors.surface.withValues(alpha: 0.8),
                                          AppColors.surface,
                                        ],
                                        stops: const [0.5, 0.85, 1.0],
                                      ),
                                    ),
                                  ),
                                  // Временной бейдж на фото
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.stage.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.line),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.schedule, color: AppColors.muted, size: 12),
                                          const SizedBox(width: 6),
                                          Text(
                                            slot.timeRange,
                                            style: const TextStyle(
                                              color: AppColors.fg,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Уровень стресса
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: slot.level.color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: slot.level.color.withValues(alpha: 0.6),
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
                                              color: slot.level.color,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${slot.stressScore}% СТРЕСС',
                                            style: TextStyle(
                                              color: slot.level.color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Описание и реакции
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Название контекста / пользовательская разметка
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                slot.contextTitle,
                                                style: const TextStyle(
                                                  color: AppColors.fg,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (slot.userTag != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.amber.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: AppColors.amber.withValues(alpha: 0.4),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'МЕТКА',
                                                  style: TextStyle(
                                                    color: AppColors.amber,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          slot.physiologicalNote,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Реплика Барыса
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.raised,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.line),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: slot.level.color.withValues(alpha: 0.2),
                                            ),
                                            child: Icon(
                                              Icons.format_quote,
                                              color: slot.level.color,
                                              size: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'БАРЫС-БАТЫР',
                                                  style: TextStyle(
                                                    color: AppColors.amber,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  slot.barysReaction,
                                                  style: const TextStyle(
                                                    color: AppColors.fg,
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Действия по карточке
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _openTagPicker(slot),
                                            icon: const Icon(
                                              Icons.tune,
                                              size: 14,
                                              color: AppColors.fg,
                                            ),
                                            label: Text(
                                              slot.userTag != null ? 'Изменить' : 'Разметить',
                                              style: const TextStyle(
                                                color: AppColors.fg,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: AppColors.raised,
                                              side: const BorderSide(color: AppColors.line),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _shareEvent(slot),
                                            icon: const Icon(
                                              Icons.ios_share,
                                              size: 14,
                                              color: AppColors.stage,
                                            ),
                                            label: const Text(
                                              'В сторис',
                                              style: TextStyle(
                                                color: AppColors.stage,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: slot.level.color,
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Подсказка навигации
                    const Text(
                      'Удерживайте для паузы · Тап слева / справа для навигации',
                      style: TextStyle(
                        color: AppColors.faint,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Зоны тапа для навигации (левая треть экрана и правая треть экрана)
              Positioned(
                left: 0,
                top: 80,
                bottom: 120,
                width: size.width * 0.35,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _goToPreviousStory,
                ),
              ),
              Positioned(
                right: 0,
                top: 80,
                bottom: 120,
                width: size.width * 0.35,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _goToNextStory,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showStoryTagSheet(BuildContext context, StressTimeSlot slot) async {
    HapticFeedback.mediumImpact();
    final controller = TextEditingController(text: slot.userTag ?? '');

    const presets = [
      '💼 Переговоры',
      '⏰ Дедлайн',
      '🚗 Дорога / Пробка',
      '☕ Кофеин',
      '🏋️ Тренировка',
      '🔥 Конфликт',
      '📱 Соцсети',
      '🧘 Медитация',
      '🥗 Обед / Пища',
    ];

    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'РАЗМЕТКА СОБЫТИЯ (${slot.timeRange})',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  Text(
                    '${slot.stressScore}% стресс',
                    style: TextStyle(
                      color: slot.level.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Отметь причину пика или спада — через 30 дней ИИ Барыса начнет предсказывать триггеры стресса:',
                style: TextStyle(color: AppColors.fg, fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 14),

              // Быстрые теги
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
                        style: const TextStyle(color: AppColors.fg, fontSize: 12),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Ручной ввод
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: AppColors.fg, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Или введи свою причину...',
                        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
                        filled: true,
                        fillColor: AppColors.raised,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.sage),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                    child: const Text(
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
  }
}
