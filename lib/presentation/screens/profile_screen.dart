import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/circa_morning_briefing_dialog.dart';
import '../widgets/circa_text_field.dart';
import '../widgets/glass_card.dart';
import 'auth_screen.dart';
import 'device_settings_screen.dart';
import 'private_league_screen.dart';
import 'menstrual_cycle_screen.dart';
import 'sport_screen.dart';
import '../../core/circa_haptics.dart';

class ProfileScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const ProfileScreen({super.key, required this.bleBridge});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = const UserProfile();
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _birthYearController;
  late TextEditingController _stepGoalController;
  late TextEditingController _calorieGoalController;
  bool _is24h = true;
  bool _isSaving = false;
  int _versionTapCount = 0;
  DateTime? _lastVersionTap;
  bool _isTiredDemo = false;
  bool _isCrisisMode = false;
  bool _isCalibrationDemo = false;

  @override
  void initState() {
    super.initState();
    _isTiredDemo = widget.bleBridge.isTiredDemo;
    _isCrisisMode = widget.bleBridge.isCrisisDemo;
    _nameController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _birthYearController = TextEditingController();
    _stepGoalController = TextEditingController();
    _calorieGoalController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await UserProfileRepository.loadProfile();
    if (mounted) {
      setState(() {
        _profile = p;
        _nameController.text = p.name;
        _heightController.text = p.heightCm.toStringAsFixed(0);
        _weightController.text = p.weightKg.toStringAsFixed(1);
        _birthYearController.text = p.birthYear.toString();
        _stepGoalController.text = p.stepGoal.toString();
        _calorieGoalController.text = p.calorieGoal.toString();
        _is24h = p.is24HourFormat;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _birthYearController.dispose();
    _stepGoalController.dispose();
    _calorieGoalController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final updated = _profile.copyWith(
      name: _nameController.text.trim(),
      heightCm: double.tryParse(_heightController.text) ?? _profile.heightCm,
      weightKg: double.tryParse(_weightController.text) ?? _profile.weightKg,
      birthYear: int.tryParse(_birthYearController.text) ?? _profile.birthYear,
      stepGoal: int.tryParse(_stepGoalController.text) ?? _profile.stepGoal,
      calorieGoal: int.tryParse(_calorieGoalController.text) ?? _profile.calorieGoal,
      is24HourFormat: _is24h,
    );

    await UserProfileRepository.saveProfile(updated);
    if (!mounted) return;
    setState(() {
      _profile = updated;
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            Icon(Icons.check, color: AppColors.sage, size: 20),
            SizedBox(width: 10),
            Text(
              'Профиль и физиологические цели сохранены',
              style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Выйти из системы?', style: TextStyle(color: AppColors.fg, fontSize: 16)),
        content: const Text(
          'Синхронизация биометрии будет приостановлена до повторного входа.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('ОТМЕНА', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                if (Firebase.apps.isNotEmpty) {
                  await FirebaseAuth.instance.signOut();
                }
              } catch (e) {
                debugPrint('Firebase signOut notice: $e');
              }
              await UserProfileRepository.setAuthenticated(false);
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => AuthScreen(bleBridge: widget.bleBridge),
                ),
                (route) => false,
              );
            },
            child: const Text('ВЫЙТИ', style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.stage,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Column(
              children: [
                Text(
                  AppStrings.tr('profile_title', language),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
                Text(
                  language == AppLanguage.kyrgyz ? 'Биометрия жана Орнотуулар' : 'Биометрия и Настройки',
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.rose, size: 20),
                tooltip: AppStrings.tr('profile_logout', language),
                onPressed: _logout,
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Баннер тревоги при активном режиме «ГРОЗА»
            if (_isCrisisMode)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.rose, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '⚡ РЕЖИМ «ГРОЗА» АКТИВЕН',
                            style: TextStyle(
                              color: AppColors.rose,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'ЧСС 118 bpm · ВСР 22 мс · Стресс 89% (Критическая зона)',
                            style: TextStyle(color: AppColors.fg, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isCrisisMode = false;
                          widget.bleBridge.setDemoCrisis(false);
                        });
                      },
                      child: const Text('ВЫКЛ', style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                  ],
                ),
              ),

            // Биометрический паспорт CIRCA
            _buildBiometricPassportCard(),
            const SizedBox(height: 20),

            // Карточка подключенного браслета с переходом в DeviceSettings
            GlassCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DeviceSettingsScreen(bleBridge: widget.bleBridge),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.raised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.watch,
                      color: telemetry.isConnected ? AppColors.sage : AppColors.muted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          telemetry.deviceName,
                          style: const TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Заряд: ${telemetry.batteryLevel}% · BLE 5.3',
                          style: const TextStyle(color: AppColors.sage, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.settings, color: AppColors.muted, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 16),

            // Интерактивная плашка «Биометрия и суточные цели»
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune, color: AppColors.amber, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'БИОМЕТРИЯ И ЦЕЛИ',
                            style: TextStyle(
                              color: AppColors.fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _showBiodataModal,
                        icon: const Icon(Icons.edit_outlined, color: AppColors.amber, size: 14),
                        label: const Text(
                          'ИЗМЕНИТЬ',
                          style: TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildMetricSummary('РОСТ', '${_profile.heightCm.toInt()} см'),
                      const SizedBox(width: 8),
                      _buildMetricSummary('ВЕС', '${_profile.weightKg.toStringAsFixed(1)} кг'),
                      const SizedBox(width: 8),
                      _buildMetricSummary('ИМТ', '${_profile.bmi.toStringAsFixed(1)} (Норма)', color: AppColors.sage),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMetricSummary('ЦЕЛЬ ШАГОВ', '${_profile.stepGoal}'),
                      const SizedBox(width: 8),
                      _buildMetricSummary('ЦЕЛЬ ККАЛ', '${_profile.calorieGoal} ккал'),
                      const SizedBox(width: 8),
                      _buildMetricSummary(
                        'ПОЛ',
                        _profile.gender == Gender.female ? 'Женский' : 'Мужской',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Сообщество и Приватные лиги
            const Text(
              'СООБЩЕСТВО И ПРИВАТНЫЕ ЛИГИ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            GlassCard(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  CircaHaptics.ringZoneTick();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PrivateLeagueScreen(bleBridge: widget.bleBridge),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield_outlined, color: AppColors.amber, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Приватная лига: «КРУГ БАТЫРОВ»',
                              style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '4 из 5 участников · Узкий круг доверия',
                              style: TextStyle(color: AppColors.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.faint),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Язык интерфейса / Интерфейс тили (RU / KG)
            _buildLanguageSelectorCard(language),
            const SizedBox(height: 24),

            // Версия прошивки с 7-кратным тапом для инженерного меню
            Center(
              child: GestureDetector(
                onTap: _handleVersionTap,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  child: Text(
                    'KALKAN SPORT · СААТ-1 v1.4.2 · Сборка 2026.09',
                    style: TextStyle(
                      color: AppColors.faint,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildLanguageSelectorCard(AppLanguage currentLanguage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.tr('profile_language_section', currentLanguage),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.language, color: AppColors.amber, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Тил тандоо / Выбор языка',
                        style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      currentLanguage.shortTitle,
                      style: const TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildLangButton(
                      language: AppLanguage.russian,
                      isActive: currentLanguage == AppLanguage.russian,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLangButton(
                      language: AppLanguage.kyrgyz,
                      isActive: currentLanguage == AppLanguage.kyrgyz,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLangButton({required AppLanguage language, required bool isActive}) {
    return GestureDetector(
      onTap: () {
        AppLocaleNotifier.setLanguage(language);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.amber.withValues(alpha: 0.16) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.amber : AppColors.line,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(language.flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              '${language.title} (${language.shortTitle})',
              style: TextStyle(
                color: isActive ? AppColors.fg : AppColors.muted,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleVersionTap() {
    final now = DateTime.now();
    if (_lastVersionTap == null || now.difference(_lastVersionTap!).inSeconds > 3) {
      _versionTapCount = 1;
    } else {
      _versionTapCount++;
    }
    _lastVersionTap = now;

    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      HapticFeedback.heavyImpact();
      _showDeveloperMenu();
    }
  }

  void _showDeveloperMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.stage,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.line, width: 1.0)),
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
                  'ИНЖЕНЕРНОЕ МЕНЮ (KALKAN DEV)',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 14),

                // Режим «ГРОЗА» (Кризис ЦНС и стресс)
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '⚡ Режим «ГРОЗА» (Кризис и тревога)',
                              style: TextStyle(color: AppColors.rose, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'ЧСС 118, ВСР 22мс, стресс 89% (Red Zone)',
                              style: TextStyle(color: AppColors.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isCrisisMode,
                        activeThumbColor: AppColors.rose,
                        onChanged: (val) {
                          HapticFeedback.heavyImpact();
                          setSheetState(() => _isCrisisMode = val);
                          setState(() {
                            _isCrisisMode = val;
                            widget.bleBridge.setDemoCrisis(val);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Демо усталости
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Демо: Уставший организм (Red Zone)',
                        style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Switch(
                        value: _isTiredDemo,
                        activeThumbColor: AppColors.rose,
                        onChanged: (val) {
                          setSheetState(() => _isTiredDemo = val);
                          setState(() {
                            widget.bleBridge.setDemoTired(val);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Демо калибровки
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Демо: 14 дней калибровки профиля',
                        style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Switch(
                        value: _isCalibrationDemo,
                        activeThumbColor: AppColors.amber,
                        onChanged: (val) {
                          setSheetState(() => _isCalibrationDemo = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Кнопка утреннего отчета
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.wb_sunny_outlined, color: AppColors.amber, size: 18),
                    label: const Text(
                      'Тест утреннего отчета 07:00 (Briefing)',
                      style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      CircaMorningBriefingDialog.show(
                        context,
                        widget.bleBridge.currentTelemetry,
                        const PersonalBaseline(),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricSummary(String title, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: color ?? AppColors.fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _profile.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Имя атлета',
          style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: CircaTextField(
          label: 'Ваше имя',
          controller: controller,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ОТМЕНА', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final updated = _profile.copyWith(name: newName);
                setState(() => _profile = updated);
                await UserProfileRepository.saveProfile(updated);
                CircaHaptics.success();
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.stage,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('СОХРАНИТЬ', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showBiodataModal() {
    CircaHaptics.selectionClick();
    final hCtrl = TextEditingController(text: _profile.heightCm.toInt().toString());
    final wCtrl = TextEditingController(text: _profile.weightKg.toString());
    final bCtrl = TextEditingController(text: _profile.birthYear.toString());
    final sCtrl = TextEditingController(text: _profile.stepGoal.toString());
    final cCtrl = TextEditingController(text: _profile.calorieGoal.toString());
    Gender tempGender = _profile.gender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'БИОМЕТРИЯ И ЦЕЛИ',
                        style: TextStyle(
                          color: AppColors.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: AppColors.muted, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Выбор пола
                  const Text(
                    'ПОЛ АТЛЕТА',
                    style: TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            CircaHaptics.selectionClick();
                            setModalState(() => tempGender = Gender.male);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: tempGender == Gender.male ? AppColors.raised : AppColors.stage,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: tempGender == Gender.male ? AppColors.amber : AppColors.line,
                                width: tempGender == Gender.male ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.male, size: 16, color: tempGender == Gender.male ? AppColors.amber : AppColors.muted),
                                const SizedBox(width: 6),
                                Text(
                                  'Мужской',
                                  style: TextStyle(
                                    color: tempGender == Gender.male ? AppColors.fg : AppColors.muted,
                                    fontSize: 12,
                                    fontWeight: tempGender == Gender.male ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            CircaHaptics.selectionClick();
                            setModalState(() => tempGender = Gender.female);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: tempGender == Gender.female ? AppColors.raised : AppColors.stage,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: tempGender == Gender.female ? AppColors.amber : AppColors.line,
                                width: tempGender == Gender.female ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.female, size: 16, color: tempGender == Gender.female ? AppColors.amber : AppColors.muted),
                                const SizedBox(width: 6),
                                Text(
                                  'Женский',
                                  style: TextStyle(
                                    color: tempGender == Gender.female ? AppColors.fg : AppColors.muted,
                                    fontSize: 12,
                                    fontWeight: tempGender == Gender.female ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: CircaTextField(
                          label: 'Рост (см)',
                          controller: hCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CircaTextField(
                          label: 'Вес (кг)',
                          controller: wCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CircaTextField(
                          label: 'Год рожд.',
                          controller: bCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: CircaTextField(
                          label: 'Цель шагов',
                          controller: sCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CircaTextField(
                          label: 'Цель ккал',
                          controller: cCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final h = double.tryParse(hCtrl.text) ?? _profile.heightCm;
                        final w = double.tryParse(wCtrl.text) ?? _profile.weightKg;
                        final b = int.tryParse(bCtrl.text) ?? _profile.birthYear;
                        final s = int.tryParse(sCtrl.text) ?? _profile.stepGoal;
                        final c = int.tryParse(cCtrl.text) ?? _profile.calorieGoal;

                        final updated = _profile.copyWith(
                          gender: tempGender,
                          heightCm: h,
                          weightKg: w,
                          birthYear: b,
                          stepGoal: s,
                          calorieGoal: c,
                          cycleDay: tempGender == Gender.female ? (_profile.cycleDay ?? 14) : null,
                          lastPeriodStartDate: tempGender == Gender.female
                              ? (_profile.lastPeriodStartDate ?? DateTime.now().subtract(const Duration(days: 14)))
                              : null,
                        );

                        setState(() => _profile = updated);
                        await UserProfileRepository.saveProfile(updated);
                        CircaHaptics.success();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: AppColors.stage,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'СОХРАНИТЬ БИОДАННЫЕ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Карточка атлета в строгом спортивно-технологичном стиле KALKAN
  Widget _buildBiometricPassportCard() {
    final birthYear = _profile.birthYear;
    final currentYear = DateTime.now().year;
    final chronoAge = (currentYear - birthYear).clamp(16, 99);
    final bioAge = (chronoAge - 4).clamp(14, 95);
    final initials = _profile.name.isNotEmpty
        ? _profile.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join()
        : 'АК';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Верхняя шапка удостоверения
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.raised.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.amber.withValues(alpha: 0.2),
                  width: 0.8,
                ),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'КЫРГЫЗ РЕСПУБЛИКАСЫ · БИОМЕТРИЯ РЕГИСТРИ',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'KALKAN ID-KG · № 784-092/26',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Основная часть: монограмма атлета + данные
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Инициалы / бейдж атлета
                Container(
                  width: 72,
                  height: 86,
                  decoration: BoxDecoration(
                    color: AppColors.stage,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Icon(
                          Icons.crop_free,
                          color: AppColors.amber.withValues(alpha: 0.4),
                          size: 10,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Icon(
                          Icons.crop_free,
                          color: AppColors.amber.withValues(alpha: 0.4),
                          size: 10,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            initials,
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'VERIFIED',
                              style: TextStyle(
                                color: AppColors.amber,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Метаданные атлета
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Имя владельца + кнопка быстрого редактирования имени
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _profile.name.isNotEmpty ? _profile.name.toUpperCase() : 'АЛИХАН',
                              style: const TextStyle(
                                color: AppColors.fg,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: _showEditNameDialog,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: const [
                                  Icon(Icons.edit_outlined, color: AppColors.amber, size: 14),
                                  SizedBox(width: 3),
                                  Text(
                                    'ИЗМЕНИТЬ',
                                    style: TextStyle(
                                      color: AppColors.amber,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'АТЛЕТ ВЫСШЕЙ КАТЕГОРИИ · УРОВЕНЬ BATYR',
                        style: TextStyle(
                          color: AppColors.sage,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Таблица характеристик
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ХРОНО / БИО-ВОЗРАСТ',
                                  style: TextStyle(color: AppColors.faint, fontSize: 8, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    text: '$chronoAge ',
                                    style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w700),
                                    children: [
                                      TextSpan(
                                        text: '/ $bioAge лет',
                                        style: const TextStyle(color: AppColors.sage, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'СТАТУС АТЛЕТА',
                                  style: TextStyle(color: AppColors.faint, fontSize: 8, fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'ВЕРИФИЦИРОВАН (СААТ-1)',
                                  style: TextStyle(color: AppColors.amber, fontSize: 10.5, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Нижняя статусная строка карточки
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(
                top: BorderSide(
                  color: AppColors.line.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
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
                const Text(
                  'СИНХРОНИЗАЦИЯ БИОМЕТРИИ АКТИВНА · СААТ-1 СЕНСОР',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
