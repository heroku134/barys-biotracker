import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/circa_haptics.dart';
import '../../domain/models/private_league.dart';
import '../../domain/models/readiness.dart';
import 'glass_card.dart';

class CircaFriendDetailSheet extends StatelessWidget {
  final FriendMember member;
  final VoidCallback? onImpulseSent;

  const CircaFriendDetailSheet({
    super.key,
    required this.member,
    this.onImpulseSent,
  });

  static void show(BuildContext context, FriendMember member, {VoidCallback? onImpulseSent}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CircaFriendDetailSheet(
        member: member,
        onImpulseSent: onImpulseSent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = member.recoveryZone == RecoveryZone.optimal
        ? AppColors.sage
        : (member.recoveryZone == RecoveryZone.moderate ? AppColors.amber : AppColors.rose);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.stage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.line, width: 1.0)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: zoneColor, width: 2.0),
                ),
                child: Center(
                  child: Text(
                    member.avatarInitials,
                    style: TextStyle(
                      color: zoneColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            style: const TextStyle(
                              color: AppColors.fg,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${member.rankTitle} · LVL ${member.level}',
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${member.city} · Синхронизация: ${member.lastSyncText}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Quote
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              member.statusQuote,
              style: const TextStyle(
                color: AppColors.fg,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recovery Card Hero
          GlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ВОССТАНОВЛЕНИЕ (RECOVERY)',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${member.recoveryScore}%',
                          style: TextStyle(
                            color: zoneColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          member.recoveryZone == RecoveryZone.optimal
                              ? 'Зеленый коридор'
                              : (member.recoveryZone == RecoveryZone.moderate ? 'Адаптивный коридор' : 'Зона отдыха'),
                          style: TextStyle(
                            color: zoneColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: zoneColor.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Icon(Icons.favorite, color: zoneColor, size: 22),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4 Grid metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'НАГРУЗКА ДНЯ',
                  value: '${member.currentDayStrain.toStringAsFixed(1)} / 21',
                  sub: 'Суточный Strain',
                  icon: Icons.bolt,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'СОН И КАЧЕСТВО',
                  value: '${member.sleepHours.toStringAsFixed(1)}ч',
                  sub: '${member.sleepPerformance}% эффективности',
                  icon: Icons.bedtime_outlined,
                  color: AppColors.sage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'ВСР (HRV)',
                  value: '${member.hrv.round()} мс',
                  sub: 'Баланс вегетатики',
                  icon: Icons.graphic_eq,
                  color: AppColors.sage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'ЧСС ПОКОЯ',
                  value: '${member.restingHeartRate} bpm',
                  sub: 'База миокарда',
                  icon: Icons.monitor_heart_outlined,
                  color: AppColors.rose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Button: Send Impulse
          if (!member.isCurrentUser)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.stage,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  CircaHaptics.questCompleted();
                  onImpulseSent?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.surface,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.amber),
                      ),
                      content: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.amber, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Импульс силы Барыса успешно отправлен ${member.name}!',
                              style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'ОТПРАВИТЬ ИМПУЛЬС СИЛЫ БАРЫСА ✦',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.fg,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(color: AppColors.faint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
