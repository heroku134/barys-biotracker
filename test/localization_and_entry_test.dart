import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/core/app_language.dart';
import 'package:barys_biotracker/core/app_strings.dart';
import 'package:barys_biotracker/presentation/widgets/circa_pulsing_logo.dart';
import 'package:barys_biotracker/presentation/screens/splash_screen.dart';
import 'package:barys_biotracker/presentation/screens/auth_screen.dart';
import 'package:barys_biotracker/presentation/screens/profile_screen.dart';
import 'package:barys_biotracker/data/ble/ute_ble_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocaleNotifier.init();
    await AppLocaleNotifier.setLanguage(AppLanguage.russian);
  });

  group('AppLanguage & AppLocaleNotifier Unit Tests', () {
    test('Default language is Russian', () {
      expect(AppLocaleNotifier.current, AppLanguage.russian);
      expect(AppLocaleNotifier.current.code, 'ru');
      expect(AppLocaleNotifier.current.shortTitle, 'RU');
    });

    test('Can switch to Kyrgyz and persists in SharedPreferences', () async {
      await AppLocaleNotifier.setLanguage(AppLanguage.kyrgyz);
      expect(AppLocaleNotifier.current, AppLanguage.kyrgyz);
      expect(AppLocaleNotifier.current.code, 'ky');
      expect(AppLocaleNotifier.current.shortTitle, 'KG');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('circa_app_language_code'), 'ky');

      // Toggle back to Russian
      await AppLocaleNotifier.toggleLanguage();
      expect(AppLocaleNotifier.current, AppLanguage.russian);
      expect(prefs.getString('circa_app_language_code'), 'ru');
    });
  });

  group('AppStrings Dictionary Tests', () {
    test('Entrance quote exists in Russian and Kyrgyz', () {
      final quoteRu = AppStrings.tr('entrance_quote', AppLanguage.russian);
      final quoteKy = AppStrings.tr('entrance_quote', AppLanguage.kyrgyz);

      expect(quoteRu, '«Адамга өз чегин билбей өлгөн уят»');
      expect(quoteKy, '«Адамга өз чегин билбей өлгөн уят»');

      final subRu = AppStrings.tr('entrance_quote_sub', AppLanguage.russian);
      final subKy = AppStrings.tr('entrance_quote_sub', AppLanguage.kyrgyz);

      expect(subRu, contains('Стыдно человеку умереть'));
      expect(subKy, contains('Адам өз чегин'));
    });

    test('Navigation labels are translated to Kyrgyz', () {
      expect(AppStrings.tr('nav_today', AppLanguage.russian), 'Сегодня');
      expect(AppStrings.tr('nav_today', AppLanguage.kyrgyz), 'Бүгүн');

      expect(AppStrings.tr('nav_analysis', AppLanguage.russian), 'Анализ');
      expect(AppStrings.tr('nav_analysis', AppLanguage.kyrgyz), 'Талдоо');

      expect(AppStrings.tr('nav_sport', AppLanguage.russian), 'Спорт');
      expect(AppStrings.tr('nav_sport', AppLanguage.kyrgyz), 'Спорт');

      expect(AppStrings.tr('nav_barys', AppLanguage.russian), '🐯 БАРЫС');
      expect(AppStrings.tr('nav_barys', AppLanguage.kyrgyz), '🐯 БАРЫС');

      expect(AppStrings.tr('nav_profile', AppLanguage.russian), 'Профиль');
      expect(AppStrings.tr('nav_profile', AppLanguage.kyrgyz), 'Профиль');
    });

    test('trParams interpolates arguments correctly in both languages', () {
      final ruParam = AppStrings.trParams(
        'league_slots_format',
        {'current': 4, 'max': 5},
        AppLanguage.russian,
      );
      expect(ruParam, '4 / 5 МЕСТ');

      final kyParam = AppStrings.trParams(
        'league_slots_format',
        {'current': 4, 'max': 5},
        AppLanguage.kyrgyz,
      );
      expect(kyParam, '4 / 5 ОРУН');
    });
  });

  group('SplashScreen UI & Sacred Entrance Tests', () {
    testWidgets('SplashScreen renders sacred quote, subtitle and CircaPulsingLogo', (tester) async {
      final bridge = UteBleBridge();
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            bleBridge: bridge,
            isAuthenticated: false,
            displayDuration: const Duration(seconds: 10),
          ),
        ),
      );

      // Verify sacred proverb
      expect(find.text('«Адамга өз чегин билбей өлгөн уят»'), findsOneWidget);
      expect(find.text('«Стыдно человеку умереть, не познав предела своих сил»'), findsOneWidget);

      // Verify luxury pulsating logo
      expect(find.byType(CircaPulsingLogo), findsOneWidget);

      // Verify language toggle chip showing current language 'RU'
      expect(find.text('RU'), findsOneWidget);

      // Tap RU chip to toggle to Kyrgyz
      await tester.tap(find.text('RU'));
      await tester.pump();

      expect(AppLocaleNotifier.current, AppLanguage.kyrgyz);
      expect(find.text('KG'), findsOneWidget);
      expect(find.text('«Адам өз чегин, дараметин жана күчүн билбей өтүп кеткени уят»'), findsOneWidget);
    });
  });

  group('AuthScreen Tests (No Demo Login & Rich Branding)', () {
    testWidgets('AuthScreen has NO demo login button and shows quote + pulsing logo', (tester) async {
      final bridge = UteBleBridge();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(bleBridge: bridge),
        ),
      );

      // User explicitly requested: "демо вход убери"
      expect(find.text('БЫСТРЫЙ ДЕМО-ВХОД БЕЗ ПАРОЛЯ'), findsNothing);
      expect(find.text('Демо-вход'), findsNothing);
      expect(find.text('ДЕМО-ВХОД'), findsNothing);

      // Verify sacred quote and pulsing logo
      expect(find.text('«Адамга өз чегин билбей өлгөн уят»'), findsOneWidget);
      expect(find.byType(CircaPulsingLogo), findsOneWidget);

      // Verify brand title and login header in Russian
      expect(find.textContaining('КАЛКАН СПОРТ'), findsOneWidget);
      expect(find.text('Вход в биосистему'), findsOneWidget);
      expect(find.text('ВОЙТИ В СИСТЕМУ'), findsOneWidget);

      // Verify language toggle chip in Auth header
      expect(find.text('RU'), findsOneWidget);

      // Tap RU chip to toggle to Kyrgyz
      await tester.tap(find.text('RU'));
      await tester.pump();

      expect(AppLocaleNotifier.current, AppLanguage.kyrgyz);
      expect(find.text('KG'), findsOneWidget);
      expect(find.text('Биосистемага кирүү'), findsOneWidget);
      expect(find.text('СИСТЕМАГА КИРҮҮ'), findsOneWidget);
    });
  });

  group('ProfileScreen Language Switcher Card Tests', () {
    testWidgets('ProfileScreen shows language selector and allows interactive change', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bridge = UteBleBridge();
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            bleBridge: bridge,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify language section
      final langFinder = find.text('ЯЗЫК ИНТЕРФЕЙСА');
      expect(langFinder, findsOneWidget);

      expect(find.text('Русский (RU)'), findsOneWidget);
      expect(find.text('Кыргызча (KG)'), findsOneWidget);

      // Tap Kyrgyz button
      await tester.tap(find.text('Кыргызча (KG)'));
      await tester.pumpAndSettle();

      expect(AppLocaleNotifier.current, AppLanguage.kyrgyz);
      expect(find.text('ИНТЕРФЕЙС ТИЛИ'), findsOneWidget);
    });
  });
}
