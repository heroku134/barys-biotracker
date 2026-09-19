import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_colors.dart';
import 'data/ble/ute_ble_bridge.dart';
import 'data/storage/user_profile_repository.dart';
import 'domain/avatar/avatar_manager.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/main_shell.dart';

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

  // Инициализация сохранений и моста
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
    return MaterialApp(
      title: 'CIRCA · Барыс-Батыр Биотрекер',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.stage,
        primaryColor: AppColors.amber,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.amber,
          secondary: AppColors.sage,
          surface: AppColors.surface,
        ),
        fontFamily: 'Inter',
      ),
      home: isAuthenticated
          ? MainShell(bleBridge: bleBridge)
          : AuthScreen(bleBridge: bleBridge),
    );
  }
}
