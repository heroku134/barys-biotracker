import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/onboarding_repository.dart';
import 'auth_screen.dart';
import 'device_pair_screen.dart';
import 'main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  final bool isAuthenticated;
  const OnboardingScreen({super.key, required this.bleBridge, required this.isAuthenticated});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  Future<void> _finish({required bool calibrate}) async {
    await OnboardingRepository.markDone(startCalibration: calibrate);
    if (!mounted) return;
    final next = widget.isAuthenticated
        ? MainShell(bleBridge: widget.bleBridge)
        : AuthScreen(bleBridge: widget.bleBridge);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        final palette = KalkanColors.of(context);
        final titles = [
          AppLocaleNotifier.pick('Наденьте СААТ-1', 'СААТ-1 кийиңиз', 'Put on SAAT-1'),
          AppLocaleNotifier.pick('Три числа каждый день', 'Күнүнө үч сан', 'Three numbers a day'),
          AppLocaleNotifier.pick('14 дней калибровки', '14 күн калибрлөө', '14 days of calibration'),
          AppLocaleNotifier.pick('Это не врач', 'Бул дарыгер эмес', 'Not a clinician'),
        ];
        const photos = [
          'assets/images/onboard_watch.jpg',
          'assets/images/onboard_rings.jpg',
          'assets/images/onboard_morning.jpg',
          'assets/images/onboard_legal.jpg',
        ];
        final bodies = [
          AppLocaleNotifier.pick(
            'Часы без экрана. Телефон показывает сон, восстановление и нагрузку.',
            'Саатта экран жок. Телефон уйку, калыбына келүү жана жүктөмдү көрсөтөт.',
            'The watch has no screen. The phone shows sleep, recovery and strain.',
          ),
          AppLocaleNotifier.pick(
            'Утром смотрите восстановление. По нему считается цель нагрузки на день.',
            'Таңда калыбына келүүнү караңыз. Ошого жараша күндүк жүктөм коюлат.',
            'Check recovery in the morning. That sets the strain budget for the day.',
          ),
          AppLocaleNotifier.pick(
            'Первые две недели приложение учит ваш обычный пульс и HRV. Потом цифры становятся личными.',
            'Алгачкы эки жума колдонмо сиздин кадимки пульсуңузду үйрөнөт. Андан кийин сандар жеке болот.',
            'The first two weeks learn your usual HRV and resting heart rate. Then the numbers are yours.',
          ),
          AppLocaleNotifier.pick(
            'Цифры — ориентир нагрузки, не диагноз. Цикл и беременность — дневник. Решения о здоровье принимаете вы и врач.',
            'Сандар жүктөм үчүн багыт, диагноз эмес. Цикл менен кош бойлуулук — күндөлүк.',
            'Numbers are a training guide, not a diagnosis. Cycle and pregnancy tools are a diary. You and your clinician decide.',
          ),
        ];

        return Scaffold(
          backgroundColor: palette.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('КАЛКАН', style: AppTypography.caption(palette.secondary)),
                      TextButton(
                        onPressed: () => AppLocaleNotifier.toggleLanguage(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '${language.flag} ${language.shortTitle}',
                          style: TextStyle(color: palette.secondary, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(titles[_step], style: AppTypography.screenTitle(palette.fg).copyWith(fontSize: 26, height: 1.2)),
                  const SizedBox(height: 12),
                  Text(bodies[_step], style: AppTypography.body(palette.secondary).copyWith(height: 1.45)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(photos[_step], fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
              const SizedBox(height: 16),
              Row(
                children: List.generate(4, (i) {
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: i == _step ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _step ? AppColors.sage : palette.hairline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              if (_step == 0)
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DevicePairScreen(bleBridge: widget.bleBridge),
                    ));
                  },
                  child: Text(AppLocaleNotifier.pick('Найти часы', 'Саатты табуу', 'Find watch')),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_step < 3) {
                      setState(() => _step++);
                    } else {
                      _finish(calibrate: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_step < 3 ? (AppLocaleNotifier.pick('Дальше', 'Кийинки', 'Next')) : (AppLocaleNotifier.pick('Начать 14 дней', '14 күндү баштоо', 'Start 14 days'))),
                ),
              ),
              TextButton(
                onPressed: () => _finish(calibrate: false),
                child: Text(AppLocaleNotifier.pick('Пропустить', 'Өткөрүп жиберүү', 'Skip'), style: TextStyle(color: palette.secondary)),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
}
}
