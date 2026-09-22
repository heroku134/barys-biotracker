import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/demo_mode_store.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/glass_card.dart';
import 'device_pair_screen.dart';
import 'main_shell.dart';

class AccountSetupScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  const AccountSetupScreen({super.key, required this.bleBridge});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _height = TextEditingController(text: '170');
  final _weight = TextEditingController(text: '70');
  Gender _gender = Gender.male;
  int _step = 0;

  bool get _ru => AppLocaleNotifier.current != AppLanguage.kyrgyz;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _saveBody() async {
    final p = await UserProfileRepository.loadProfile();
    final h = double.tryParse(_height.text.replaceAll(',', '.')) ?? 170;
    final w = double.tryParse(_weight.text.replaceAll(',', '.')) ?? 70;
    await UserProfileRepository.saveProfile(p.copyWith(
      heightCm: h,
      weightKg: w,
      gender: _gender,
      isAuthenticated: true,
    ));
    await DemoModeStore.setEnabled(false);
    setState(() => _step = 1);
  }

  Future<void> _finish({required bool pair}) async {
    if (pair) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DevicePairScreen(bleBridge: widget.bleBridge),
      ));
    }
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
        title: Text(_step == 0
            ? AppLocaleNotifier.pick('Ваши данные', 'Сиздин маалымат', 'Your details')
            : AppLocaleNotifier.pick('Часы', 'Саат', 'Watch'), style: AppTypography.screenTitle(palette.fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_step == 0) ...[
            Text(AppLocaleNotifier.pick('Рост, вес и пол нужны для нагрузки. Без демо-цифр.', 'Бой, салмак жана жыныс жүктөм үчүн.', 'Height, weight and sex set the strain math. No demo numbers.'), style: AppTypography.caption(palette.secondary).copyWith(height: 1.4)),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(children: [
                TextField(controller: _height, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppLocaleNotifier.pick('Рост, см', 'Бой, см', 'Height, cm'))),
                TextField(controller: _weight, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppLocaleNotifier.pick('Вес, кг', 'Салмак, кг', 'Weight, kg'))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _g(palette, Gender.male, AppLocaleNotifier.pick('Муж', 'Эркек', 'Male'))),
                  const SizedBox(width: 8),
                  Expanded(child: _g(palette, Gender.female, AppLocaleNotifier.pick('Жен', 'Аял', 'Female'))),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveBody,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size.fromHeight(48)),
              child: Text(AppLocaleNotifier.pick('Дальше', 'Андан ары', 'Next')),
            ),
          ] else ...[
            Text(AppLocaleNotifier.pick('Без часов утро будет пустым. Подключите СААТ-1 или откройте приложение без браслета.', 'Саат жок болсо таң бош.', 'Without the watch the morning stays empty.'), style: AppTypography.caption(palette.secondary).copyWith(height: 1.4)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _finish(pair: true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size.fromHeight(48)),
              child: Text(AppLocaleNotifier.pick('Подключить часы', 'Саатты туташтыруу', 'Connect watch')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _finish(pair: false),
              child: Text(AppLocaleNotifier.pick('Позже', 'Кийинчерээк', 'Later')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _g(KalkanColors palette, Gender g, String label) {
    final on = _gender == g;
    return GestureDetector(
      onTap: () => setState(() => _gender = g),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: on ? AppColors.sage.withValues(alpha: 0.14) : palette.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppColors.sage : palette.hairline),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: palette.fg, fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}
