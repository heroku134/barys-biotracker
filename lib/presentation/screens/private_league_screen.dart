import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/private_league_repository.dart';
import '../../data/services/cloud_sync_service.dart';
import '../../domain/models/private_league.dart';
import '../widgets/glass_card.dart';

class PrivateLeagueScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  const PrivateLeagueScreen({super.key, required this.bleBridge});

  @override
  State<PrivateLeagueScreen> createState() => _PrivateLeagueScreenState();
}

class _PrivateLeagueScreenState extends State<PrivateLeagueScreen> {
  PrivateLeague? _league;
  bool _loading = true;
  String? _cloudCode;

  String _t(String ru, String ky, String en) => AppLocaleNotifier.pick(ru, ky, en);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 1. Мгновенно загружаем локальный круг без блокировки UI
    try {
      final l = await PrivateLeagueRepository.loadLeague(telemetry: widget.bleBridge.currentTelemetry);
      if (mounted) {
        setState(() {
          _league = l;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('PrivateLeague load local error: $e');
      if (mounted) setState(() => _loading = false);
    }

    // 2. Фоново обновляем инвайт код через Firestore без блокировки пользователя
    try {
      final cloudCode = await CloudSyncService.publishCycleInvite()
          .timeout(const Duration(seconds: 2), onTimeout: () => _league?.inviteCode ?? 'KALKAN-0000');
      if (mounted && cloudCode.isNotEmpty) {
        setState(() => _cloudCode = cloudCode);
      }
    } catch (e) {
      debugPrint('PrivateLeague cloud invite note: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    if (_loading && _league == null) {
      return Scaffold(
        backgroundColor: palette.bg,
        appBar: AppBar(
          backgroundColor: palette.bg,
          elevation: 0,
          title: Text(_t('Круг друзей', 'Достор', 'Circle of friends'), style: AppTypography.screenTitle(palette.fg)),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.sage),
        ),
      );
    }

    final league = _league ?? const PrivateLeague(
      id: 'fallback',
      title: 'Круг доверия',
      inviteCode: 'KALKAN-0000',
      members: [],
    );
    final members = league.members.take(5).toList();
    final inviteCode = _cloudCode ?? league.inviteCode;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        elevation: 0,
        title: Text(_t('Круг друзей', 'Достор', 'Circle of friends'), style: AppTypography.screenTitle(palette.fg)),
        actions: [
          IconButton(
            tooltip: _t('Скопировать код', 'Кодду көчүрүү', 'Copy code'),
            icon: Icon(Icons.share_outlined, color: palette.secondary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              CircaHaptics.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: palette.surface,
                  content: Text(
                    _t('Код круга скопирован: $inviteCode', 'Код көчүрүлдү: $inviteCode', 'Circle code copied: $inviteCode'),
                    style: TextStyle(color: palette.fg),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Карточка инвайт-кода
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _t('ПРИВАТНАЯ ЛИГА (ДАНБАР 3-5)', 'ЖЕКЕ ЛИГА', 'PRIVATE LEAGUE (DUNBAR 3-5)'),
                      style: TextStyle(
                        color: palette.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${members.length} / 5',
                        style: TextStyle(color: AppColors.sage, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    'Делитесь физиологической готовностью только с близким кругом. Код для подключения:',
                    'Жакын досторуңуз менен гана бөлүшүңүз. Кошулуу коду:',
                    'Share physiological readiness only with your inner circle. Invite code:',
                  ),
                  style: AppTypography.caption(palette.secondary),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    CircaHaptics.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: palette.surface,
                        content: Text(_t('Код скопирован в буфер', 'Код көчүрүлдү', 'Code copied to clipboard'), style: TextStyle(color: palette.fg)),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.raised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          inviteCode,
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Icon(Icons.copy, size: 16, color: palette.secondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _t('Участники круга', 'Катышуучулар', 'Circle members'),
            style: AppTypography.bodySemibold(palette.fg),
          ),
          const SizedBox(height: 10),

          ...members.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: m.isCurrentUser ? AppColors.sage.withValues(alpha: 0.2) : palette.raised,
                        child: Text(
                          m.avatarInitials,
                          style: TextStyle(
                            color: m.isCurrentUser ? AppColors.sage : palette.fg,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    m.isCurrentUser ? _t('${m.name} (Вы)', '${m.name} (Сиз)', '${m.name} (You)') : m.name,
                                    style: AppTypography.bodySemibold(palette.fg),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (m.isCurrentUser) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.sage.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'LIVE',
                                      style: TextStyle(color: AppColors.sage, fontSize: 9, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _t(
                                'Готовность: ${m.recoveryScore}% · HRV ${m.hrv.toStringAsFixed(0)} · сон ${m.sleepHours.toStringAsFixed(1)} ч',
                                'Даярдык: ${m.recoveryScore}% · HRV ${m.hrv.toStringAsFixed(0)} · уйку ${m.sleepHours.toStringAsFixed(1)} с',
                                'Readiness: ${m.recoveryScore}% · HRV ${m.hrv.toStringAsFixed(0)} · sleep ${m.sleepHours.toStringAsFixed(1)} h',
                              ),
                              style: AppTypography.caption(palette.secondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${m.recoveryScore}%',
                            style: TextStyle(
                              color: m.recoveryZone.color,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            m.recoveryZone.name.toUpperCase(),
                            style: TextStyle(
                              color: m.recoveryZone.color.withValues(alpha: 0.8),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      if (!m.isCurrentUser) ...[
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 18, color: palette.muted),
                          color: palette.surface,
                          onSelected: (val) async {
                            if (val == 'remove') {
                              await PrivateLeagueRepository.removeFriend(m.id);
                              await _load();
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(
                                _t('Удалить из круга', 'Кругдан чыгаруу', 'Remove from circle'),
                                style: const TextStyle(color: AppColors.rose, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              )),

          if (members.length < 5) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text(_t('Добавить друга по коду', 'Код менен дос кошуу', 'Add friend by code')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.fg,
                  side: BorderSide(color: palette.hairline),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _add() {
    final code = TextEditingController();
    final palette = KalkanColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _t('Добавить друга', 'Дос кошуу', 'Add friend'),
          style: TextStyle(color: palette.fg, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                'Введите код приглашения друга (например, KALKAN-4821):',
                'Досуңуздун кодун жазыңыз (мисалы, KALKAN-4821):',
                "Enter friend's invite code (e.g. KALKAN-4821):",
              ),
              style: TextStyle(color: palette.secondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: palette.fg, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.raised,
                hintText: 'KALKAN-XXXX',
                hintStyle: TextStyle(color: palette.muted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: palette.hairline)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: palette.hairline)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.sage)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Отмена', 'Жок', 'Cancel'), style: TextStyle(color: palette.secondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final raw = code.text.trim().toUpperCase();
              Navigator.pop(ctx);
              if (raw.isEmpty) return;
              setState(() => _loading = true);
              final ok = await CloudSyncService.acceptFriendCode(raw);
              if (!ok) {
                // Локальное добавление друга
                await PrivateLeagueRepository.addFriend(name: 'Атлет $raw', inviteCode: raw);
              }
              await _load();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sage,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(_t('Добавить', 'Кошуу', 'Add')),
          ),
        ],
      ),
    );
  }
}
