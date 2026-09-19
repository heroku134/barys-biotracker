import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/circa_morning_briefing_dialog.dart';
import '../widgets/circa_text_field.dart';
import '../widgets/glass_card.dart';
import 'auth_screen.dart';
import 'device_settings_screen.dart';

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
  bool _isCalibrationDemo = false;

  @override
  void initState() {
    super.initState();
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

    return Scaffold(
      backgroundColor: AppColors.stage,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ЛИЧНЫЙ ПРОФИЛЬ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
              ),
            ),
            Text(
              'Биометрия и Настройки',
              style: TextStyle(
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
            tooltip: 'Выйти из аккаунта',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Аватар пользователя с инициалами
            Center(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.amber, width: 2.0),
                    ),
                    child: Center(
                      child: Text(
                        _profile.name.isNotEmpty ? _profile.name[0].toUpperCase() : 'Б',
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _profile.name,
                    style: const TextStyle(
                      color: AppColors.fg,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _profile.email,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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

            const Text(
              'ФИЗИОЛОГИЧЕСКИЕ ПАРАМЕТРЫ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),

            // Поля биометрии
            CircaTextField(
              label: 'Имя профиля',
              controller: _nameController,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: CircaTextField(
                    label: 'Рост (см)',
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CircaTextField(
                    label: 'Вес (кг)',
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CircaTextField(
                    label: 'Год рожд.',
                    controller: _birthYearController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ИМТ (BMI) плашка
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Индекс массы тела (BMI)',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  Text(
                    '${_profile.bmi.toStringAsFixed(1)} (Норма)',
                    style: const TextStyle(color: AppColors.sage, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'СУТОЧНЫЕ ЦЕЛИ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: CircaTextField(
                    label: 'Цель шагов',
                    controller: _stepGoalController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CircaTextField(
                    label: 'Цель ккал',
                    controller: _calorieGoalController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Переключатель 24-часового формата времени
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '24-часовой формат времени',
                        style: TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Синхронизируется с прошивкой браслета',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                  Switch(
                    value: _is24h,
                    activeThumbColor: AppColors.amber,
                    onChanged: (val) => setState(() => _is24h = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Кнопка сохранения
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.stage,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.stage),
                      )
                    : const Text(
                        'СОХРАНИТЬ ПРОФИЛЬ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Версия прошивки с 7-кратным тапом для инженерного меню
            Center(
              child: GestureDetector(
                onTap: _handleVersionTap,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  child: Text(
                    'CIRCA One v1.4.2 · Сборка 2026.09',
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
                  'ИНЖЕНЕРНОЕ МЕНЮ (CIRCA DEV)',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 14),

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
}
