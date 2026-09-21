import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/private_league_repository.dart';
import '../../domain/models/private_league.dart';
import '../../domain/models/readiness.dart';
import '../widgets/circa_friend_detail_sheet.dart';
import '../widgets/glass_card.dart';

class PrivateLeagueScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const PrivateLeagueScreen({super.key, required this.bleBridge});

  @override
  State<PrivateLeagueScreen> createState() => _PrivateLeagueScreenState();
}

class _PrivateLeagueScreenState extends State<PrivateLeagueScreen> {
  PrivateLeague? _league;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeague();
  }

  Future<void> _loadLeague() async {
    final l = await PrivateLeagueRepository.loadLeague(
      telemetry: widget.bleBridge.currentTelemetry,
    );
    if (mounted) {
      setState(() {
        _league = l;
        _isLoading = false;
      });
    }
  }

  void _copyInviteCode() {
    CircaHaptics.ringZoneTick();
    if (_league != null) {
      Clipboard.setData(ClipboardData(text: _league!.inviteCode));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.amber),
          ),
          content: Text(
            'Инвайт-код ${_league!.inviteCode} скопирован в буфер',
            style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddFriendDialog() {
    if (_league == null || _league!.isFull) return;

    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.stage,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.line, width: 1.0)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              SizedBox(height: 16),
              const Text(
                'ПРИГЛАШЕНИЕ В КРУГ ДОВЕРИЯ',
                style: TextStyle(
                  color: AppColors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              SizedBox(height: 4),
              const Text(
                'Добавление друга (до 5 участников)',
                style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 14),

              TextField(
                controller: nameController,
                style: TextStyle(color: AppColors.fg, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Имя друга или позывной',
                  labelStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.amber)),
                ),
              ),
              SizedBox(height: 10),

              TextField(
                controller: codeController,
                style: TextStyle(color: AppColors.fg, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Инвайт-код (опционально, напр. BATYR-05)',
                  labelStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.amber)),
                ),
              ),
              SizedBox(height: 14),

              const Text(
                'Быстрый выбор из контактов KALKAN:',
                style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  'Арман Т.',
                  'Асель Ж.',
                  'Марат Б.',
                ].map((suggested) => ActionChip(
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: AppColors.line),
                  label: Text(suggested, style: TextStyle(color: AppColors.fg, fontSize: 11)),
                  onPressed: () => nameController.text = suggested,
                )).toList(),
              ),
              SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.stage,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      Navigator.pop(ctx);
                      final success = await PrivateLeagueRepository.addFriend(
                        name: name,
                        inviteCode: codeController.text.trim(),
                      );
                      if (success) {
                        _loadLeague();
                      }
                    }
                  },
                  child: const Text(
                    'ДОБАВИТЬ В ЗАКРЫТЫЙ КРУГ',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _league == null) {
      return const Scaffold(
        backgroundColor: AppColors.stage,
        body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      );
    }

    final league = _league!;
    final memberCount = league.members.length;
    final maxCount = league.maxMembers;
    final avgScore = league.averageRecoveryScore.round();

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.stage,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: AppColors.muted, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              children: [
                Text(
                  AppStrings.tr('league_appbar_sub', language),
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  AppStrings.tr('league_appbar_title', language),
                  style: TextStyle(
                    color: AppColors.fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: AppColors.muted, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Философия узкого круга', style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700)),
                  content: const Text(
                    'Вместо токсичных глобальных таблиц лидеров КАЛКАН использует закрытые круги на 3–5 человек. Вы соревнуетесь только с собой, получая искреннюю поддержку близких.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ПОНЯТНО', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // League Header Card
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppColors.amber, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                league.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.fg,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$memberCount / $maxCount МЕСТ',
                          style: const TextStyle(
                            color: AppColors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'СРЕДНЕЕ ВОССТАНОВЛЕНИЕ КРУГА',
                            style: TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '$avgScore%',
                                style: const TextStyle(color: AppColors.sage, fontSize: 24, fontWeight: FontWeight.w800),
                              ),
                              SizedBox(width: 8),
                              const Text('· Зеленый коридор', style: TextStyle(color: AppColors.sage, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      // 5 сегментных полос заполнения
                      Row(
                        children: List.generate(maxCount, (idx) {
                          final isFilled = idx < memberCount;
                          return Container(
                            margin: const EdgeInsets.only(left: 4),
                            width: 8,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isFilled ? AppColors.amber : AppColors.line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Container(height: 1, color: AppColors.line),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('ИНВАЙТ-КОД: ', style: TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          Text(league.inviteCode, style: const TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                        ],
                      ),
                      GestureDetector(
                        onTap: _copyInviteCode,
                        child: Row(
                          children: const [
                            Icon(Icons.copy, size: 12, color: AppColors.faint),
                            SizedBox(width: 4),
                            Text('Скопировать', style: TextStyle(color: AppColors.faint, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 18),

            // Members Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'УЧАСТНИКИ КРУГА ДОВЕРИЯ',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  '${league.availableSlots} свободных слота',
                  style: TextStyle(color: AppColors.faint, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            SizedBox(height: 10),

            // Members List
            ...league.members.map((member) {
              final zoneColor = member.recoveryZone == RecoveryZone.optimal
                  ? AppColors.sage
                  : (member.recoveryZone == RecoveryZone.moderate ? AppColors.amber : AppColors.rose);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => CircaFriendDetailSheet.show(
                      context,
                      member,
                      onImpulseSent: _loadLeague,
                    ),
                    child: Row(
                      children: [
                        // Avatar Circle
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            border: Border.all(color: zoneColor, width: 2.0),
                          ),
                          child: Center(
                            child: Text(
                              member.avatarInitials,
                              style: TextStyle(color: zoneColor, fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),

                        // Center Info
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
                                        fontSize: 14,
                                        fontWeight: member.isCurrentUser ? FontWeight.w800 : FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.raised,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      member.rankTitle,
                                      style: const TextStyle(color: AppColors.amber, fontSize: 8.5, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 3),
                              Text(
                                member.statusQuote,
                                style: TextStyle(color: AppColors.muted, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),

                        // Right Metrics
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: zoneColor),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${member.recoveryScore}%',
                                  style: TextStyle(color: zoneColor, fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${member.currentDayStrain.toStringAsFixed(1)} Str',
                              style: const TextStyle(color: AppColors.amber, fontSize: 10.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.faint),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // Add Friend / Full Circle status
            SizedBox(height: 4),
            if (!league.isFull)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: const BorderSide(color: AppColors.amber, width: 1.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: Text(
                    'ДОБАВИТЬ ДРУГА (${league.availableSlots} СВОБОДНО)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  onPressed: _showAddFriendDialog,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: AppColors.amber),
                    SizedBox(width: 8),
                    Text(
                      'КРУГ ДОВЕРИЯ ЗАПОЛНЕН (5/5) · ДОВЕРИТЕЛЬНАЯ ЛИГА',
                      style: TextStyle(color: AppColors.amber, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24),

            // Quiet Luxury Note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.fingerprint, color: AppColors.muted, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Приватные круги КАЛКАН защищены правилом Данбара: малый круг близких людей исключает токсичное социальное сравнение и сохраняет психологический комфорт.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
      },
    );
  }
}
