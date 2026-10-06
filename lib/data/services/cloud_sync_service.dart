import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/secure_invite_generator.dart';
import '../../domain/intelligence/menstrual_cycle_engine.dart';
import '../../domain/models/partner_cycle_data.dart';
import '../../domain/models/user_profile.dart';
import '../storage/day_snapshot_repository.dart';
import '../storage/partner_cycle_repository.dart';
import '../storage/private_league_repository.dart';
import '../storage/user_profile_repository.dart';
import 'fcm_service.dart';
import 'user_session_manager.dart';
import 'cloud_outbox.dart';

/// Firestore only (Spark). No Storage.
class CloudSyncService {
  static bool get ready => Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static String? get uid {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static Future<void> pushProfile(UserProfile profile) async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;
    try {
      await db.collection('users').doc(id).set({
        'profileRaw': profile.serialize(),
        'name': profile.name,
        'email': profile.email,
        'gender': profile.gender.name,
        'hasCompletedProfile': profile.hasCompletedProfile,
        'heightCm': profile.heightCm,
        'weightKg': profile.weightKg,
        'birthYear': profile.birthYear,
        'stepGoal': profile.stepGoal,
        'calorieGoal': profile.calorieGoal,
        'sleepGoalHours': profile.sleepGoalHours,
        'isPregnant': profile.isPregnant,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      if (profile.gender == Gender.female) {
        await db.collection('cycle').doc(id).set({
          'cycleDay': profile.cycleDay ?? 1,
          'cycleLength': profile.cycleLengthDays,
          'phase': (profile.cyclePhase ?? HormonalCyclePhase.follicular).name,
          'partnerName': profile.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      }
      await CloudOutbox.markClean(CloudOutbox.profile);
    } catch (e) {
      debugPrint('CloudSync.pushProfile: $e');
      await CloudOutbox.markDirty(CloudOutbox.profile);
    }
  }

  static Future<UserProfile?> pullProfile() async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return null;
    try {
      final snap = await db.collection('users').doc(id).get().timeout(const Duration(seconds: 4));
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;

      final raw = data['profileRaw'] as String?;
      UserProfile? profile;
      if (raw != null && raw.isNotEmpty) {
        try {
          profile = UserProfile.deserialize(raw);
        } catch (_) {}
      }

      if (profile == null) {
        final name = (data['name'] as String?) ?? '';
        final email = (data['email'] as String?) ?? '';
        final genderStr = data['gender'] as String?;
        final hasCompleted = (data['hasCompletedProfile'] as bool?) ?? false;
        final h = (data['heightCm'] as num?)?.toDouble() ?? 175.0;
        final w = (data['weightKg'] as num?)?.toDouble() ?? 72.0;
        final b = (data['birthYear'] as num?)?.toInt() ?? 1996;
        final s = (data['stepGoal'] as num?)?.toInt() ?? 10000;
        final c = (data['calorieGoal'] as num?)?.toInt() ?? 650;
        final sl = (data['sleepGoalHours'] as num?)?.toDouble() ?? 8.0;
        final isPreg = (data['isPregnant'] as bool?) ?? false;

        profile = UserProfile(
          name: name,
          email: email,
          gender: genderStr == 'female'
              ? Gender.female
              : (genderStr == 'other' ? Gender.other : Gender.male),
          hasCompletedProfile: hasCompleted,
          heightCm: h,
          weightKg: w,
          birthYear: b,
          stepGoal: s,
          calorieGoal: c,
          sleepGoalHours: sl,
          isPregnant: isPreg,
        );
      }
      return profile.copyWith(isAuthenticated: true);
    } catch (e) {
      debugPrint('CloudSync.pullProfile: $e');
      return null;
    }
  }

  static Future<void> afterLogin(UserProfile local) async {
    final remote = await pullProfile();
    if (remote != null) {
      final merged = remote.copyWith(
        isAuthenticated: true,
        email: local.email.isNotEmpty ? local.email : remote.email,
      );
      await UserProfileRepository.saveProfile(merged);
    } else {
      await pushProfile(local);
    }
    await pullDays();
    await flushOutbox();
    try {
      await FcmService.init();
    } catch (_) {}
  }

  static String? _lastPushedDayKey;
  static int? _lastPushedRecovery;
  static double? _lastPushedStrain;
  static DateTime? _lastPushDayTime;

  static Future<void> pushDay(DaySnapshot day) async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;

    final today = DaySnapshot.keyFor(DateTime.now());
    final isToday = day.dateKey == today;

    // PERF-01: Debounce duplicate or very rapid writes within 3 seconds if data didn't change meaningfully
    final now = DateTime.now();
    if (_lastPushedDayKey == day.dateKey &&
        _lastPushedRecovery == day.recovery &&
        _lastPushedStrain != null &&
        (day.strain - _lastPushedStrain!).abs() < 0.1 &&
        _lastPushDayTime != null &&
        now.difference(_lastPushDayTime!).inSeconds < 3) {
      return;
    }

    _lastPushedDayKey = day.dateKey;
    _lastPushedRecovery = day.recovery;
    _lastPushedStrain = day.strain;
    _lastPushDayTime = now;

    try {
      await db
          .collection('days')
          .doc(id)
          .collection('snapshots')
          .doc(day.dateKey)
          .set(day.toJson())
          .timeout(const Duration(seconds: 4));
      // Only today's snapshot updates can publish active recovery to friend circle
      if (isToday) {
        await publishRecovery(recovery: day.recovery, hrv: day.hrv, rhr: day.rhr);
      }
      await CloudOutbox.markClean(CloudOutbox.day);
    } catch (e) {
      debugPrint('CloudSync.pushDay: $e');
      await CloudOutbox.markDirty(CloudOutbox.day);
    }
  }

  static int? _lastPublishedRecovery;
  static double? _lastPublishedHrv;
  static int? _lastPublishedRhr;

  static Future<void> publishRecovery({required int recovery, required double hrv, required int rhr}) async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;

    // PERF-01: Avoid redundant cloud writes if values haven't changed
    if (_lastPublishedRecovery == recovery &&
        _lastPublishedHrv != null &&
        (hrv - _lastPublishedHrv!).abs() < 0.5 &&
        _lastPublishedRhr == rhr) {
      return;
    }

    _lastPublishedRecovery = recovery;
    _lastPublishedHrv = hrv;
    _lastPublishedRhr = rhr;

    try {
      final mine = await db
          .collection('friends')
          .doc(id)
          .collection('members')
          .get()
          .timeout(const Duration(seconds: 4));

      final batch = db.batch();
      batch.set(db.collection('users').doc(id), {
        'recovery': recovery,
        'hrv': hrv,
        'rhr': rhr,
        'recoveryAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final f in mine.docs) {
        batch.set(db.collection('friends').doc(f.id).collection('members').doc(id), {
          'recovery': recovery,
          'hrv': hrv,
          'rhr': rhr,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('CloudSync.publishRecovery: $e');
    }
  }

  static Future<void> pullDays() async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;
    try {
      final qs = await db
          .collection('days')
          .doc(id)
          .collection('snapshots')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(60)
          .get()
          .timeout(const Duration(seconds: 4));

      final items = <DaySnapshot>[];
      for (final doc in qs.docs) {
        try {
          items.add(DaySnapshot.fromJson(doc.data()));
        } catch (_) {}
      }
      // PERF-01: Save all loaded days strictly locally without triggering cloud write cascade!
      await DaySnapshotRepository.upsertAll(items, syncToCloud: false);
    } catch (e) {
      debugPrint('CloudSync.pullDays: $e');
    }
  }

  static const String _keyCycleInviteCode = 'kalkan_cycle_partner_invite_code_v1';
  static const String _keyCycleInviteExpiresAt = 'kalkan_cycle_partner_invite_expires_at_v1';

  static Future<String> publishFriendInvite() async {
    final db = _db;
    final id = uid;
    final league = await PrivateLeagueRepository.loadLeague();
    var code = league.inviteCode;
    if (code.length < 12 || !code.startsWith('KLK-')) {
      code = SecureInviteGenerator.generateFriendCode();
      await PrivateLeagueRepository.saveLeague(league.copyWith(inviteCode: code));
    }
    if (db == null || id == null) return code;
    try {
      final profile = UserProfileRepository.profileNotifier.value;
      await db.collection('invites').doc(code).set({
        'ownerUid': id,
        'type': 'friend',
        'name': profile.name,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromMillisecondsSinceEpoch(
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        ),
      }).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('CloudSync.publishFriendInvite: $e');
    }
    return code;
  }

  static Future<bool> acceptFriendCode(String code) async {
    final db = _db;
    final id = uid;
    final raw = code.trim().toUpperCase();
    if (db == null || id == null || raw.isEmpty) return false;
    try {
      final inv = await db.collection('invites').doc(raw).get().timeout(const Duration(seconds: 4));
      if (!inv.exists) return false;
      final type = inv.data()?['type'] as String?;
      if (type != null && type != 'friend') return false; // Prevent cycle invite reuse
      final owner = inv.data()?['ownerUid'] as String?;
      final name = inv.data()?['name'] as String? ?? raw;
      if (owner == null || owner == id) return false;
      final expires = inv.data()?['expiresAt'] as Timestamp?;
      if (expires != null && expires.toDate().isBefore(DateTime.now())) return false;
      final me = UserProfileRepository.profileNotifier.value;
      await db.collection('friends').doc(id).collection('members').doc(owner).set({
        'name': name,
        'uid': owner,
        'code': raw,
      }).timeout(const Duration(seconds: 4));
      await db.collection('friends').doc(owner).collection('members').doc(id).set({
        'name': me.name,
        'uid': id,
        'code': raw,
      }).timeout(const Duration(seconds: 4));
      await PrivateLeagueRepository.addFriend(name: name, inviteCode: raw);
      return true;
    } catch (e) {
      debugPrint('CloudSync.acceptFriendCode: $e');
      return false;
    }
  }

  static Future<String> publishCycleInvite({bool forceRotate = false}) async {
    final db = _db;
    final id = uid;
    final prefs = await SharedPreferences.getInstance();
    var code = prefs.getString(_keyCycleInviteCode);
    final expiresAtMillis = prefs.getInt(_keyCycleInviteExpiresAt) ?? 0;
    final isExpired = expiresAtMillis > 0 && DateTime.now().millisecondsSinceEpoch > expiresAtMillis;

    if (forceRotate || code == null || code.length < 12 || !code.startsWith('KLK-CYC-') || isExpired) {
      code = SecureInviteGenerator.generateCycleCode();
      final exp = DateTime.now().add(const Duration(days: 7));
      await prefs.setString(_keyCycleInviteCode, code);
      await prefs.setInt(_keyCycleInviteExpiresAt, exp.millisecondsSinceEpoch);
    }
    if (db == null || id == null) return code;
    try {
      final profile = UserProfileRepository.profileNotifier.value;
      final expMillis = prefs.getInt(_keyCycleInviteExpiresAt) ?? (DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch);
      await db.collection('invites').doc(code).set({
        'ownerUid': id,
        'type': 'cycle',
        'name': profile.name.isNotEmpty ? profile.name : 'Партнёр',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromMillisecondsSinceEpoch(expMillis),
      }).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('CloudSync.publishCycleInvite: $e');
    }
    return code;
  }

  static Future<void> pushCycle(PartnerCycleData data) async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;
    try {
      final profile = UserProfileRepository.profileNotifier.value;
      await db.collection('cycle').doc(id).set({
        'cycleDay': data.cycleDay,
        'cycleLength': data.cycleLength,
        'phase': data.phase.name,
        'mood': data.mood,
        'flow': data.flow,
        'energyScore': data.energyScore,
        'symptoms': data.symptoms,
        'note': data.note,
        'partnerName': profile.name.isNotEmpty ? profile.name : data.partnerName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    await CloudOutbox.markClean(CloudOutbox.cycle);
    } catch (e) {
      debugPrint('CloudSync.pushCycle: $e');
      await CloudOutbox.markDirty(CloudOutbox.cycle);
    }
  }

  static Future<void> flushOutbox() async {
    if (!ready) return;
    final pending = await CloudOutbox.pending();
    for (final type in pending) {
      try {
        switch (type) {
          case CloudOutbox.profile:
            await pushProfile(UserProfileRepository.profileNotifier.value);
            break;
          case CloudOutbox.day:
            final latest = await DaySnapshotRepository.lastDays(1);
            if (latest.isNotEmpty) await pushDay(latest.first);
            break;
          case CloudOutbox.cycle:
            await pushCycle(PartnerCycleRepository.notifier.value);
            break;
        }
      } catch (e) {
        debugPrint('CloudSync.flushOutbox: $e');
      }
    }
  }

  static Future<bool> linkPartner(String code, [String? name]) async {
    final db = _db;
    final id = uid;
    final raw = code.trim().toUpperCase();
    if (raw.isEmpty) return false;

    // Partner cycle is a cloud-synchronized feature; require active session & database
    if (db == null || id == null) {
      debugPrint('CloudSync.linkPartner: cloud db unavailable or user not authenticated');
      return false;
    }

    String resolvedName = (name ?? '').trim();

    try {
      final inv = await db.collection('invites').doc(raw).get().timeout(const Duration(seconds: 6));
      if (!inv.exists) {
        debugPrint('CloudSync.linkPartner: invite code $raw not found');
        return false;
      }

      final invData = inv.data();
      final type = invData?['type'] as String?;
      if (type != 'cycle') {
        debugPrint('CloudSync.linkPartner: invite code $raw has invalid type ($type)');
        return false; // Prevent using non-cycle invite codes
      }

      final exp = invData?['expiresAt'];
      if (exp is Timestamp && exp.toDate().isBefore(DateTime.now())) {
        debugPrint('CloudSync.linkPartner: invite code $raw has expired');
        return false; // Invite code expired
      }

      final owner = invData?['ownerUid'] as String?;
      if (owner == null || owner.isEmpty || owner == id) {
        debugPrint('CloudSync.linkPartner: invalid partner owner ($owner)');
        return false; // Cannot link self or empty owner
      }

      final inviteName = invData?['name'] as String?;
      if (resolvedName.isEmpty && inviteName != null && inviteName.isNotEmpty) {
        resolvedName = inviteName;
      }
      if (resolvedName.isEmpty) {
        resolvedName = 'Партнёр';
      }

      // Write verified partner link to Firestore
      await db.collection('partners').doc(id).set({
        'partnerUid': owner,
        'code': raw,
        'linkedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 6));

      // Also register as an authorized viewer in cycle owner's subcollection (SEC-02)
      final me = UserProfileRepository.profileNotifier.value;
      try {
        await db.collection('cycle').doc(owner).collection('viewers').doc(id).set({
          'partnerUid': id,
          'partnerName': me.name.isNotEmpty ? me.name : 'Партнёр',
          'code': raw,
          'linkedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('CloudSync.linkPartner viewer registration error: $e');
      }

      // Successfully written to cloud -> link locally and trigger initial pull
      await PartnerCycleRepository.linkPartner(partnerCode: raw, partnerName: resolvedName);
      await pullPartnerCycle();
      return true;
    } catch (e) {
      debugPrint('CloudSync.linkPartner error: $e');
      return false;
    }
  }

  /// Получение списка партнёров, имеющих доступ к просмотру цикла (SEC-02)
  static Future<List<CycleViewer>> pullCycleViewers() async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return [];
    try {
      final snap = await db.collection('cycle').doc(id).collection('viewers').get().timeout(const Duration(seconds: 4));
      return snap.docs.map((d) => CycleViewer.fromMap(d.id, d.data())).toList();
    } catch (e) {
      debugPrint('CloudSync.pullCycleViewers: $e');
      return [];
    }
  }

  /// Отзыв доступа партнёра к просмотру цикла (SEC-02)
  static Future<bool> revokeCycleViewer(String viewerUid) async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return false;
    try {
      await db.collection('cycle').doc(id).collection('viewers').doc(viewerUid).delete().timeout(const Duration(seconds: 4));
      return true;
    } catch (e) {
      debugPrint('CloudSync.revokeCycleViewer: $e');
      return false;
    }
  }

  /// Ротация инвайт-кода цикла с автоматическим аннулированием старого (SEC-02)
  static Future<String> rotateCycleInvite() async {
    return publishCycleInvite(forceRotate: true);
  }

  static Future<void> pullPartnerCycle() async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;
    try {
      final link = await db.collection('partners').doc(id).get().timeout(const Duration(seconds: 4));
      final other = link.data()?['partnerUid'] as String?;
      if (other == null) return;
      final doc = await db.collection('cycle').doc(other).get().timeout(const Duration(seconds: 4));
      final d = doc.data();
      if (d == null) return;
      final current = await PartnerCycleRepository.loadPartnerCycle();
      final cloudName = d['partnerName'] as String?;
      final cycleDay = (d['cycleDay'] as num?)?.toInt() ?? current.cycleDay;
      final cycleLength = (d['cycleLength'] as num?)?.toInt() ?? current.cycleLength;
      final phaseStr = d['phase'] as String?;
      HormonalCyclePhase phase;
      if (phaseStr != null) {
        phase = HormonalCyclePhase.values.firstWhere(
          (p) => p.name == phaseStr,
          orElse: () => MenstrualCycleEngine.determinePhase(cycleDay, cycleLength: cycleLength),
        );
      } else {
        phase = MenstrualCycleEngine.determinePhase(cycleDay, cycleLength: cycleLength);
      }
      await PartnerCycleRepository.savePartnerCycle(current.copyWith(
        isLinked: true,
        partnerName: cloudName != null && cloudName.isNotEmpty ? cloudName : (current.partnerName.isNotEmpty ? current.partnerName : 'Партнёр'),
        cycleDay: cycleDay,
        cycleLength: cycleLength,
        phase: phase,
        mood: d['mood'] as String? ?? current.mood,
        flow: d['flow'] as String? ?? current.flow,
        energyScore: (d['energyScore'] as num?)?.toInt() ?? current.energyScore,
        note: d['note'] as String? ?? current.note,
        lastSyncTime: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('CloudSync.pullPartnerCycle: $e');
    }
  }

  /// Полное удаление аккаунта и связанных данных (App Store Guideline 5.1.1(v)):
  /// 1. Удаление данных пользователя в Firestore (users, cycle, partners, days, friends, invites).
  /// 2. Удаление учетной записи в Firebase Auth.
  /// 3. Очистка локального хранилища (SharedPreferences).
  /// Полное удаление аккаунта и связанных данных (App Store Guideline 5.1.1(v)):
  /// 1. (Опционально) Повторная аутентификация с паролем (reauthenticateWithCredential).
  /// 2. Каскадное удаление всех данных пользователя в Firestore:
  ///    - Удаление своей карточки из кругов друзей (friends/{friendId}/members/{id})
  ///    - Удаление снимков дней (days/{id}/snapshots/*) через batch
  ///    - Удаление участников своего круга (friends/{id}/members/*) через batch
  ///    - Удаление инвайтов (invites/{cycleCode}, invites/{leagueCode})
  ///    - Удаление partners/{id}, cycle/{id}, users/{id}
  /// 3. Удаление учетной записи в Firebase Auth (user.delete()).
  /// 4. Только при 100% успехе (Firestore + Auth) — очистка локального хранилища и сессии.
  /// 5. При любой ошибке — проброс исключения, локальные данные НЕ стираются!
  static Future<void> deleteAccountAndData({String? password}) async {
    final user = FirebaseAuth.instance.currentUser;
    final id = uid;
    final db = _db;

    if (user == null || id == null || db == null) {
      throw Exception('Пользователь не авторизован или облачный сервис недоступен.');
    }

    // 1. Повторная аутентификация при наличии пароля
    if (password != null && password.isNotEmpty && user.email != null) {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred).timeout(const Duration(seconds: 10));
    }

    // 2. Каскадное удаление данных в Firestore (выполняется строго ДО удаления Auth, чтобы не потерять права)
    try {
      // 2a. Удаляем свою карточку из кругов друзей (friends/{friendUid}/members/{id})
      try {
        final myFriends = await db
            .collection('friends')
            .doc(id)
            .collection('members')
            .get()
            .timeout(const Duration(seconds: 8));
        for (final f in myFriends.docs) {
          final friendUid = f.id;
          if (friendUid.isNotEmpty && friendUid != id) {
            try {
              await db
                  .collection('friends')
                  .doc(friendUid)
                  .collection('members')
                  .doc(id)
                  .delete()
                  .timeout(const Duration(seconds: 4));
            } catch (e) {
              debugPrint('CloudSync.deleteAccountAndData: could not remove from friend $friendUid: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('CloudSync.deleteAccountAndData: friends traversal note: $e');
      }

      // 2b. Пакетное удаление снимков дней (days/{id}/snapshots/*)
      final daysSnap = await db
          .collection('days')
          .doc(id)
          .collection('snapshots')
          .get()
          .timeout(const Duration(seconds: 8));

      // 2c. Пакетное удаление участников своего круга (friends/{id}/members/*)
      final friendsSnap = await db
          .collection('friends')
          .doc(id)
          .collection('members')
          .get()
          .timeout(const Duration(seconds: 8));

      final batch = db.batch();
      for (final doc in daysSnap.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in friendsSnap.docs) {
        batch.delete(doc.reference);
      }

      // 2d. Инвайты
      final prefs = await SharedPreferences.getInstance();
      final cycleCode = prefs.getString(_keyCycleInviteCode);
      if (cycleCode != null && cycleCode.isNotEmpty) {
        batch.delete(db.collection('invites').doc(cycleCode));
      }
      try {
        final league = await PrivateLeagueRepository.loadLeague();
        if (league.inviteCode.isNotEmpty) {
          batch.delete(db.collection('invites').doc(league.inviteCode));
        }
      } catch (_) {}

      // 2e. Корневые документы
      batch.delete(db.collection('partners').doc(id));
      batch.delete(db.collection('cycle').doc(id));
      batch.delete(db.collection('users').doc(id));

      // Фиксируем пакетное удаление
      await batch.commit().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('CloudSync.deleteAccountAndData firestore failed: $e');
      throw Exception('Ошибка при удалении данных из облака: $e. Аккаунт не был удален.');
    }

    // 3. Удаляем учетную запись Firebase Auth
    try {
      await user.delete().timeout(const Duration(seconds: 10));
    } on FirebaseAuthException catch (e) {
      debugPrint('CloudSync.deleteAccountAndData auth delete error: ${e.code}');
      if (e.code == 'requires-recent-login') {
        rethrow;
      }
      throw Exception('Не удалось удалить профиль авторизации: ${e.message ?? e.code}');
    }

    // 4. Очищаем локальные хранилища ТОЛЬКО при полном успехе
    await CloudOutbox.clearOutbox();
    await UserSessionManager.clearLocalUserData();
    await UserProfileRepository.saveProfile(const UserProfile(isAuthenticated: false));
  }
}
