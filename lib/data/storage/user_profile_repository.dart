import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/user_profile.dart';
import '../ble/ute_ble_bridge.dart';
import '../services/cloud_sync_service.dart';

class UserProfileRepository {
  static const String _keyProfile = 'kalkan_user_profile_v1';
  static const String _legacyKeyProfile = 'circa_user_profile_v1';
  static const String _keyAuth = 'kalkan_user_authenticated_v1';
  static const String _legacyKeyAuth = 'circa_user_authenticated_v1';

  static final ValueNotifier<UserProfile> profileNotifier =
      ValueNotifier<UserProfile>(const UserProfile());

  static Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyProfile) ?? prefs.getString(_legacyKeyProfile);
    UserProfile profile = const UserProfile();
    if (jsonStr != null) {
      try {
        profile = UserProfile.deserialize(jsonStr);
      } catch (_) {}
    } else {
      final isAuth = prefs.getBool(_keyAuth) ?? prefs.getBool(_legacyKeyAuth) ?? false;
      profile = UserProfile(isAuthenticated: isAuth);
    }
    profileNotifier.value = profile;
    return profile;
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, profile.serialize());
    await prefs.setBool(_keyAuth, profile.isAuthenticated);
    profileNotifier.value = profile;
    CloudSyncService.pushProfile(profile);
    if (UteBleBridge.instance.isConnected) {
      unawaited(UteBleBridge.instance.syncUserProfile(profile));
    }
  }

  static Future<void> setAuthenticated(bool isAuth) async {
    final profile = await loadProfile();
    await saveProfile(profile.copyWith(isAuthenticated: isAuth));
  }
}
