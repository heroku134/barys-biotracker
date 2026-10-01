import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
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

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('KALKAN FlutterError: ${details.exceptionAsString()}');
    };

    // 1. Мгновенная инициализация локальных настроек UI
    try {
      await AppLocaleNotifier.init();
      await AppThemeNotifier.init();
      AppThemeNotifier.applySystemUi(AppThemeNotifier.current);
      await AvatarManager.init();
    } catch (e) {
      debugPrint('KALKAN UI prefs init note: $e');
    }

    // 2. Инициализация BLE моста (подписка на стрим, не блокирует UI)
    final bleBridge = UteBleBridge();
    try {
      await bleBridge.init();
    } catch (e) {
      debugPrint('KALKAN BleBridge init note: $e');
    }

    // 3. Быстрая загрузка кэша профиля для правильного выбора стартового экрана
    bool isAuthenticated = false;
    try {
      final profile = await UserProfileRepository.loadProfile();
      isAuthenticated = profile.isAuthenticated;
    } catch (e) {
      debugPrint('KALKAN UserProfile load note: $e');
    }

    // 4. НЕМЕДЛЕННЫЙ запуск интерфейса приложения:
    //    Первый кадр отрисовывается мгновенно, предотвращая срабатывание OS Watchdog (0x8badf00d на iOS / ANR на Android)
    runApp(BarysBioTrackerApp(
      bleBridge: bleBridge,
      isAuthenticated: isAuthenticated,
    ));

    // 5. Тяжелые сетевые вызовы, фоновая синхронизация и виджеты запускаются асинхронно
    //    в фоновом микротаске и никогда не могут прервать запуск приложения
    Future.microtask(() async {
      // Инициализация Firebase с платформенными ключами
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        await FcmService.init();
      } catch (e) {
        debugPrint('KALKAN Firebase deferred init note: $e');
      }

      // Безопасная инициализация виджетов рабочего стола
      try {
        await IosWidgetService.init();
      } catch (e) {
        debugPrint('KALKAN IosWidgetService deferred init note: $e');
      }

      // Запуск фонового BLE цикла
      try {
        BackgroundBleSyncService.start(bleBridge);
        await BackgroundBleSyncService.performSync(bleBridge);
        await BackgroundBleSyncService.requestNativeRefresh();
      } catch (e) {
        debugPrint('KALKAN BackgroundBleSyncService deferred start note: $e');
      }

      // Уведомления и снапшоты
      try {
        await DaySnapshotRepository.seedPreviewIfEmpty(bleBridge.currentTelemetry);
        await SystemNotificationService.requestAndSchedule(
          ru: AppLocaleNotifier.current != AppLanguage.english,
        );
      } catch (e) {
        debugPrint('KALKAN notifications/snapshot deferred note: $e');
      }

      // Фоновый синк с облаком
      if (isAuthenticated) {
        try {
          await CloudSyncService.pullDays();
          await CloudSyncService.pullPartnerCycle();
        } catch (e) {
          debugPrint('KALKAN CloudSync deferred note: $e');
        }
      }
    });
  }, (error, stack) {
    debugPrint('KALKAN Global unhandled error: $error\n$stack');
  });
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
