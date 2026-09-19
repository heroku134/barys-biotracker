import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import '../widgets/circa_film_grain.dart';
import 'analytics_screen.dart';
import 'bio_avatar_screen.dart';
import 'dashboard_screen.dart';
import 'device_settings_screen.dart';
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
  late BleTelemetry _telemetry;
  final PersonalBaseline _baseline = const PersonalBaseline();

  @override
  void initState() {
    super.initState();
    _telemetry = widget.bleBridge.currentTelemetry;
    widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) {
        setState(() => _telemetry = data);
      }
    });
  }

  void _openAvatarScreen() {
    HapticFeedback.mediumImpact();
    setState(() => _currentIndex = 2);
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
    final readiness = ReadinessEngine.calculate(_telemetry, baseline: _baseline);
    final avatarProfile = AvatarManager.getProfile(_telemetry, baseline: _baseline);

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.stage,
          body: CircaFilmGrainBackground(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                DashboardScreen(
                  bleBridge: widget.bleBridge,
                  onOpenAvatar: _openAvatarScreen,
                  onOpenDeviceSettings: _openDeviceSettings,
                ),
                AnalyticsScreen(bleBridge: widget.bleBridge),
                BioAvatarScreen(bleBridge: widget.bleBridge),
                SportScreen(bleBridge: widget.bleBridge),
                ProfileScreen(bleBridge: widget.bleBridge),
              ],
            ),
          ),

          // Премиальная 5-сегментная навигационная панель с ЦЕНТРАЛЬНОЙ КНОПКОЙ-МАСКОТОМ
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.line, width: 1.0),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: [
                    _buildNavItem(0, Icons.radio_button_checked, AppStrings.tr('nav_today', language)),
                    _buildNavItem(1, Icons.insights_outlined, AppStrings.tr('nav_analysis', language)),
                    _buildCentralBarysButton(readiness.zone.color, avatarProfile.state.assetPath),
                    _buildNavItem(3, Icons.directions_run_outlined, AppStrings.tr('nav_sport', language)),
                    _buildNavItem(4, Icons.person_outline, AppStrings.tr('nav_profile', language)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.amber : AppColors.muted;

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
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Акцентная центральная кнопка персонажа Барыс-Батыра
  Widget _buildCentralBarysButton(Color statusColor, String assetPath) {
    final isSelected = _currentIndex == 2;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          setState(() => _currentIndex = 2);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isSelected ? 44 : 40,
              height: isSelected ? 44 : 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.amber : statusColor,
                  width: isSelected ? 2.5 : 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? AppColors.amber : statusColor).withValues(alpha: isSelected ? 0.5 : 0.25),
                    blurRadius: isSelected ? 12 : 6,
                    spreadRadius: isSelected ? 1.5 : 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.pets,
                    color: AppColors.amber,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'БАРЫС',
              style: TextStyle(
                color: isSelected ? AppColors.amber : AppColors.fg,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
