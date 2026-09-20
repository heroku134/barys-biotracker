import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../widgets/circa_film_grain.dart';
import '../widgets/circa_pulsing_logo.dart';
import 'auth_screen.dart';
import 'main_shell.dart';

/// Входной кинематографичный экран CIRCA со священной цитатой и богатым пульсирующим логотипом
class SplashScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  final bool isAuthenticated;
  final Duration displayDuration;

  const SplashScreen({
    super.key,
    required this.bleBridge,
    required this.isAuthenticated,
    this.displayDuration = const Duration(milliseconds: 2600),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _hasNavigated = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _timer = Timer(widget.displayDuration, _proceedToNextScreen);
  }

  void _proceedToNextScreen() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _timer?.cancel();

    CircaHaptics.selectionClick();

    final nextScreen = widget.isAuthenticated
        ? MainShell(bleBridge: widget.bleBridge)
        : AuthScreen(bleBridge: widget.bleBridge);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.stage,
          body: CircaFilmGrainBackground(
            child: GestureDetector(
              onTap: _proceedToNextScreen,
              behavior: HitTestBehavior.opaque,
              child: SafeArea(
                child: Stack(
                  children: [
                    // Верхний переключатель языка [RU | KG]
                    Positioned(
                      top: 12,
                      right: 18,
                      child: GestureDetector(
                        onTap: () {
                          AppLocaleNotifier.toggleLanguage();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                language.flag,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                language.shortTitle,
                                style: const TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.sync_alt, color: AppColors.muted, size: 12),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Центральная композиция
                    Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Маленький бейдж бренда
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: const Text(
                                  'KALKAN SPORT · СААТ-1',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Священная кыргызская пословица
                              Text(
                                AppStrings.tr('entrance_quote', language),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.fg,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Философский перевод / объяснение
                              Text(
                                AppStrings.tr('entrance_quote_sub', language),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Источник мудрости
                              Text(
                                AppStrings.tr('entrance_source', language),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.faint,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 36),

                              // Богатое пульсирующее лого
                              const CircaPulsingLogo(
                                size: 165,
                                primaryColor: AppColors.amber,
                                secondaryColor: AppColors.sage,
                              ),
                              const SizedBox(height: 32),

                              // Подсказка перехода
                              Text(
                                AppStrings.tr('entrance_tap_to_enter', language),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.8,
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
            ),
          ),
        );
      },
    );
  }
}
