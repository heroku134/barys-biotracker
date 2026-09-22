import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/account_backup_service.dart';
import '../../data/storage/climate_mode_store.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../data/services/app_icon_service.dart';
import 'legal_screen.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  const SettingsScreen({super.key, required this.bleBridge});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _icon = 'obsidian';

  @override
  void initState() {
    super.initState();
    AppIconService.current().then((v) {
      if (mounted) setState(() => _icon = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final dark = AppThemeNotifier.isDark;
    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        title: Text(AppLocaleNotifier.pick('Настройки', 'Жөндөөлөр', 'Settings'), style: AppTypography.screenTitle(palette.fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocaleNotifier.pick('Тема', 'Тема', 'Theme'), style: AppTypography.bodySemibold(palette.fg)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _choice(palette, AppLocaleNotifier.pick('Тёмная', 'Караңгы', 'Dark'), dark, () async {
                  await AppThemeNotifier.setThemeMode(ThemeMode.dark);
                  setState(() {});
                })),
                const SizedBox(width: 8),
                Expanded(child: _choice(palette, AppLocaleNotifier.pick('Светлая', 'Жарык', 'Light'), !dark, () async {
                  await AppThemeNotifier.setThemeMode(ThemeMode.light);
                  setState(() {});
                })),
              ]),
              const SizedBox(height: 16),
              Text(AppLocaleNotifier.pick('Иконка', 'Сүрөтчө', 'App icon'), style: AppTypography.bodySemibold(palette.fg)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _iconTile(palette, 'obsidian', AppLocaleNotifier.pick('Обсидиан', 'Обсидиан', 'Obsidian'), Colors.black)),
                const SizedBox(width: 8),
                Expanded(child: _iconTile(palette, 'porcelain', AppLocaleNotifier.pick('Фарфор', 'Фарфор', 'Porcelain'), Colors.white)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          FutureBuilder<ClimateMode>(
            future: ClimateModeStore.load(),
            builder: (context, snap) {
              final mode = snap.data ?? ClimateMode.normal;
              return GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(AppLocaleNotifier.pick('Регион', 'Аймак', 'Region'), style: AppTypography.bodySemibold(palette.fg)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _choice(palette, AppLocaleNotifier.pick('Обычный', 'Кадимки', 'Normal'), mode == ClimateMode.normal, () async {
                      await ClimateModeStore.save(ClimateMode.normal);
                      setState(() {});
                    })),
                    const SizedBox(width: 6),
                    Expanded(child: _choice(palette, AppLocaleNotifier.pick('Горы', 'Тоо', 'Altitude'), mode == ClimateMode.altitude, () async {
                      await ClimateModeStore.save(ClimateMode.altitude);
                      setState(() {});
                    })),
                    const SizedBox(width: 6),
                    Expanded(child: _choice(palette, AppLocaleNotifier.pick('Жара', 'Ысык', 'Heat'), mode == ClimateMode.heat, () async {
                      await ClimateModeStore.save(ClimateMode.heat);
                      setState(() {});
                    })),
                  ]),
                ]),
              );
            },
          ),
          const SizedBox(height: 12),
          _row(palette, Icons.gavel_outlined, AppLocaleNotifier.pick('Правила', 'Эрежелер', 'Terms'), AppLocaleNotifier.pick('Не диагноз', 'Диагноз эмес', 'Not a diagnosis'), () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen()));
          }),
          const SizedBox(height: 12),
          _row(palette, Icons.cloud_upload_outlined, AppLocaleNotifier.pick('Копия аккаунта', 'Аккаунт көчүрмөсү', 'Account copy'), AppLocaleNotifier.pick('Файл для нового телефона', 'Жаңы телефон үчүн файл', 'File for a new phone'), () async {
            try { await AccountBackupService.share(); } catch (_) {}
          }),
          const SizedBox(height: 12),
          _row(palette, Icons.cloud_download_outlined, AppLocaleNotifier.pick('Восстановить', 'Калыбына келтирүү', 'Restore'), AppLocaleNotifier.pick('Вставить JSON копии', 'JSON коюу', 'Paste backup JSON'), _restore),
        ],
      ),
    );
  }

  Widget _iconTile(KalkanColors palette, String id, String title, Color swatch) {
    final on = _icon == id;
    return GestureDetector(
      onTap: () async {
        setState(() => _icon = id);
        await AppIconService.setIcon(id);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: on ? AppColors.sage.withValues(alpha: 0.14) : palette.raised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? AppColors.sage : palette.hairline),
        ),
        child: Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(8), border: Border.all(color: palette.hairline))),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(color: palette.fg, fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
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

  Widget _row(KalkanColors palette, IconData icon, String title, String sub, VoidCallback onTap) {
    return GlassCard(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: palette.secondary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTypography.bodySemibold(palette.fg)),
          Text(sub, style: AppTypography.caption(palette.secondary)),
        ])),
        Icon(Icons.chevron_right, color: palette.muted),
      ]),
    );
  }

  Future<void> _restore() async {
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
      await UserProfileRepository.loadProfile();
    } catch (_) {}
  }
}
