import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/data/ble/ute_ble_bridge.dart';
import 'package:barys_biotracker/domain/models/private_league.dart';
import 'package:barys_biotracker/domain/models/readiness.dart';
import 'package:barys_biotracker/data/storage/private_league_repository.dart';
import 'package:barys_biotracker/domain/avatar/avatar_manager.dart';
import 'package:barys_biotracker/presentation/screens/private_league_screen.dart';
import 'package:barys_biotracker/presentation/widgets/circa_friend_detail_sheet.dart';
import 'package:barys_biotracker/presentation/widgets/circa_edge_fade.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Private League Domain Model & Dunbar Limit (3-5 Friends)', () {
    test('PrivateLeague defaults to max 5 members (Dunbar rule)', () {
      final league = PrivateLeague(
        id: 'test-league',
        title: 'Тестовый круг',
        inviteCode: 'CIRCA-TEST',
        members: [
          const FriendMember(
            id: '1',
            name: 'Алихан',
            city: 'Алматы',
            avatarInitials: 'АХ',
            rankTitle: 'Батыр',
            level: 4,
            recoveryScore: 85,
            recoveryZone: RecoveryZone.optimal,
            currentDayStrain: 12.4,
            sleepHours: 7.8,
            sleepPerformance: 92,
            hrv: 64,
            restingHeartRate: 51,
            lastSyncText: '12 мин назад',
            statusQuote: 'В строю',
          ),
        ],
      );

      expect(league.maxMembers, 5);
      expect(league.isFull, false);
      expect(league.availableSlots, 4);
      expect(league.averageRecoveryScore, 85.0);
    });

    test('PrivateLeague enforces maximum 5 members limit', () {
      final members = List.generate(
        5,
        (i) => FriendMember(
          id: 'user_$i',
          name: 'Друг $i',
          city: 'Алматы',
          avatarInitials: 'Д$i',
          rankTitle: 'Сарбаз',
          level: 2,
          recoveryScore: 70 + i * 4,
          recoveryZone: RecoveryZone.optimal,
          currentDayStrain: 10.0,
          sleepHours: 7.5,
          sleepPerformance: 88,
          hrv: 55,
          restingHeartRate: 54,
          lastSyncText: '5 мин назад',
          statusQuote: 'Готов к нагрузке',
        ),
      );

      final fullLeague = PrivateLeague(
        id: 'league-full',
        title: 'Полный круг',
        inviteCode: 'CIRCA-FULL',
        members: members,
      );

      expect(fullLeague.isFull, true);
      expect(fullLeague.availableSlots, 0);
    });

    test('PrivateLeague serialization and deserialization roundtrip', () {
      final original = PrivateLeague(
        id: 'json-league',
        title: 'JSON Круг',
        inviteCode: 'CIRCA-JSON',
        members: [
          const FriendMember(
            id: 'm1',
            name: 'Кайрат',
            city: 'Шымкент',
            avatarInitials: 'КР',
            rankTitle: 'Батыр',
            level: 3,
            recoveryScore: 89,
            recoveryZone: RecoveryZone.optimal,
            currentDayStrain: 14.1,
            sleepHours: 8.1,
            sleepPerformance: 95,
            hrv: 72,
            restingHeartRate: 49,
            lastSyncText: 'только что',
            statusQuote: 'Легкий бег на Медеу',
            isCurrentUser: true,
          ),
        ],
      );

      final serialized = original.serialize();
      final restored = PrivateLeague.deserialize(serialized);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.inviteCode, original.inviteCode);
      expect(restored.members.length, 1);
      expect(restored.members.first.name, 'Кайрат');
      expect(restored.members.first.isCurrentUser, true);
    });
  });

  group('Private League Repository Tests', () {
    test('loadLeague initializes default 4 curated members and supports adding/removing friends', () async {
      final league = await PrivateLeagueRepository.loadLeague();

      expect(league.members.length, 4);
      expect(league.isFull, false);
      expect(league.availableSlots, 1);

      // Add a 5th friend
      final added = await PrivateLeagueRepository.addFriend(
        name: 'Арман И.',
        city: 'Астана',
      );
      expect(added, true);

      final updated = await PrivateLeagueRepository.loadLeague();
      expect(updated.members.length, 5);
      expect(updated.isFull, true);
      expect(updated.availableSlots, 0);
      expect(updated.members.last.name, 'Арман И.');

      // Adding when full should return false
      final overLimit = await PrivateLeagueRepository.addFriend(
        name: 'Шестой друг',
      );
      expect(overLimit, false);

      // Removing a friend restores an available slot
      await PrivateLeagueRepository.removeFriend(updated.members.last.id);
      final afterRemove = await PrivateLeagueRepository.loadLeague();
      expect(afterRemove.members.length, 4);
      expect(afterRemove.isFull, false);
    });

    test('sendImpulse succeeds without error', () async {
      await expectLater(
        PrivateLeagueRepository.sendImpulse('member-1'),
        completes,
      );
    });
  });

  group('XP Reactive Synchronization Tests', () {
    test('AvatarManager.xpNotifier broadcasts XP changes across screens', () async {
      AvatarManager.setXpForTesting(150, level: 1);
      expect(AvatarManager.xpNotifier.value, 150);

      int? listenedXp;
      void listener() {
        listenedXp = AvatarManager.xpNotifier.value;
      }

      AvatarManager.xpNotifier.addListener(listener);

      // Simulate a workout reward (+148 XP)
      await AvatarManager.addXp(148);
      expect(listenedXp, 298);

      AvatarManager.xpNotifier.removeListener(listener);
    });
  });

  group('CircaEdgeFade Widget Test', () {
    testWidgets('CircaEdgeFade renders child with ShaderMask gradient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircaEdgeFade(
              fadeWidthFraction: 0.1,
              child: SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    Text('Item 1'),
                    Text('Item 2'),
                    Text('Item 3'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });

  group('Private League & Friend Detail UI Tests', () {
    testWidgets('PrivateLeagueScreen renders league header, slots, friends and allows detail view', (tester) async {
      final bleBridge = UteBleBridge();

      await tester.pumpWidget(
        MaterialApp(
          home: PrivateLeagueScreen(bleBridge: bleBridge),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header and league details
      expect(find.text('Приватная лига КАЛКАН'), findsOneWidget);
      expect(find.text('КРУГ БАТЫРОВ · ALMATY ATELIER'), findsOneWidget);
      expect(find.text('4 / 5 МЕСТ'), findsOneWidget);
      expect(find.text('СРЕДНЕЕ ВОССТАНОВЛЕНИЕ КРУГА'), findsOneWidget);

      // Curated friends
      expect(find.text('Даурен С.'), findsOneWidget);
      expect(find.text('Алия М.'), findsOneWidget);
      expect(find.text('Тимур К.'), findsOneWidget);

      // Tap on a friend to open biometric snapshot sheet
      await tester.tap(find.text('Даурен С.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Biometric snapshot elements
      expect(find.text('ВОССТАНОВЛЕНИЕ (RECOVERY)'), findsOneWidget);
      expect(find.text('ОТПРАВИТЬ ИМПУЛЬС СИЛЫ БАРЫСА ✦'), findsOneWidget);

      // Tap impulse button
      await tester.tap(find.text('ОТПРАВИТЬ ИМПУЛЬС СИЛЫ БАРЫСА ✦'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('CircaFriendDetailSheet displays metrics and sends impulse', (tester) async {
      const friend = FriendMember(
        id: 'test_friend_1',
        name: 'Нурлан Б.',
        city: 'Алматы',
        avatarInitials: 'НБ',
        rankTitle: 'Батыр',
        level: 3,
        recoveryScore: 94,
        recoveryZone: RecoveryZone.optimal,
        currentDayStrain: 11.2,
        sleepHours: 8.2,
        sleepPerformance: 96,
        hrv: 78,
        restingHeartRate: 48,
        lastSyncText: '10 мин назад',
        statusQuote: 'Горный поход на Кок-Жайляу',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircaFriendDetailSheet(member: friend),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Нурлан Б.'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      expect(find.text('78 мс'), findsOneWidget);
      expect(find.text('48 bpm'), findsOneWidget);
      expect(find.text('ОТПРАВИТЬ ИМПУЛЬС СИЛЫ БАРЫСА ✦'), findsOneWidget);

      await tester.tap(find.text('ОТПРАВИТЬ ИМПУЛЬС СИЛЫ БАРЫСА ✦'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
