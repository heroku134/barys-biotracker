import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/storage/private_league_repository.dart';
import '../../domain/models/private_league.dart';
import '../../domain/models/readiness.dart';
import 'glass_card.dart';

class CircaFriendDetailSheet extends StatelessWidget {
  final FriendMember member;
  final VoidCallback? onImpulseSent;
  final VoidCallback? onFriendRemoved;

  const CircaFriendDetailSheet({
    super.key,
    required this.member,
    this.onImpulseSent,
    this.onFriendRemoved,
  });

  static void show(BuildContext context, FriendMember member, {VoidCallback? onImpulseSent, VoidCallback? onFriendRemoved}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CircaFriendDetailSheet(
        member: member,
        onImpulseSent: onImpulseSent,
        onFriendRemoved: onFriendRemoved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = member.recoveryZone == RecoveryZone.optimal
        ? AppColors.sage
        : (member.recoveryZone == RecoveryZone.moderate ? AppColors.amber : AppColors.rose);

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
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
          SizedBox(height: 18),

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
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            style: TextStyle(
                              color: AppColors.fg,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${member.rankTitle} · LVL ${member.level}',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${member.city} · Синхронизация: ${member.lastSyncText}',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

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
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(height: 16),

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
                    Text(
                      AppStrings.tr('friend_detail_recovery', language),
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 6),
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
                        SizedBox(width: 8),
                        Text(
                          member.recoveryZone == RecoveryZone.optimal
                              ? AppLocaleNotifier.pick('Зеленый коридор', 'Жашыл коридор', 'Optimal corridor')
                              : (member.recoveryZone == RecoveryZone.moderate
                                  ? AppLocaleNotifier.pick('Адаптивный коридор', 'Адаптивдүү коридор', 'Adaptive corridor')
                                  : AppLocaleNotifier.pick('Зона отдыха', 'Эс алуу зонасы', 'Rest zone')),
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
          SizedBox(height: 12),

          // 4 Grid metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: AppStrings.tr('friend_detail_strain', language),
                  value: '${member.currentDayStrain.toStringAsFixed(1)} / 21',
                  sub: AppLocaleNotifier.pick('Суточный Strain', 'Күндүк Strain', 'Daily Strain'),
                  icon: Icons.bolt,
                  color: AppColors.amber,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: AppStrings.tr('friend_detail_sleep', language),
                  value: '${member.sleepHours.toStringAsFixed(1)}h',
                  sub: '${member.sleepPerformance}% ${AppLocaleNotifier.pick('эффективности', 'натыйжалуулук', 'performance')}',
                  icon: Icons.bedtime_outlined,
                  color: AppColors.sage,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: AppStrings.tr('friend_detail_hrv', language),
                  value: '${member.hrv.round()} ms',
                  sub: AppLocaleNotifier.pick('Баланс вегетатики', 'Вегетативдик тең салмак', 'Autonomic balance'),
                  icon: Icons.graphic_eq,
                  color: AppColors.sage,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: AppStrings.tr('friend_detail_rhr', language),
                  value: '${member.restingHeartRate} bpm',
                  sub: AppLocaleNotifier.pick('База миокарда', 'Миокард базасы', 'Resting baseline'),
                  icon: Icons.monitor_heart_outlined,
                  color: AppColors.rose,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

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
                          Icon(Icons.auto_awesome, color: AppColors.amber, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Импульс силы Барыса успешно отправлен ${member.name}!',
                              style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 16),
                    SizedBox(width: 8),
                    Text(
                      AppStrings.tr('league_send_impulse', language),
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
            if (!member.isCurrentUser) ...[
              SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    CircaHaptics.selectionClick();
                    await PrivateLeagueRepository.removeFriend(member.id);
                    onFriendRemoved?.call();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text(
                            '${member.name} удален(а) из закрытого круга.',
                            style: TextStyle(color: AppColors.rose, fontSize: 12),
                          ),
                        ),
                      );
                    }
                  },
                  icon: Icon(Icons.person_remove_outlined, color: AppColors.rose, size: 16),
                  label: Text(
                    'УДАЛИТЬ ИЗ КРУГА',
                    style: TextStyle(color: AppColors.rose, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
      },
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
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppColors.fg,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(color: AppColors.faint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
