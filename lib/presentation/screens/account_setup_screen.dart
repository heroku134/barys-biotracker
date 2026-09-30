import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/services/health_sync_service.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/glass_card.dart';
import 'device_pair_screen.dart';
import 'main_shell.dart';

/// Полноценный экран первичной настройки биометрического профиля после регистрации
class AccountSetupScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  const AccountSetupScreen({super.key, required this.bleBridge});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _nameController = TextEditingController();
  final _heightController = TextEditingController(text: '175');
  final _weightController = TextEditingController(text: '72');
  DateTime _birthDate = DateTime(1996, 6, 15);
  Gender _gender = Gender.male;
  String _selectedGoal = 'endurance';
  int _step = 0; // 0: Биометрия, 1: Подключение СААТ-1, 2: Apple Health / Health Connect
  bool _isSyncingHealth = false;

  @override
  void initState() {
    super.initState();
    UserProfileRepository.loadProfile().then((p) {
      if (mounted) {
        setState(() {
          if (p.name.isNotEmpty && p.name != 'Гость' && p.name != 'Алихан') {
            _nameController.text = p.name;
          }
          if (p.heightCm > 0) _heightController.text = p.heightCm.toInt().toString();
          if (p.weightKg > 0) _weightController.text = p.weightKg.toInt().toString();
          if (p.birthYear > 1920 && p.birthYear <= DateTime.now().year - 10) {
            _birthDate = DateTime(p.birthYear, 6, 15);
          }
          _gender = p.gender;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  int get _calculatedAge => (DateTime.now().year - _birthDate.year).clamp(12, 100);
  int get _calculatedMaxHr => (220 - _calculatedAge).clamp(140, 220);

  double get _calculatedBmi {
    final h = double.tryParse(_heightController.text.replaceAll(',', '.')) ?? 175.0;
    final w = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 72.0;
    if (h <= 0) return 22.0;
    return w / ((h / 100.0) * (h / 100.0));
  }

  String get _bmiInterpretation {
    final bmi = _calculatedBmi;
    if (bmi < 18.5) return 'Дефицит веса';
    if (bmi < 25.0) return 'Норма';
    if (bmi < 30.0) return 'Избыточный вес';
    return 'Высокий ИМТ';
  }

  Color get _bmiColor {
    final bmi = _calculatedBmi;
    if (bmi >= 18.5 && bmi < 25.0) return AppColors.sage;
    if (bmi < 18.5 || (bmi >= 25.0 && bmi < 30.0)) return AppColors.amber;
    return AppColors.rose;
  }

  Future<void> _pickBirthDate() async {
    CircaHaptics.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1930),
      lastDate: DateTime(DateTime.now().year - 10),
      helpText: AppLocaleNotifier.pick(
        'Выберите дату рождения',
        'Туулган күнүңүздү тандаңыз',
        'Select Date of Birth',
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.amber,
              onPrimary: Colors.black,
              surface: AppColors.surface,
              onSurface: AppColors.fg,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _saveBiometrics() async {
    CircaHaptics.selectionClick();
    final name = _nameController.text.trim();
    final h = double.tryParse(_heightController.text.replaceAll(',', '.')) ?? 175.0;
    final w = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 72.0;

    int stepGoal = 10000;
    int calorieGoal = 650;
    double sleepGoal = 8.0;
    switch (_selectedGoal) {
      case 'endurance':
        stepGoal = 12000;
        calorieGoal = 750;
        sleepGoal = 8.5;
        break;
      case 'strength':
        stepGoal = 8000;
        calorieGoal = 650;
        sleepGoal = 8.5;
        break;
      case 'fat_loss':
        stepGoal = 10000;
        calorieGoal = 800;
        sleepGoal = 8.0;
        break;
      case 'health':
        stepGoal = 8000;
        calorieGoal = 500;
        sleepGoal = 8.0;
        break;
    }

    final p = await UserProfileRepository.loadProfile();
    final updated = p.copyWith(
      name: name.isNotEmpty ? name : (p.name.isNotEmpty ? p.name : 'Атлет'),
      heightCm: h.clamp(100.0, 240.0),
      weightKg: w.clamp(30.0, 250.0),
      birthYear: _birthDate.year,
      gender: _gender,
      stepGoal: stepGoal,
      calorieGoal: calorieGoal,
      sleepGoalHours: sleepGoal,
      isAuthenticated: true,
      hasCompletedProfile: true,
    );
    await UserProfileRepository.saveProfile(updated);
    setState(() => _step = 1);
  }

  Future<void> _proceedToHealthSync({required bool pair}) async {
    CircaHaptics.selectionClick();
    if (pair) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DevicePairScreen(bleBridge: widget.bleBridge),
      ));
    }
    if (!mounted) return;
    setState(() => _step = 2);
  }

  Future<void> _syncHealth() async {
    CircaHaptics.selectionClick();
    setState(() => _isSyncingHealth = true);
    try {
      await HealthSyncService.requestPermissions();
      final report = await HealthSyncService.syncAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(report.message),
            backgroundColor: AppColors.sage,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Onboarding health sync note: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncingHealth = false);
        _enterMainShell();
      }
    }
  }

  void _skipHealthSync() {
    CircaHaptics.selectionClick();
    _enterMainShell();
  }

  void _enterMainShell() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => MainShell(bleBridge: widget.bleBridge)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: palette.fg, size: 20),
                onPressed: () {
                  CircaHaptics.selectionClick();
                  setState(() => _step--);
                },
              )
            : null,
        title: Text(
          _step == 0
              ? AppLocaleNotifier.pick('Настройка профиля', 'Профилди жөндөө', 'Profile Setup')
              : (_step == 1
                  ? AppLocaleNotifier.pick('Часы СААТ-1', 'СААТ-1 сааты', 'SAAT-1 Watch')
                  : AppLocaleNotifier.pick('Синхронизация здоровья', 'Ден соолукту байланыштыруу', 'Health Sync')),
          style: AppTypography.screenTitle(palette.fg),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Индикатор шагов (1/3, 2/3, 3/3)
            Row(
              children: List.generate(3, (index) {
                final isActive = index <= _step;
                final isCurrent = index == _step;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : 4,
                      right: index == 2 ? 0 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.amber
                          : (isActive ? AppColors.sage : palette.hairline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            if (_step == 0) ...[
              Text(
                AppLocaleNotifier.pick(
                  'Укажите ваши персональные данные. Они необходимы для точного расчёта пульсовых зон, сожжённых калорий и готовности нервной системы.',
                  'Жеке маалыматтарыңызды киргизиңиз. Алар калория, жүрөк кагышынын зоналарын жана калыбына келүүнү так эсептөө үчүн керек.',
                  'Enter your personal biometric details. They calibrate your heart rate zones, calories burned and recovery score.',
                ),
                style: AppTypography.caption(palette.secondary).copyWith(height: 1.45),
              ),
              const SizedBox(height: 16),

              // 1. Имя пользователя
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleNotifier.pick('Ваше имя', 'Сиздин атыңыз', 'Your Name'),
                      style: AppTypography.caption(palette.secondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: palette.fg, fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: AppLocaleNotifier.pick('Например, Дастан', 'Мисалы, Дастан', 'e.g. Alex'),
                        hintStyle: TextStyle(color: palette.muted),
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.amber, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: palette.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: palette.hairline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.amber),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Выбор пола
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleNotifier.pick('Биологический пол', 'Биологиялык жыныс', 'Biological Sex'),
                      style: AppTypography.caption(palette.secondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _genderCard(
                            palette,
                            Gender.male,
                            AppLocaleNotifier.pick('Мужской', 'Эркек', 'Male'),
                            Icons.male,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _genderCard(
                            palette,
                            Gender.female,
                            AppLocaleNotifier.pick('Женский', 'Аял', 'Female'),
                            Icons.female,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocaleNotifier.pick(
                        'Влияет на формулы базального метаболизма и гормональный трекинг цикла.',
                        'Негизги зат алмашуу жана цикл трекинги үчүн керек.',
                        'Calibrates basal metabolic rate and hormonal cycle telemetry.',
                      ),
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Дата рождения и возраст
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocaleNotifier.pick('Дата рождения', 'Туулган күнү', 'Date of Birth'),
                          style: AppTypography.caption(palette.secondary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$_calculatedAge лет · Max HR: $_calculatedMaxHr bpm',
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickBirthDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: palette.raised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: palette.hairline),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined, color: AppColors.amber, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  '${_birthDate.day.toString().padLeft(2, '0')}.${_birthDate.month.toString().padLeft(2, '0')}.${_birthDate.year}',
                                  style: TextStyle(color: palette.fg, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Icon(Icons.edit_calendar_outlined, color: palette.secondary, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 4. Рост, вес и ИМТ
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocaleNotifier.pick('Рост и вес', 'Бою жана салмагы', 'Height & Weight'),
                          style: AppTypography.caption(palette.secondary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _bmiColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ИМТ: ${_calculatedBmi.toStringAsFixed(1)} · $_bmiInterpretation',
                            style: TextStyle(
                              color: _bmiColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: palette.fg, fontSize: 16, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: AppLocaleNotifier.pick('Рост, см', 'Бою, см', 'Height, cm'),
                              labelStyle: TextStyle(color: palette.secondary),
                              suffixText: 'см',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: palette.hairline),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: palette.fg, fontSize: 16, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: AppLocaleNotifier.pick('Вес, кг', 'Салмагы, кг', 'Weight, kg'),
                              labelStyle: TextStyle(color: palette.secondary),
                              suffixText: 'кг',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: palette.hairline),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 5. Цель тренировок
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleNotifier.pick('Основная цель', 'Негизги максат', 'Primary Goal'),
                      style: AppTypography.caption(palette.secondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _goalChip('endurance', AppLocaleNotifier.pick('🏃 Выносливость', '🏃 Чыдамкайлык', '🏃 Endurance')),
                        _goalChip('strength', AppLocaleNotifier.pick('🏋️ Сила и мышцы', '🏋️ Күч жана булчуң', '🏋️ Strength')),
                        _goalChip('weight_loss', AppLocaleNotifier.pick('🔥 Сжигание жира', '🔥 Май күйгүзүү', '🔥 Fat Loss')),
                        _goalChip('health', AppLocaleNotifier.pick('🌿 Здоровье и тонус', '🌿 Ден соолук', '🌿 Health & Tone')),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Кнопка перехода к часам
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveBiometrics,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    AppLocaleNotifier.pick('Сохранить и продолжить', 'Сактоо жана улантуу', 'Save & Continue'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),
              ),
            ] else if (_step == 1) ...[
              // ШАГ 2: Подключение часов СААТ-1
              Text(
                AppLocaleNotifier.pick(
                  'СААТ-1 — водонепроницаемый браслет без экрана. Он передаёт ЧСС, ВСР (HRV), температуру и минуты сна каждую секунду.',
                  'СААТ-1 экраны жок браслет. Ал жүрөк кагышын, HRV жана уйкуну реалдуу убакытта өткөрүп берет.',
                  'SAAT-1 is a screenless biometric band that streams live HR, HRV, skin temp and sleep stages.',
                ),
                style: AppTypography.caption(palette.secondary).copyWith(height: 1.45),
              ),
              const SizedBox(height: 20),

              Center(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.raised,
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber.withValues(alpha: 0.15),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.watch_outlined,
                    size: 64,
                    color: AppColors.amber,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _proceedToHealthSync(pair: true),
                  icon: const Icon(Icons.bluetooth_searching, size: 20),
                  label: Text(
                    AppLocaleNotifier.pick('Подключить СААТ-1', 'СААТ-1 саатын туташтыруу', 'Pair SAAT-1 Watch'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _proceedToHealthSync(pair: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.fg,
                    side: BorderSide(color: palette.hairline),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    AppLocaleNotifier.pick('Пропустить подключение часов', 'Саатты кийинчерээк туташтыруу', 'Skip Watch Pairing'),
                    style: TextStyle(color: palette.secondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else ...[
              // ШАГ 3: Синхронизация с Apple Health / Google Health Connect
              Text(
                Platform.isIOS
                    ? AppLocaleNotifier.pick(
                        'Синхронизируйте KALKAN SPORT с Apple Health, чтобы объединить данные сна, пульса и тренировок из сторонних приложений (Strava, Apple Fitness, Garmin).',
                        'Strava, Apple Fitness жана Garmin машыгууларын бириктирүү үчүн KALKAN SPORTту Apple Health менен байланыштырыңыз.',
                        'Sync KALKAN SPORT with Apple Health to combine sleep, HR and workouts from third-party apps (Strava, Apple Fitness, Garmin).',
                      )
                    : AppLocaleNotifier.pick(
                        'Синхронизируйте KALKAN SPORT с Google Health Connect, чтобы автоматически подтягивать пробежки, заезды и тренировки из Strava, Garmin и других приложений.',
                        'Strava, Garmin жана башка колдонмолордон машыгууларды жүктөө үчүн Google Health Connect менен байланыштырыңыз.',
                        'Sync KALKAN SPORT with Google Health Connect to import runs, rides and workouts from Strava, Garmin and other apps.',
                      ),
                style: AppTypography.caption(palette.secondary).copyWith(height: 1.45),
              ),
              const SizedBox(height: 20),

              // Hero Card
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.raised,
                    border: Border.all(color: AppColors.sage.withValues(alpha: 0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sage.withValues(alpha: 0.15),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Icon(
                    Platform.isIOS ? Icons.favorite_rounded : Icons.health_and_safety_rounded,
                    size: 50,
                    color: AppColors.sage,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  Platform.isIOS ? 'Apple HealthKit' : 'Google Health Connect',
                  style: TextStyle(
                    color: palette.fg,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  AppLocaleNotifier.pick(
                    'Двусторонний обмен данными и авто-импорт',
                    'Эки тараптуу маалымат алмашуу жана авто-импорт',
                    'Two-Way Data Exchange & Auto-Import',
                  ),
                  style: AppTypography.caption(palette.secondary),
                ),
              ),

              const SizedBox(height: 18),

              // Поддерживаемые источники (чипы)
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _sourceChip(
                      label: Platform.isIOS ? 'Apple Health' : 'Health Connect',
                      icon: Icons.monitor_heart,
                      color: AppColors.sage,
                    ),
                    _sourceChip(
                      label: 'Strava',
                      icon: Icons.directions_bike,
                      color: const Color(0xFFFC5200),
                    ),
                    _sourceChip(
                      label: 'Garmin',
                      icon: Icons.navigation_rounded,
                      color: const Color(0xFF007CC3),
                    ),
                    _sourceChip(
                      label: Platform.isIOS ? 'Fitness' : 'Samsung Health',
                      icon: Icons.fitness_center,
                      color: AppColors.amber,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Преимущества синхронизации
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _benefitRow(
                      palette: palette,
                      icon: Icons.sync_alt_rounded,
                      iconColor: AppColors.amber,
                      title: AppLocaleNotifier.pick(
                        'Чтение внешних тренировок',
                        'Сырткы машыгууларды окуу',
                        'External Workouts Sync',
                      ),
                      desc: AppLocaleNotifier.pick(
                        'Если вы плавали или бегали со Strava/Garmin без телефона, сессия автоматически подтянется.',
                        'Эгер Strava же Garmin менен телефонсуз машыксаңыз, сессия автоматтык түрдө кошулат.',
                        'If you ran or swam with Strava/Garmin without your phone, sessions are imported automatically.',
                      ),
                    ),
                    Divider(color: palette.hairline, height: 24),
                    _benefitRow(
                      palette: palette,
                      icon: Icons.bolt_rounded,
                      iconColor: AppColors.sage,
                      title: AppLocaleNotifier.pick(
                        'Автоматический Strain',
                        'Автоматтык Strain эсептөө',
                        'Automatic Strain',
                      ),
                      desc: AppLocaleNotifier.pick(
                        'Кардионагрузка рассчитывается по пульсовым зонам KALKAN и добавляется в дневной баланс.',
                        'Жүрөк жүктөмү KALKAN пульс зоналары менен эсептелип, күндүк баланска кошулат.',
                        'Cardiovascular load is calibrated to KALKAN heart zones and adds to your daily balance.',
                      ),
                    ),
                    Divider(color: palette.hairline, height: 24),
                    _benefitRow(
                      palette: palette,
                      icon: Icons.pets_rounded,
                      iconColor: AppColors.accent,
                      title: AppLocaleNotifier.pick(
                        'Прокачка Барыса (XP)',
                        'Барысты өстүрүү (XP)',
                        'Barys Experience (XP)',
                      ),
                      desc: AppLocaleNotifier.pick(
                        'Каждая сессия приносит очки опыта вашему барсу-маскоту.',
                        'Ар бир машыгуу маскотуңузга тажрыйба упайларын алып келет.',
                        'Every workout awards experience points to your mascot companion.',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Кнопка 1: Синхронизировать
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSyncingHealth ? null : _syncHealth,
                  icon: _isSyncingHealth
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 20),
                  label: Text(
                    _isSyncingHealth
                        ? AppLocaleNotifier.pick('Синхронизация...', 'Синхрондолууда...', 'Syncing...')
                        : AppLocaleNotifier.pick('Синхронизировать', 'Синхрондоштуруу', 'Enable Health Sync'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Кнопка 2: Пропустить
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSyncingHealth ? null : _skipHealthSync,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.fg,
                    side: BorderSide(color: palette.hairline),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    AppLocaleNotifier.pick('Пропустить', 'Өткөрүп жиберүү', 'Skip for Now'),
                    style: TextStyle(color: palette.secondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _genderCard(KalkanColors palette, Gender g, String label, IconData icon) {
    final isSelected = _gender == g;
    return GestureDetector(
      onTap: () {
        CircaHaptics.selectionClick();
        setState(() => _gender = g);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.amber.withValues(alpha: 0.16) : palette.raised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.amber : palette.hairline,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.amber : palette.secondary, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.amber : palette.fg,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalChip(String id, String label) {
    final isSelected = _selectedGoal == id;
    return GestureDetector(
      onTap: () {
        CircaHaptics.selectionClick();
        setState(() => _selectedGoal = id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sage.withValues(alpha: 0.18) : AppColors.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.sage : AppColors.hairline,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.sage : AppColors.muted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _sourceChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow({
    required KalkanColors palette,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: AppTypography.caption(palette.secondary).copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

