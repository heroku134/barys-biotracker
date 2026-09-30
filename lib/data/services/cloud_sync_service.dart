import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/secure_invite_generator.dart';
import '../../domain/models/partner_cycle_data.dart';
import '../../domain/models/user_profile.dart';
import '../storage/day_snapshot_repository.dart';
import '../storage/partner_cycle_repository.dart';
import '../storage/private_league_repository.dart';
import '../storage/user_profile_repository.dart';
import 'fcm_service.dart';

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
    } catch (e) {
      debugPrint('CloudSync.pushProfile: $e');
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
          gender: genderStr == 'female' ? Gender.female : Gender.male,
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
    try {
      await FcmService.init();
    } catch (_) {}
  }

  static Future<void> pushDay(DaySnapshot day) async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;
    try {
      await db.collection('days').doc(id).collection('snapshots').doc(day.dateKey).set(day.toJson()).timeout(const Duration(seconds: 4));
      await publishRecovery(recovery: day.recovery, hrv: day.hrv, rhr: day.rhr);
    } catch (e) {
      debugPrint('CloudSync.pushDay: $e');
    }
  }

  static Future<void> publishRecovery({required int recovery, required double hrv, required int rhr}) async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;
    try {
      await db.collection('users').doc(id).set({
        'recovery': recovery,
        'hrv': hrv,
        'rhr': rhr,
        'recoveryAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      final mine = await db.collection('friends').doc(id).collection('members').get().timeout(const Duration(seconds: 4));
      for (final f in mine.docs) {
        await db.collection('friends').doc(f.id).collection('members').doc(id).set({
          'recovery': recovery,
          'hrv': hrv,
          'rhr': rhr,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('CloudSync.publishRecovery: $e');
    }
  }

  static Future<void> pullDays() async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;
    try {
      final qs = await db.collection('days').doc(id).collection('snapshots').get().timeout(const Duration(seconds: 4));
      for (final doc in qs.docs) {
        await DaySnapshotRepository.upsert(DaySnapshot.fromJson(doc.data()));
      }
    } catch (e) {
      debugPrint('CloudSync.pullDays: $e');
    }
  }

  static const String _keyCycleInviteCode = 'kalkan_cycle_partner_invite_code_v1';

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
      final me = UserProfileRepository.profileNotifier.value;
      await db.collection('friends').doc(id).collection('members').doc(owner).set({
        'name': name,
        'uid': owner,
      }).timeout(const Duration(seconds: 4));
      await db.collection('friends').doc(owner).collection('members').doc(id).set({
        'name': me.name,
        'uid': id,
      }).timeout(const Duration(seconds: 4));
      await PrivateLeagueRepository.addFriend(name: name, inviteCode: raw);
      return true;
    } catch (e) {
      debugPrint('CloudSync.acceptFriendCode: $e');
      return false;
    }
  }

  static Future<String> publishCycleInvite() async {
    final db = _db;
    final id = uid;
    final prefs = await SharedPreferences.getInstance();
    var code = prefs.getString(_keyCycleInviteCode);
    if (code == null || code.length < 12 || !code.startsWith('KLK-')) {
      code = SecureInviteGenerator.generateCycleCode();
      await prefs.setString(_keyCycleInviteCode, code);
    }
    if (db == null || id == null) return code;
    try {
      final profile = UserProfileRepository.profileNotifier.value;
      await db.collection('invites').doc(code).set({
        'ownerUid': id,
        'type': 'cycle',
        'name': profile.name.isNotEmpty ? profile.name : 'Партнёр',
        'createdAt': FieldValue.serverTimestamp(),
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
    } catch (e) {
      debugPrint('CloudSync.pushCycle: $e');
    }
  }

  static Future<bool> linkPartner(String code, [String? name]) async {
    final db = _db;
    final id = uid;
    final raw = code.trim().toUpperCase();
    if (raw.isEmpty) return false;

    String resolvedName = (name ?? '').trim();

    try {
      if (db != null && id != null) {
        final inv = await db.collection('invites').doc(raw).get().timeout(const Duration(seconds: 4));
        if (inv.exists) {
          final type = inv.data()?['type'] as String?;
          if (type != null && type != 'cycle') {
            return false; // Prevent using non-cycle invite codes
          }
          final owner = inv.data()?['ownerUid'] as String?;
          final inviteName = inv.data()?['name'] as String?;
          if (resolvedName.isEmpty && inviteName != null && inviteName.isNotEmpty) {
            resolvedName = inviteName;
          }
          if (owner != null) {
            await db.collection('partners').doc(id).set({
              'partnerUid': owner,
              'code': raw,
              'linkedAt': FieldValue.serverTimestamp(),
            }).timeout(const Duration(seconds: 4));
          }
        } else {
          return false;
        }
      }
    } catch (e) {
      debugPrint('CloudSync.linkPartner: $e');
    }

    if (resolvedName.isEmpty) {
      resolvedName = 'Партнёр';
    }

    await PartnerCycleRepository.linkPartner(partnerCode: raw, partnerName: resolvedName);
    await pullPartnerCycle();
    return true;
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
      await PartnerCycleRepository.savePartnerCycle(current.copyWith(
        isLinked: true,
        partnerName: cloudName != null && cloudName.isNotEmpty ? cloudName : (current.partnerName.isNotEmpty ? current.partnerName : 'Партнёр'),
        cycleDay: (d['cycleDay'] as num?)?.toInt() ?? current.cycleDay,
        cycleLength: (d['cycleLength'] as num?)?.toInt() ?? current.cycleLength,
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
  static Future<void> deleteAccountAndData() async {
    final db = _db;
    final id = uid;
    final user = FirebaseAuth.instance.currentUser;

    if (db != null && id != null) {
      try {
        // Удаляем документы пользователя
        await db.collection('users').doc(id).delete().timeout(const Duration(seconds: 4));
        await db.collection('cycle').doc(id).delete().timeout(const Duration(seconds: 4));
        await db.collection('partners').doc(id).delete().timeout(const Duration(seconds: 4));

        // Удаляем снимки дней
        final daysSnap = await db.collection('days').doc(id).collection('snapshots').get().timeout(const Duration(seconds: 4));
        for (final doc in daysSnap.docs) {
          await doc.reference.delete().timeout(const Duration(seconds: 2));
        }

        // Удаляем записи участников круга
        final friendsSnap = await db.collection('friends').doc(id).collection('members').get().timeout(const Duration(seconds: 4));
        for (final doc in friendsSnap.docs) {
          await doc.reference.delete().timeout(const Duration(seconds: 2));
        }

        // Удаляем свои инвайты
        final prefs = await SharedPreferences.getInstance();
        final cycleCode = prefs.getString(_keyCycleInviteCode);
        if (cycleCode != null && cycleCode.isNotEmpty) {
          await db.collection('invites').doc(cycleCode).delete().timeout(const Duration(seconds: 2));
        }
        final league = await PrivateLeagueRepository.loadLeague();
        if (league.inviteCode.isNotEmpty) {
          await db.collection('invites').doc(league.inviteCode).delete().timeout(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint('CloudSync.deleteAccountAndData firestore: $e');
      }
    }

    // Удаляем Firebase Auth пользователя
    if (user != null) {
      try {
        await user.delete().timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('CloudSync.deleteAccountAndData auth delete note: $e');
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }
    }

    // Очищаем локальные хранилища
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    await UserProfileRepository.saveProfile(const UserProfile(isAuthenticated: false));
  }
}
