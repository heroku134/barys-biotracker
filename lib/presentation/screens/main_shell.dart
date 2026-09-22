import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/app_typography.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/services/background_ble_sync_service.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import 'analytics_screen.dart';
import 'bio_avatar_screen.dart';
import 'dashboard_screen.dart';
import 'device_settings_screen.dart';
import 'menstrual_cycle_screen.dart';
import 'pregnancy_screen.dart';
import 'profile_screen.dart';
import 'sport_screen.dart';

class MainShell extends StatefulWidget {
  final UteBleBridge bleBridge;

  const MainShell({super.key, required this.bleBridge});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late BleTelemetry _telemetry;
  final PersonalBaseline _baseline = const PersonalBaseline();
  StreamSubscription<BleTelemetry>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    UserProfileRepository.loadProfile();
    _telemetry = widget.bleBridge.currentTelemetry;
    _sub = widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) setState(() => _telemetry = data);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      BackgroundBleSyncService.performSync(widget.bleBridge);
    }
    if (state == AppLifecycleState.paused) {
      BackgroundBleSyncService.requestNativeRefresh();
    }
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
    final avatar = AvatarManager.getProfile(_telemetry, baseline: _baseline);
    final zone = ReadinessEngine.calculate(_telemetry, baseline: _baseline).zone;

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
                  if (isFemale) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BioAvatarScreen(bleBridge: widget.bleBridge),
                    ));
                  } else {
                    setState(() => _currentIndex = 2);
                  }
                },
                onOpenDeviceSettings: _openDeviceSettings,
              ),
              AnalyticsScreen(bleBridge: widget.bleBridge),
              if (isFemale)
                userProfile.isPregnant
                    ? PregnancyScreen(bleBridge: widget.bleBridge)
                    : MenstrualCycleScreen(bleBridge: widget.bleBridge)
              else
                BioAvatarScreen(bleBridge: widget.bleBridge, embedded: true),
              SportScreen(bleBridge: widget.bleBridge),
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
                    height: 64,
                    child: Row(
                      children: [
                        _nav(palette, 0, Icons.circle_outlined, AppStrings.tr('nav_today', language)),
                        _nav(palette, 1, Icons.insights_outlined, AppStrings.tr('nav_analysis', language)),
                        if (isFemale)
                          _nav(palette, 2, userProfile.isPregnant ? Icons.favorite_outline : Icons.water_drop_outlined, AppStrings.tr(userProfile.isPregnant ? 'nav_pregnancy' : 'nav_cycle', language))
                        else
                          _mascotNav(palette, zone.color, avatar.state.assetFor(userProfile.gender), 2, AppStrings.tr('nav_barys', language)),
                        _nav(palette, 3, Icons.directions_run, AppStrings.tr('nav_sport', language)),
                        _nav(palette, 4, Icons.person_outline, AppStrings.tr('nav_profile', language)),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(color).copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mascotNav(KalkanColors palette, Color ring, String asset, int index, String label) {
    final selected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.sage : ring, width: 1.4),
              ),
              child: ClipOval(
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Icon(Icons.pets, color: AppColors.sage, size: 16),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(selected ? AppColors.sage : palette.secondary).copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
