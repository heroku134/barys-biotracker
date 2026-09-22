import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import 'auth_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../data/storage/onboarding_repository.dart';

class SplashScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  final bool isAuthenticated;
  final Duration displayDuration;

  const SplashScreen({
    super.key,
    required this.bleBridge,
    required this.isAuthenticated,
    this.displayDuration = const Duration(milliseconds: 2200),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _hasNavigated = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _timer = Timer(widget.displayDuration, _proceedToNextScreen);
  }

  Future<void> _proceedToNextScreen() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _timer?.cancel();
    CircaHaptics.selectionClick();

    final onboarded = await OnboardingRepository.isDone();
    final Widget nextScreen;
    if (!onboarded) {
      nextScreen = OnboardingScreen(
        bleBridge: widget.bleBridge,
        isAuthenticated: widget.isAuthenticated,
      );
    } else {
      nextScreen = widget.isAuthenticated
          ? MainShell(bleBridge: widget.bleBridge)
          : AuthScreen(bleBridge: widget.bleBridge);
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
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
    final palette = KalkanColors.of(context);
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: palette.bg,
          body: GestureDetector(
            onTap: _proceedToNextScreen,
            behavior: HitTestBehavior.opaque,
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: TextButton(
                          onPressed: () => AppLocaleNotifier.toggleLanguage(),
                          child: Text(
                            language.shortTitle,
                            style: AppTypography.monoLabel(palette.secondary),
                          ),
                        ),
                      ),
                      Spacer(),
                      ClipOval(
                        child: Image.asset(
                          AvatarVisualState.genderedPath('assets/images/mascot_normal.jpg'),
                          width: 128,
                          height: 128,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'КАЛКАН',
                        style: AppTypography.monoLabel(palette.secondary).copyWith(
                          letterSpacing: 4,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppStrings.tr('entrance_quote', language),
                        textAlign: TextAlign.center,
                        style: AppTypography.screenTitle(palette.fg).copyWith(
                          fontSize: 22,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.tr('entrance_quote_sub', language),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMuted(palette.secondary),
                      ),
                      Spacer(),
                      Text(
                        AppStrings.tr('entrance_source', language),
                        textAlign: TextAlign.center,
                        style: AppTypography.caption(palette.muted),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.tr('entrance_tap_to_enter', language),
                        style: AppTypography.monoLabel(palette.secondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
