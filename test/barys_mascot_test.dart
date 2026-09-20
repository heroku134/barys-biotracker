import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/data/ble/ute_ble_bridge.dart';
import 'package:barys_biotracker/domain/avatar/avatar_manager.dart';
import 'package:barys_biotracker/domain/models/personal_baseline.dart';
import 'package:barys_biotracker/domain/models/telemetry.dart';
import 'package:barys_biotracker/presentation/screens/bio_avatar_screen.dart';
import 'package:barys_biotracker/presentation/widgets/bio_avatar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Barys Evolution & Memory Tests', () {
    test('All 4 evolution tiers have valid metadata and progression', () {
      expect(BarysEvolutionTier.values.length, 4);

      expect(BarysEvolutionTier.cadet.shortName, 'Кадет');
      expect(BarysEvolutionTier.sarbaz.shortName, 'Сарбаз');
      expect(BarysEvolutionTier.batyr.shortName, 'Батыр');
      expect(BarysEvolutionTier.aksakal.shortName, 'Аксакал');

      for (final tier in BarysEvolutionTier.values) {
        expect(tier.title.isNotEmpty, isTrue);
        expect(tier.description.isNotEmpty, isTrue);
        expect(tier.ornamentName.isNotEmpty, isTrue);
        expect(tier.unlockBenefit.isNotEmpty, isTrue);
        expect(tier.minLevel, greaterThan(0));
      }
    });

    test('getEvolutionTier maps level to correct tier', () {
      expect(AvatarManager.getEvolutionTier(1), BarysEvolutionTier.cadet);
      expect(AvatarManager.getEvolutionTier(4), BarysEvolutionTier.cadet);
      expect(AvatarManager.getEvolutionTier(5), BarysEvolutionTier.sarbaz);
      expect(AvatarManager.getEvolutionTier(9), BarysEvolutionTier.sarbaz);
      expect(AvatarManager.getEvolutionTier(10), BarysEvolutionTier.batyr);
      expect(AvatarManager.getEvolutionTier(19), BarysEvolutionTier.batyr);
      expect(AvatarManager.getEvolutionTier(20), BarysEvolutionTier.aksakal);
      expect(AvatarManager.getEvolutionTier(50), BarysEvolutionTier.aksakal);
    });

    test('getEvolutionProgress computes remaining XP to next tier', () {
      final cadetProgress = AvatarManager.getEvolutionProgress(1, 100);
      expect(cadetProgress.currentTier, BarysEvolutionTier.cadet);
      expect(cadetProgress.nextTier, BarysEvolutionTier.sarbaz);
      expect(cadetProgress.xpToNextTier, greaterThan(0));

      final maxProgress = AvatarManager.getEvolutionProgress(25, 500);
      expect(maxProgress.currentTier, BarysEvolutionTier.aksakal);
      expect(maxProgress.nextTier, isNull);
      expect(maxProgress.xpToNextTier, 0);
    });

    test('getMemoryQuote generates contextual phrases referencing yesterday data', () {
      final telemetry = BleTelemetry(
        timestamp: DateTime(2026, 9, 20, 10, 0),
        heartRate: 60,
        restingHeartRate: 50,
        hrv: 68.0,
        sleepMinutes: 480,
      );

      // 1. Вчера был высокий Strain >= 14
      const baselineHigh = PersonalBaseline(yesterdayStrain: 14.8);
      final quoteHigh = AvatarManager.getMemoryQuote(telemetry: telemetry, baseline: baselineHigh);
      expect(quoteHigh, contains('14.8'));
      expect(quoteHigh, contains('8.1 км'));

      // 2. Вчера отоспались
      const baselineGoodSleep = PersonalBaseline(yesterdayStrain: 10.0, sleepDebtMinutes: 10);
      final quoteSleep = AvatarManager.getMemoryQuote(telemetry: telemetry, baseline: baselineGoodSleep);
      expect(quoteSleep, contains('глубокого сна'));

      // 3. Долг сна >= 40
      const baselineDebt = PersonalBaseline(sleepDebtMinutes: 45);
      final quoteDebt = AvatarManager.getMemoryQuote(telemetry: telemetry, baseline: baselineDebt);
      expect(quoteDebt, contains('45 минут'));
    });

    test('interactiveTapQuotes has responsive and encouraging phrases', () {
      expect(AvatarManager.interactiveTapQuotes.length, greaterThanOrEqualTo(5));
      for (final quote in AvatarManager.interactiveTapQuotes) {
        expect(quote.isNotEmpty, isTrue);
      }
      final reaction = AvatarManager.getRandomTapReaction();
      expect(reaction.isNotEmpty, isTrue);
    });
  });

  group('BioAvatarScreen & BioAvatarWidget UI Tests', () {
    testWidgets('BioAvatarScreen renders Barys, Evolution card, and Memory card', (tester) async {
      final bleBridge = UteBleBridge();

      await tester.pumpWidget(
        MaterialApp(
          home: BioAvatarScreen(bleBridge: bleBridge),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Проверяем наличие аватара
      expect(find.byType(BioAvatarWidget), findsOneWidget);

      // Проверяем, что слайдер состояний (Авто/Бодрый/В тонусе/...) УБРАН из основного экрана
      // Никаких чипов 'Автономный' или 'В тонусе' в теле экрана нет
      expect(find.text('Автономный (ИИ)'), findsNothing);

      // Проверяем, что карточка памяти о вчерашнем дне убрана по запросу пользователя
      expect(find.text('ПАМЯТЬ БАРЫСА О ВЧЕРАШНЕМ ДНЕ'), findsNothing);
      expect(find.text('ВЧЕРА → СЕГОДНЯ'), findsNothing);

      // Проверяем карточку пути эволюции
      expect(find.textContaining('ИРБИС-КАДЕТ'), findsWidgets);
      expect(find.text('Все ступени эволюции >'), findsOneWidget);

      // Проверяем, что устаревшие числовые RPG-статы убраны
      expect(find.text('ВЫНОСЛИВОСТЬ'), findsNothing);
      expect(find.text('СИЛА'), findsNothing);
      expect(find.text('ФОКУС'), findsNothing);

      // Проверяем автоматические сенсорные задачи активности
      expect(find.textContaining('ЕЖЕДНЕВНЫЕ ЗАДАЧИ АКТИВНОСТИ'), findsOneWidget);
      expect(find.textContaining('Дневная норма активности'), findsOneWidget);
      expect(find.textContaining('Дневная норма шагов'), findsOneWidget);
      expect(find.textContaining('Сон и восстановление'), findsOneWidget);
    });

    testWidgets('Tapping Barys triggers interactive speech bubble with live quote', (tester) async {
      final bleBridge = UteBleBridge();

      await tester.pumpWidget(
        MaterialApp(
          home: BioAvatarScreen(bleBridge: bleBridge),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Тапаем по Барысу
      await tester.tap(find.byType(BioAvatarWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Должно появиться облачко речи с цитатой Барыса
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('Tapping tune button in AppBar opens Dev Scenarios sheet', (tester) async {
      final bleBridge = UteBleBridge();

      await tester.pumpWidget(
        MaterialApp(
          home: BioAvatarScreen(bleBridge: bleBridge),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Нажимаем на иконку настроек / отладки в AppBar
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // В шторке отладки теперь доступны сценарии
      expect(find.text('РЕЖИМ ОТЛАДКИ МАСКОТА (DEV)'), findsOneWidget);
      expect(find.text('Автономный (ИИ)'), findsOneWidget);
    });

    testWidgets('Tapping evolution link opens all 4 tiers sheet', (tester) async {
      final bleBridge = UteBleBridge();

      await tester.pumpWidget(
        MaterialApp(
          home: BioAvatarScreen(bleBridge: bleBridge),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Скроллим к ссылке «Все ступени эволюции >» и тапаем
      final linkFinder = find.text('Все ступени эволюции >');
      await tester.ensureVisible(linkFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(linkFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Проверяем отображение всех 4 ступеней
      expect(find.text('ПУТЬ ЭВОЛЮЦИИ БАРЫСА'), findsOneWidget);
      expect(find.text('СТЕПНОЙ САРБАЗ'), findsOneWidget);
      expect(find.text('ХАНСКИЙ БАТЫР'), findsOneWidget);
      expect(find.text('МУДРЫЙ АКСАКАЛ'), findsOneWidget);
    });
  });
}
