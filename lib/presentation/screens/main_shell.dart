import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../data/ble/ute_ble_bridge.dart';
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

  void _openAvatarScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BioAvatarScreen(bleBridge: widget.bleBridge),
      ),
    );
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
    return Scaffold(
      backgroundColor: AppColors.stage,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            bleBridge: widget.bleBridge,
            onOpenAvatar: _openAvatarScreen,
            onOpenDeviceSettings: _openDeviceSettings,
          ),
          AnalyticsScreen(bleBridge: widget.bleBridge),
          SportScreen(bleBridge: widget.bleBridge),
          ProfileScreen(bleBridge: widget.bleBridge),
        ],
      ),

      // Чистая 4-сегментная плоская навигация CIRCA (без нависающего FAB)
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
            height: 54,
            child: Row(
              children: [
                _buildNavItem(0, Icons.radio_button_checked, 'Сегодня'),
                _buildNavItem(1, Icons.insights_outlined, 'Анализ'),
                _buildNavItem(2, Icons.directions_run_outlined, 'Спорт'),
                _buildNavItem(3, Icons.person_outline, 'Профиль'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.amber : AppColors.muted;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
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
}
