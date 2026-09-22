import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/partner_cycle_data.dart';
import '../../domain/models/user_profile.dart';
import '../storage/day_snapshot_repository.dart';
import '../storage/partner_cycle_repository.dart';
import '../storage/private_league_repository.dart';
import '../storage/user_profile_repository.dart';

/// Firestore only (Spark). No Storage.
class CloudSyncService {
  static bool get ready => Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  static FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

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
      debugPrint('CloudSync.pushProfile note: $e');
    }
  }

  static Future<UserProfile?> pullProfile() async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return null;
    try {
      final snap = await db.collection('users').doc(id).get().timeout(const Duration(seconds: 4));
      final raw = snap.data()?['profileRaw'] as String?;
      if (raw == null || raw.isEmpty) return null;
      return UserProfile.deserialize(raw).copyWith(isAuthenticated: true);
    } catch (e) {
      debugPrint('CloudSync.pullProfile note: $e');
      return null;
    }
  }

  static Future<void> afterLogin(UserProfile local) async {
    try {
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
    } catch (e) {
      debugPrint('CloudSync.afterLogin note: $e');
    }
  }

  static Future<void> pushDay(DaySnapshot day) async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;
    try {
      await db.collection('days').doc(id).collection('snapshots').doc(day.dateKey).set(day.toJson()).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('CloudSync.pushDay note: $e');
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
      debugPrint('CloudSync.pullDays note: $e');
    }
  }

  static Future<String> publishFriendInvite() async {
    final db = _db;
    final id = uid;
    final code = 'KALKAN-${(id ?? 'LOCAL').hashCode.abs().toString().padLeft(4, '0').substring(0, 4)}';
    if (db == null || id == null) return code;
    try {
      final profile = UserProfileRepository.profileNotifier.value;
      await db.collection('invites').doc(code).set({
        'ownerUid': id,
        'type': 'friend',
        'name': profile.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
      final inv = await db.collection('invites').doc(raw).get();
      if (!inv.exists) return false;
      final owner = inv.data()?['ownerUid'] as String?;
      final name = inv.data()?['name'] as String? ?? raw;
      if (owner == null || owner == id) return false;
      final me = UserProfileRepository.profileNotifier.value;
      await db.collection('friends').doc(id).collection('members').doc(owner).set({
        'name': name,
        'uid': owner,
      });
      await db.collection('friends').doc(owner).collection('members').doc(id).set({
        'name': me.name,
        'uid': id,
      });
      await PrivateLeagueRepository.addFriend(name: name, inviteCode: raw);
      return true;
    } catch (e) {
      debugPrint('CloudSync.acceptFriendCode: $e');
      return false;
    }
  }

  static Future<void> pushCycle(PartnerCycleData data) async {
    final db = _db;
    final id = uid;
    if (db == null || id == null) return;
    try {
      await db.collection('cycle').doc(id).set({
        'cycleDay': data.cycleDay,
        'cycleLength': data.cycleLength,
        'phase': data.phase.name,
        'mood': data.mood,
        'flow': data.flow,
        'energyScore': data.energyScore,
        'symptoms': data.symptoms,
        'note': data.note,
        'partnerName': data.partnerName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('CloudSync.pushCycle note: $e');
    }
  }

  static Future<bool> linkPartner(String code, String name) async {
    final db = _db;
    final id = uid;
    final raw = code.trim().toUpperCase();
    if (db == null || id == null || raw.isEmpty) return false;
    try {
      final inv = await db.collection('invites').doc(raw).get().timeout(const Duration(seconds: 4));
      if (!inv.exists) return false;
      final owner = inv.data()?['ownerUid'] as String?;
      if (owner == null) return false;
      await db.collection('partners').doc(id).set({'partnerUid': owner, 'code': raw}).timeout(const Duration(seconds: 4));
      await PartnerCycleRepository.linkPartner(partnerCode: raw, partnerName: name);
      await pullPartnerCycle();
      return true;
    } catch (e) {
      debugPrint('CloudSync.linkPartner note: $e');
      return false;
    }
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
      await PartnerCycleRepository.savePartnerCycle(current.copyWith(
        isLinked: true,
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
}
