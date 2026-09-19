import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import '../widgets/bio_avatar_widget.dart';
import '../widgets/glass_card.dart';

class BioAvatarScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const BioAvatarScreen({
    super.key,
    required this.bleBridge,
  });

  @override
  State<BioAvatarScreen> createState() => _BioAvatarScreenState();
}

class _BioAvatarScreenState extends State<BioAvatarScreen> {
  late BleTelemetry _telemetry;
  late AvatarProfile _profile;
  final PersonalBaseline _baseline = const PersonalBaseline();
  AvatarVisualState? _selectedScenario;

  @override
  void initState() {
    super.initState();
    _selectedScenario = AvatarManager.demoOverride;
    _telemetry = widget.bleBridge.currentTelemetry;
    _profile = AvatarManager.getProfile(_telemetry, baseline: _baseline);

    widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _telemetry = data;
          _profile = AvatarManager.getProfile(data, baseline: _baseline);
        });
      }
    });
  }

  void _selectScenario(AvatarVisualState? state) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedScenario = state;
      AvatarManager.setDemoOverride(state);
      _profile = AvatarManager.getProfile(_telemetry, baseline: _baseline);
    });
  }

  void _showWorkoutStartDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.stage,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.line, width: 1.5)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              const Text(
                'РЕГИСТРАЦИЯ ТРЕНИРОВКИ (STRAIN)',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'XP Барысу начисляется строго за физиологическую нагрузку:',
                style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              _buildWorkoutOption(
                title: 'Аэробный кросс (Зона 2)',
                sub: '40 мин · +8.5 Strain · Выносливость миокарда',
                strain: 8.5,
                color: AppColors.sage,
              ),
              _buildWorkoutOption(
                title: 'Интервальный HIIT (Зона 4-5)',
                sub: '25 мин · +12.0 Strain · Сила и анаэробная емкость',
                strain: 12.0,
                color: AppColors.amber,
              ),
              _buildWorkoutOption(
                title: 'Силовая сессия в зале',
                sub: '50 мин · +9.8 Strain · Мышечный тонус',
                strain: 9.8,
                color: AppColors.sage,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkoutOption({
    required String title,
    required String sub,
    required double strain,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        HapticFeedback.heavyImpact();

        final result = await AvatarManager.recordWorkoutReward(activityStrain: strain);

        if (mounted) {
          setState(() {
            _profile = AvatarManager.getProfile(_telemetry, baseline: _baseline);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.line),
              ),
              content: Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Нагрузка +$strain Strain зачтена! +${result.addedXp} XP',
                    style: const TextStyle(
                      color: AppColors.fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );

          if (result.didLevelUp) {
            _showLevelUpDialog(result.level);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.directions_run, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              '+${(strain * 35).round()} XP',
              style: const TextStyle(
                color: AppColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLevelUpDialog(int newLevel) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.amber, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.amber, size: 24),
              SizedBox(width: 10),
              Text(
                'НОВЫЙ УРОВЕНЬ',
                style: TextStyle(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Уровень $newLevel',
                style: const TextStyle(
                  color: AppColors.fg,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AvatarManager.getRankTitle(newLevel),
                style: const TextStyle(
                  color: AppColors.sage,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Характеристики Батыра повышены за счет реальной физической нагрузки. Продолжайте закрывать целевой бюджет!',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'ПРОДОЛЖИТЬ',
                style: TextStyle(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stage,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.muted, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'БАРЫС-БАТЫР',
          style: TextStyle(
            color: AppColors.fg,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 6),

                    // 1. Аватар Барыса в скандинавском минимализме
                    Center(
                      child: BioAvatarWidget(
                        state: _profile.state,
                        bpm: _telemetry.heartRate,
                        size: 240,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Селектор сценариев Барыса
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildScenarioChip(null, 'Авто'),
                          _buildScenarioChip(AvatarVisualState.charged, 'Бодрый'),
                          _buildScenarioChip(AvatarVisualState.normal, 'В тонусе'),
                          _buildScenarioChip(AvatarVisualState.tired, 'Уставший'),
                          _buildScenarioChip(AvatarVisualState.sleep, 'Сон / Отбой'),
                          _buildScenarioChip(AvatarVisualState.postWorkout, 'После спорта'),
                          _buildScenarioChip(AvatarVisualState.meditation, 'Баланс / Дзен'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Цитата-ритуал Барыса
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.format_quote, color: AppColors.amber, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AvatarManager.getRitualQuote(_profile.state),
                              style: const TextStyle(
                                color: AppColors.fg,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. Карточка Ранга в стиле Circa
                    GlassCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _profile.rankTitle.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.amber,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Уровень ${_profile.level}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${_profile.currentXp} / ${_profile.maxXp} XP',
                                style: const TextStyle(
                                  color: AppColors.fg,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _profile.progressRatio,
                              backgroundColor: AppColors.raised,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.amber),
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 3. Статус ЦНС (бодрый или отдых)
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _profile.state.badgeColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile.state.title,
                                  style: TextStyle(
                                    color: _profile.state.badgeColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _profile.state.description,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 4. Три RPG характеристики от РЕАЛЬНЫХ сенсоров
                    Row(
                      children: [
                        Expanded(
                          child: _buildCircaStat('ВЫНОСЛИВОСТЬ', _profile.endurance, 'Зона 2 ЧСС', AppColors.sage),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCircaStat('СИЛА', _profile.power, 'Пик Strain / Z5', AppColors.amber),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCircaStat('ФОКУС', _profile.focus, 'Deep+REM сон', AppColors.sage),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 5. Ежедневные задачи (физиологические, а не кликер)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _profile.isPauseMode ? 'РЕЖИМ ПАУЗЫ (ЦНС)' : 'ЕЖЕДНЕВНЫЕ ЗАДАЧИ НАГРУЗКИ',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    ..._profile.quests.map((quest) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                quest.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: quest.isCompleted ? AppColors.sage : AppColors.faint,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quest.title,
                                      style: TextStyle(
                                        color: quest.isCompleted ? AppColors.fg : AppColors.muted,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${quest.current} / ${quest.target} ${quest.unit}',
                                      style: const TextStyle(
                                        color: AppColors.faint,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.raised,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${quest.rewardXp} XP',
                                  style: const TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Кнопка реальной тренировки (НЕ кликер!)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.stage,
                border: Border(top: BorderSide(color: AppColors.line, width: 1.0)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _profile.isPauseMode ? AppColors.raised : AppColors.amber,
                    foregroundColor: _profile.isPauseMode ? AppColors.muted : AppColors.stage,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _profile.isPauseMode ? null : _showWorkoutStartDialog,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_profile.isPauseMode ? Icons.bedtime : Icons.directions_run, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _profile.isPauseMode ? 'РЕЖИМ ЗАЩИТЫ ЦНС (ОТДЫХ)' : 'ЗАФИКСИРОВАТЬ ТРЕНИРОВКУ (STRAIN)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioChip(AvatarVisualState? state, String label) {
    final isSelected = _selectedScenario == state;
    final color = state?.badgeColor ?? AppColors.amber;
    return GestureDetector(
      onTap: () => _selectScenario(state),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.line,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.fg : AppColors.muted,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircaStat(String title, int value, String sub, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.fg,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: const TextStyle(
              color: AppColors.faint,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}
