import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_colors.dart';
import 'core/app_language.dart';
import 'core/app_theme.dart';
import 'data/ble/ute_ble_bridge.dart';
import 'data/services/ios_widget_service.dart';
import 'data/services/background_ble_sync_service.dart';
import 'data/storage/user_profile_repository.dart';
import 'data/services/cloud_sync_service.dart';
import 'data/services/fcm_service.dart';
import 'data/storage/day_snapshot_repository.dart';
import 'data/services/system_notification_service.dart';
import 'domain/avatar/avatar_manager.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase с безопасным fallback
  try {
    await Firebase.initializeApp();
    await FcmService.init();
  } catch (e) {
    debugPrint('Firebase.initializeApp() note: $e');
  }

  // Инициализация виджетов iOS / Android
  await IosWidgetService.init();

  // Инициализация языка, темы, сохранений и моста
  await AppLocaleNotifier.init();
  await AppThemeNotifier.init();
  AppThemeNotifier.applySystemUi(AppThemeNotifier.current);
  await AvatarManager.init();
  final bleBridge = UteBleBridge();
  await bleBridge.init();
  BackgroundBleSyncService.start(bleBridge);
  await BackgroundBleSyncService.performSync(bleBridge);
  await BackgroundBleSyncService.requestNativeRefresh();
  await DaySnapshotRepository.seedPreviewIfEmpty(bleBridge.currentTelemetry);
  await SystemNotificationService.requestAndSchedule(
    ru: AppLocaleNotifier.current != AppLanguage.english,
  );
  final profile = await UserProfileRepository.loadProfile();
  if (profile.isAuthenticated) {
    await CloudSyncService.pullDays();
    await CloudSyncService.pullPartnerCycle();
  }

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
              title: AppLocaleNotifier.pick(
                'КАЛКАН СПОРТ · СААТ-1',
                'КАЛКАН СПОРТ · СААТ-1',
                'KALKAN SPORT · SAAT-1',
              ),
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              theme: AppThemeNotifier.lightTheme,
              darkTheme: AppThemeNotifier.darkTheme,
              builder: (context, child) {
                AppColors.light = themeMode == ThemeMode.light;
                return child ?? const SizedBox.shrink();
              },
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
