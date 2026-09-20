import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_colors.dart';
import 'core/app_language.dart';
import 'core/app_theme.dart';
import 'data/ble/ute_ble_bridge.dart';
import 'data/storage/user_profile_repository.dart';
import 'domain/avatar/avatar_manager.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Настройка прозрачного системного статус-бара в скандинавском стиле CIRCA
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.stage,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Инициализация Firebase с безопасным fallback
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase.initializeApp() note: $e');
  }

  // Инициализация языка, темы, сохранений и моста
  await AppLocaleNotifier.init();
  await AppThemeNotifier.init();
  await AvatarManager.init();
  final bleBridge = UteBleBridge();
  await bleBridge.init();
  final profile = await UserProfileRepository.loadProfile();

  runApp(BarysBioTrackerApp(
    bleBridge: bleBridge,
    isAuthenticated: profile.isAuthenticated,
  ));
}

class BarysBioTrackerApp extends StatelessWidget {
  final UteBleBridge bleBridge;
  final bool isAuthenticated;

  const BarysBioTrackerApp({
    super.key,
    required this.bleBridge,
    required this.isAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeNotifier.instance,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: AppLocaleNotifier.instance,
          builder: (context, language, _) {
            return MaterialApp(
              title: language == AppLanguage.kyrgyz
                  ? 'КАЛКАН СПОРТ · СААТ-1'
                  : 'КАЛКАН СПОРТ · СААТ-1',
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              theme: AppThemeNotifier.lightTheme,
              darkTheme: AppThemeNotifier.darkTheme,
              home: SplashScreen(
                bleBridge: bleBridge,
                isAuthenticated: isAuthenticated,
              ),
            );
          },
        );
      },
    );
  }
}
