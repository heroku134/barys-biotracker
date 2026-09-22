import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/user_profile.dart';
import 'user_profile_repository.dart';
import 'day_snapshot_repository.dart';
import 'day_journal_repository.dart';

class AccountBackupService {
  static Future<Map<String, dynamic>> bundle() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await UserProfileRepository.loadProfile();
    final snaps = await DaySnapshotRepository.loadAll();
    final journal = await DayJournalRepository.loadAll();
    return {
      'v': 1,
      'profile': profile.toJson(),
      'snapshots': snaps.map((e) => e.toJson()).toList(),
      'journal': journal.map((e) => e.toJson()).toList(),
      'prefs': {
        'kalkan_calibration_days_v1': prefs.getInt('kalkan_calibration_days_v1'),
        'kalkan_cal_mean_hrv_v1': prefs.getDouble('kalkan_cal_mean_hrv_v1'),
        'kalkan_cal_mean_rhr_v1': prefs.getInt('kalkan_cal_mean_rhr_v1'),
        'circa_app_language_code': prefs.getString('circa_app_language_code'),
        'kalkan_climate_mode_v1': prefs.getString('kalkan_climate_mode_v1'),
      },
    };
  }

  static Future<File> writeFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/kalkan_backup.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(await bundle()));
    return file;
  }

  static Future<void> share() async {
    final file = await writeFile();
    await Share.shareXFiles([XFile(file.path)], text: 'KALKAN backup');
  }

  static Future<void> restoreMap(Map<String, dynamic> data) async {
    try {
      if (data['profile'] is Map) {
        final raw = Map<String, dynamic>.from(data['profile'] as Map);
        await UserProfileRepository.saveProfile(UserProfile.fromJson(raw));
      }
    } catch (_) {}
    if (data['snapshots'] is List) {
      await DaySnapshotRepository.importJson(jsonEncode(data['snapshots']));
    }
    final prefs = await SharedPreferences.getInstance();
    final p = data['prefs'];
    if (p is Map) {
      if (p['kalkan_calibration_days_v1'] is int) {
        await prefs.setInt('kalkan_calibration_days_v1', p['kalkan_calibration_days_v1'] as int);
      }
      if (p['kalkan_cal_mean_hrv_v1'] is num) {
        await prefs.setDouble('kalkan_cal_mean_hrv_v1', (p['kalkan_cal_mean_hrv_v1'] as num).toDouble());
      }
      if (p['kalkan_cal_mean_rhr_v1'] is int) {
        await prefs.setInt('kalkan_cal_mean_rhr_v1', p['kalkan_cal_mean_rhr_v1'] as int);
      }
      if (p['circa_app_language_code'] is String) {
        await prefs.setString('circa_app_language_code', p['circa_app_language_code'] as String);
      }
      if (p['kalkan_climate_mode_v1'] is String) {
        await prefs.setString('kalkan_climate_mode_v1', p['kalkan_climate_mode_v1'] as String);
      }
    }
  }

  static Future<void> restoreFromJsonText(String raw) async {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    await restoreMap(data);
  }
}
