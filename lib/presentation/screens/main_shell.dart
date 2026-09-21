import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/app_typography.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import 'analytics_screen.dart';
import 'bio_avatar_screen.dart';
import 'dashboard_screen.dart';
import 'device_settings_screen.dart';
import 'menstrual_cycle_screen.dart';
import 'profile_screen.dart';
import 'sport_screen.dart';

class MainShell extends StatefulWidget {
  final UteBleBridge bleBridge;

  const MainShell({super.key, required this.bleBridge});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  StreamSubscription<BleTelemetry>? _sub;

  @override
  void initState() {
    super.initState();
    UserProfileRepository.loadProfile();
    _sub = widget.bleBridge.telemetryStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _openDeviceSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeviceSettingsScreen(bleBridge: widget.bleBridge),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository.profileNotifier,
      builder: (context, userProfile, _) {
        final isFemale = userProfile.gender == Gender.female;
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: AppLocaleNotifier.instance,
          builder: (context, language, _) {
            final pages = <Widget>[
              DashboardScreen(
                bleBridge: widget.bleBridge,
                onOpenAvatar: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BioAvatarScreen(bleBridge: widget.bleBridge),
                    ),
                  );
                },
                onOpenDeviceSettings: _openDeviceSettings,
              ),
              AnalyticsScreen(bleBridge: widget.bleBridge),
              SportScreen(bleBridge: widget.bleBridge),
              if (isFemale) MenstrualCycleScreen(bleBridge: widget.bleBridge),
              ProfileScreen(bleBridge: widget.bleBridge),
            ];
            final safeIndex = _currentIndex.clamp(0, pages.length - 1);

            return Scaffold(
              backgroundColor: palette.bg,
              body: IndexedStack(index: safeIndex, children: pages),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.hairline)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 62,
                    child: Row(
                      children: [
                        _nav(palette, 0, Icons.circle_outlined, AppStrings.tr('nav_today', language)),
                        _nav(palette, 1, Icons.insights_outlined, AppStrings.tr('nav_analysis', language)),
                        _nav(palette, 2, Icons.directions_run, AppStrings.tr('nav_sport', language)),
                        if (isFemale)
                          _nav(palette, 3, Icons.water_drop_outlined, AppStrings.tr('nav_cycle', language)),
                        _nav(
                          palette,
                          isFemale ? 4 : 3,
                          Icons.person_outline,
                          AppStrings.tr('nav_profile', language),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _nav(KalkanColors palette, int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    final color = selected ? AppColors.sage : palette.secondary;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.caption(color).copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
