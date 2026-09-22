import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../core/avatar_image_provider.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/partner_cycle_repository.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/models/partner_cycle_data.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/circa_avatar_picker_dialog.dart';
import '../widgets/circa_morning_briefing_dialog.dart';
import '../widgets/circa_partner_cycle_sheet.dart';
import '../widgets/glass_card.dart';
import 'auth_screen.dart';
import 'device_settings_screen.dart';
import 'pregnancy_screen.dart';
import 'legal_screen.dart';
import '../../data/storage/account_backup_service.dart';
import '../../data/storage/climate_mode_store.dart';
import 'private_league_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  const ProfileScreen({super.key, required this.bleBridge});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = const UserProfile();
  PartnerCycleData? _partnerCycle;
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
    _loadProfile();
    _loadPartnerCycle();
    UserProfileRepository.profileNotifier.addListener(_onProfileChanged);
    PartnerCycleRepository.notifier.addListener(_onPartnerCycleChanged);
  }

  void _onProfileChanged() {
    if (mounted) setState(() => _profile = UserProfileRepository.profileNotifier.value);
  }

  void _onPartnerCycleChanged() {
    if (mounted) setState(() => _partnerCycle = PartnerCycleRepository.notifier.value);
  }

  Future<void> _loadPartnerCycle() async {
    final data = await PartnerCycleRepository.loadPartnerCycle();
    if (mounted) setState(() => _partnerCycle = data);
  }

  Future<void> _loadProfile() async {
    final p = await UserProfileRepository.loadProfile();
    if (mounted) setState(() => _profile = p);
  }

  @override
  void dispose() {
    UserProfileRepository.profileNotifier.removeListener(_onProfileChanged);
    PartnerCycleRepository.notifier.removeListener(_onPartnerCycleChanged);
    super.dispose();
  }

  bool get _ru => AppLocaleNotifier.current != AppLanguage.kyrgyz;

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final telemetry = widget.bleBridge.currentTelemetry;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: palette.bg,
          appBar: AppBar(
            backgroundColor: palette.bg,
            elevation: 0,
            title: Text(AppStrings.tr('profile_title', language), style: AppTypography.screenTitle(palette.fg)),
            actions: [
              IconButton(
                icon: Icon(Icons.logout, color: AppColors.rose, size: 20),
                onPressed: _logout,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (_isCrisisMode) _crisisBanner(palette),
              _identityCard(palette, telemetry, language),
              if (_profile.gender == Gender.female) ...[
                const SizedBox(height: 12),
                _pregnancyCard(palette),
              ],
              const SizedBox(height: 12),
              _deviceCard(palette, telemetry, language),
              const SizedBox(height: 12),
              _metricsCard(palette, language),
              const SizedBox(height: 12),
              _linkTile(
                palette,
                icon: Icons.people_outline,
                title: _ru ? 'Круг друзей' : 'Достор',
                subtitle: _ru ? 'Приватная лига' : 'Жеке лига',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PrivateLeagueScreen(bleBridge: widget.bleBridge)),
                ),
              ),
              const SizedBox(height: 12),
              _partnerCard(palette, language),
              const SizedBox(height: 12),
              _languageCard(palette, language),
              const SizedBox(height: 12),
              _themeCard(palette, language),
              const SizedBox(height: 12),
              _climateCard(palette),
              const SizedBox(height: 12),
              _linkTile(
                palette,
                icon: Icons.gavel_outlined,
                title: AppLocaleNotifier.pick('Правила', 'Эрежелер', 'Terms'),
                subtitle: AppLocaleNotifier.pick('Не диагноз', 'Диагноз эмес', 'Not a diagnosis'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen())),
              ),
              const SizedBox(height: 12),
              _linkTile(
                palette,
                icon: Icons.cloud_upload_outlined,
                title: AppLocaleNotifier.pick('Копия аккаунта', 'Аккаунт көчүрмөсү', 'Account copy'),
                subtitle: AppLocaleNotifier.pick('Файл для нового телефона', 'Жаңы телефон үчүн файл', 'File for a new phone'),
                onTap: () async {
                  try {
                    await AccountBackupService.share();
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 12),
              _linkTile(
                palette,
                icon: Icons.cloud_download_outlined,
                title: AppLocaleNotifier.pick('Восстановить', 'Калыбына келтирүү', 'Restore'),
                subtitle: AppLocaleNotifier.pick('Вставить JSON копии', 'JSON коюу', 'Paste backup JSON'),
                onTap: _restoreBackup,
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _handleVersionTap,
                  child: Text(
                    'КАЛКАН · СААТ-1  v1.4.2',
                    style: AppTypography.caption(palette.muted),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _ru
                    ? 'Часы не ставят диагноз. Цифры показывают тренд восстановления и нагрузки.'
                    : 'Саат диагноз койбойт. Сандар калыбына келүү жана жүктөмдүн багытын көрсөтөт.',
                style: AppTypography.caption(palette.secondary).copyWith(height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _crisisBanner(KalkanColors palette) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _ru ? 'Демо: кризисный режим включён' : 'Демо: кризис режими күйүк',
              style: TextStyle(color: palette.fg, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isCrisisMode = false;
                widget.bleBridge.setDemoCrisis(false);
              });
            },
            child: Text(_ru ? 'Выкл' : 'Өчүр', style: TextStyle(color: AppColors.rose)),
          ),
        ],
      ),
    );
  }

  Widget _identityCard(KalkanColors palette, BleTelemetry telemetry, AppLanguage language) {
    final name = _profile.name.isNotEmpty ? _profile.name : (_ru ? 'Гость' : 'Конок');
    return GlassCard(
      child: Row(
        children: [
          GestureDetector(
            onTap: () => CircaAvatarPickerDialog.show(context, _profile),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.hairline),
              ),
              child: ClipOval(child: AvatarImageProvider.buildAvatarWidget(path: _profile.avatarPath)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.bodySemibold(palette.fg)),
                const SizedBox(height: 2),
                Text(
                  '${_profile.age} · ${_profile.gender == Gender.female ? (_ru ? 'Женский' : 'Аял') : (_ru ? 'Мужской' : 'Эркек')}',
                  style: AppTypography.caption(palette.secondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showEditNameDialog,
            child: Text(_ru ? 'Имя' : 'Аты', style: TextStyle(color: AppColors.sage)),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(KalkanColors palette, BleTelemetry telemetry, AppLanguage language) {
    return GlassCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DeviceSettingsScreen(bleBridge: widget.bleBridge)),
        );
      },
      child: Row(
        children: [
          Icon(Icons.watch_outlined, color: telemetry.isConnected ? AppColors.sage : palette.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(telemetry.deviceName.isNotEmpty ? telemetry.deviceName : 'СААТ-1', style: AppTypography.bodySemibold(palette.fg)),
                Text(
                  telemetry.isConnected
                      ? (_ru ? 'Подключены · ${telemetry.batteryLevel}%' : 'Туташкан · ${telemetry.batteryLevel}%')
                      : (_ru ? 'Нет связи' : 'Байланыш жок'),
                  style: AppTypography.caption(telemetry.isConnected ? AppColors.sage : palette.secondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: palette.muted),
        ],
      ),
    );
  }

  Widget _metricsCard(KalkanColors palette, AppLanguage language) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_ru ? 'Данные и цели' : 'Маалымат жана максат', style: AppTypography.bodySemibold(palette.fg))),
              TextButton(onPressed: _showBiodataModal, child: Text(_ru ? 'Изменить' : 'Өзгөртүү', style: TextStyle(color: AppColors.sage))),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            _metric(palette, _ru ? 'Рост' : 'Бою', '${_profile.heightCm.toInt()} см'),
            const SizedBox(width: 8),
            _metric(palette, _ru ? 'Вес' : 'Салмагы', '${_profile.weightKg.toStringAsFixed(1)} кг'),
            const SizedBox(width: 8),
            _metric(palette, 'BMI', _profile.bmi.toStringAsFixed(1)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _metric(palette, _ru ? 'Шаги' : 'Кадам', '${_profile.stepGoal}'),
            const SizedBox(width: 8),
            _metric(palette, _ru ? 'Ккал' : 'Ккал', '${_profile.calorieGoal}'),
            const SizedBox(width: 8),
            _metric(palette, _ru ? 'Сон' : 'Уйку', '${_profile.sleepGoalHours.toStringAsFixed(0)} ч'),
          ]),
        ],
      ),
    );
  }

  Widget _metric(KalkanColors palette, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.caption(palette.secondary)),
            const SizedBox(height: 2),
            Text(value, style: AppTypography.metricValue(palette.fg)),
          ],
        ),
      ),
    );
  }

  Widget _linkTile(KalkanColors palette, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: palette.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTypography.bodySemibold(palette.fg)),
              Text(subtitle, style: AppTypography.caption(palette.secondary)),
            ]),
          ),
          Icon(Icons.chevron_right, color: palette.muted),
        ],
      ),
    );
  }

  Widget _partnerCard(KalkanColors palette, AppLanguage language) {
    final linked = _partnerCycle?.isLinked == true;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_ru ? 'Цикл партнёра' : 'Өнөктөштүн цикли', style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 6),
          Text(
            linked
                ? '${_partnerCycle!.partnerName} · ${_ru ? 'день' : 'күн'} ${_partnerCycle!.currentCycleDay} · ${_partnerCycle!.phaseTitle}'
                : (_ru ? 'Привяжите код, чтобы видеть фазу на главном экране.' : 'Кодду байлаңыз — фаза башкы экранда көрүнөт.'),
            style: AppTypography.caption(palette.secondary).copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          if (linked)
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => CircaPartnerCycleSheet.show(context, _partnerCycle!),
                  child: Text(_ru ? 'Подробно' : 'Толук'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  await PartnerCycleRepository.unlinkPartner();
                  await _loadPartnerCycle();
                },
                child: Text(_ru ? 'Отключить' : 'Өчүрүү', style: TextStyle(color: AppColors.rose)),
              ),
            ])
          else
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _openPartnerLinkDialog(),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
                  child: Text(_ru ? 'Привязать' : 'Байлоо'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  await PartnerCycleRepository.linkPartner(
                    partnerCode: 'KLK-CYC-9281',
                    partnerName: 'Айпери',
                    cycleDay: 14,
                    cycleLength: 28,
                  );
                  await _loadPartnerCycle();
                },
                child: Text(_ru ? 'Демо' : 'Демо'),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _languageCard(KalkanColors palette, AppLanguage current) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_ru ? 'Язык' : 'Тил', style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _choice(palette, 'Русский', current == AppLanguage.russian, () => AppLocaleNotifier.setLanguage(AppLanguage.russian))),
            const SizedBox(width: 6),
            Expanded(child: _choice(palette, 'Кыргызча', current == AppLanguage.kyrgyz, () => AppLocaleNotifier.setLanguage(AppLanguage.kyrgyz))),
            const SizedBox(width: 6),
            Expanded(child: _choice(palette, 'EN', current == AppLanguage.english, () => AppLocaleNotifier.setLanguage(AppLanguage.english))),
          ]),
        ],
      ),
    );
  }

  Widget _themeCard(KalkanColors palette, AppLanguage language) {
    final dark = AppThemeNotifier.isDark;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_ru ? 'Тема' : 'Тема', style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _choice(palette, _ru ? 'Тёмная' : 'Караңгы', dark, () => AppThemeNotifier.setThemeMode(ThemeMode.dark))),
            const SizedBox(width: 8),
            Expanded(child: _choice(palette, _ru ? 'Светлая' : 'Жарык', !dark, () => AppThemeNotifier.setThemeMode(ThemeMode.light))),
          ]),
        ],
      ),
    );
  }


  Widget _pregnancyCard(KalkanColors palette) {
    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocaleNotifier.pick('Беременность', 'Кош бойлуулук', 'Pregnancy'), style: AppTypography.bodySemibold(palette.fg)),
                const SizedBox(height: 4),
                Text(
                  _profile.isPregnant
                      ? AppLocaleNotifier.pick('Режим включён', 'Режим күйүк', 'Mode on')
                      : AppLocaleNotifier.pick('Дневник срока, не диагноз', 'Мөөнөт күндөлүгү', 'A term diary, not a diagnosis'),
                  style: AppTypography.caption(palette.secondary),
                ),
              ],
            ),
          ),
          Switch(
            value: _profile.isPregnant,
            activeThumbColor: AppColors.sage,
            onChanged: (v) async {
              final next = _profile.copyWith(isPregnant: v);
              await UserProfileRepository.saveProfile(next);
              if (mounted) setState(() => _profile = next);
            },
          ),
        ],
      ),
    );
  }

  Widget _climateCard(KalkanColors palette) {
    return FutureBuilder<ClimateMode>(
      future: ClimateModeStore.load(),
      builder: (context, snap) {
        final mode = snap.data ?? ClimateMode.normal;
        return GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLocaleNotifier.pick('Регион', 'Аймак', 'Region'), style: AppTypography.bodySemibold(palette.fg)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _choice(palette, AppLocaleNotifier.pick('Обычный', 'Кадимки', 'Normal'), mode == ClimateMode.normal, () async { await ClimateModeStore.save(ClimateMode.normal); setState(() {}); })),
              const SizedBox(width: 6),
              Expanded(child: _choice(palette, AppLocaleNotifier.pick('Горы', 'Тоо', 'Altitude'), mode == ClimateMode.altitude, () async { await ClimateModeStore.save(ClimateMode.altitude); setState(() {}); })),
              const SizedBox(width: 6),
              Expanded(child: _choice(palette, AppLocaleNotifier.pick('Жара', 'Ысык', 'Heat'), mode == ClimateMode.heat, () async { await ClimateModeStore.save(ClimateMode.heat); setState(() {}); })),
            ]),
          ]),
        );
      },
    );
  }

  Future<void> _restoreBackup() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocaleNotifier.pick('JSON копии', 'JSON', 'Backup JSON'), style: TextStyle(color: AppColors.fg)),
        content: TextField(controller: controller, maxLines: 6),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocaleNotifier.pick('Отмена', 'Жок', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(AppLocaleNotifier.pick('Ок', 'Макул', 'OK'))),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    try {
      await AccountBackupService.restoreFromJsonText(raw.trim());
      final p = await UserProfileRepository.loadProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  Widget _choice(KalkanColors palette, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.sage.withValues(alpha: 0.14) : palette.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.sage : palette.hairline),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: palette.fg, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  void _logout() {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_ru ? 'Выйти?' : 'Чыгуу?', style: TextStyle(color: AppColors.fg)),
        content: Text(_ru ? 'Синхронизация остановится до следующего входа.' : 'Кийинки кирүүгө чейин синхрон токтотулат.', style: TextStyle(color: AppColors.secondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(_ru ? 'Отмена' : 'Жок')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
              } catch (_) {}
              await UserProfileRepository.setAuthenticated(false);
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => AuthScreen(bleBridge: widget.bleBridge)),
                (_) => false,
              );
            },
            child: Text(_ru ? 'Выйти' : 'Чыгуу', style: TextStyle(color: AppColors.rose)),
          ),
        ],
      ),
    );
  }

  void _openPartnerLinkDialog() {
    final codeCtrl = TextEditingController(text: 'KLK-CYC-9281');
    final nameCtrl = TextEditingController(text: 'Айпери');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_ru ? 'Код партнёра' : 'Өнөктөштүн коду', style: TextStyle(color: AppColors.fg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: InputDecoration(labelText: _ru ? 'Код' : 'Код')),
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: _ru ? 'Имя' : 'Аты')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_ru ? 'Отмена' : 'Жок')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await PartnerCycleRepository.linkPartner(
                partnerCode: codeCtrl.text.trim().isEmpty ? 'KLK-CYC-9281' : codeCtrl.text.trim(),
                partnerName: nameCtrl.text.trim().isEmpty ? 'Айпери' : nameCtrl.text.trim(),
                cycleDay: 14,
                cycleLength: 28,
              );
              await _loadPartnerCycle();
            },
            child: Text(_ru ? 'Привязать' : 'Байлоо'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _profile.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_ru ? 'Имя' : 'Аты', style: TextStyle(color: AppColors.fg)),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_ru ? 'Отмена' : 'Жок')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final updated = _profile.copyWith(name: name);
                setState(() => _profile = updated);
                await UserProfileRepository.saveProfile(updated);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(_ru ? 'Сохранить' : 'Сактоо'),
          ),
        ],
      ),
    );
  }

  void _showBiodataModal() {
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_ru ? 'Данные и цели' : 'Маалымат', style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _choice(KalkanColors.of(context), _ru ? 'Мужской' : 'Эркек', tempGender == Gender.male, () => setModalState(() => tempGender = Gender.male))),
                    const SizedBox(width: 8),
                    Expanded(child: _choice(KalkanColors.of(context), _ru ? 'Женский' : 'Аял', tempGender == Gender.female, () => setModalState(() => tempGender = Gender.female))),
                  ]),
                  const SizedBox(height: 12),
                  _field(_ru ? 'Рост, см' : 'Бою, см', hCtrl),
                  _field(_ru ? 'Вес, кг' : 'Салмак, кг', wCtrl),
                  _field(_ru ? 'Год рождения' : 'Туулган жыл', bCtrl),
                  _field(_ru ? 'Цель шагов' : 'Кадам максаты', sCtrl),
                  _field(_ru ? 'Цель ккал' : 'Ккал максаты', cCtrl),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final updated = _profile.copyWith(
                          heightCm: double.tryParse(hCtrl.text) ?? _profile.heightCm,
                          weightKg: double.tryParse(wCtrl.text) ?? _profile.weightKg,
                          birthYear: int.tryParse(bCtrl.text) ?? _profile.birthYear,
                          stepGoal: int.tryParse(sCtrl.text) ?? _profile.stepGoal,
                          calorieGoal: int.tryParse(cCtrl.text) ?? _profile.calorieGoal,
                          gender: tempGender,
                        );
                        await UserProfileRepository.saveProfile(updated);
                        setState(() => _profile = updated);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
                      child: Text(_ru ? 'Сохранить' : 'Сактоо'),
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

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
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
      backgroundColor: AppColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_ru ? 'Инженерное меню' : 'Инженер меню', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600)),
                SwitchListTile(
                  title: Text(_ru ? 'Кризисный режим' : 'Кризис режими', style: TextStyle(color: AppColors.fg, fontSize: 14)),
                  value: _isCrisisMode,
                  onChanged: (val) {
                    setSheetState(() => _isCrisisMode = val);
                    setState(() {
                      _isCrisisMode = val;
                      widget.bleBridge.setDemoCrisis(val);
                    });
                  },
                ),
                SwitchListTile(
                  title: Text(_ru ? 'Демо усталости' : 'Чарчоо демо', style: TextStyle(color: AppColors.fg, fontSize: 14)),
                  value: _isTiredDemo,
                  onChanged: (val) {
                    setSheetState(() => _isTiredDemo = val);
                    setState(() => widget.bleBridge.setDemoTired(val));
                  },
                ),
                SwitchListTile(
                  title: Text(_ru ? 'Демо калибровки' : 'Калибрлөө демо', style: TextStyle(color: AppColors.fg, fontSize: 14)),
                  value: _isCalibrationDemo,
                  onChanged: (val) => setSheetState(() => _isCalibrationDemo = val),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    CircaMorningBriefingDialog.show(context, widget.bleBridge.currentTelemetry, const PersonalBaseline());
                  },
                  child: Text(_ru ? 'Тест утреннего отчёта' : 'Таңкы отчет'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
