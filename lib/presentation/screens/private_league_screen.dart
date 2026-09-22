import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/private_league_repository.dart';
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
  bool get _ru => AppLocaleNotifier.current != AppLanguage.kyrgyz;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await PrivateLeagueRepository.loadLeague(telemetry: widget.bleBridge.currentTelemetry);
    if (mounted) setState(() { _league = l; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    if (_loading || _league == null) {
      return Scaffold(backgroundColor: palette.bg, body: Center(child: CircularProgressIndicator()));
    }
    final members = _league!.members.take(5).toList();
    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        title: Text(_ru ? 'Друзья' : 'Достор', style: AppTypography.screenTitle(palette.fg)),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share, color: palette.secondary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _league!.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ru ? 'Код скопирован' : 'Код көчүрүлдү')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            _ru ? 'До 5 человек. Только восстановление.' : '5 адамга чейин. Калыбына келүү гана.',
            style: AppTypography.caption(palette.secondary),
          ),
          const SizedBox(height: 12),
          ...members.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: palette.raised,
                        child: Text(m.avatarInitials, style: TextStyle(color: palette.fg, fontSize: 13)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.isCurrentUser ? (_ru ? '${m.name} · вы' : '${m.name} · сиз') : m.name, style: AppTypography.bodySemibold(palette.fg)),
                          Text(m.city, style: AppTypography.caption(palette.secondary)),
                        ]),
                      ),
                      Text('${m.recoveryScore}%', style: TextStyle(color: m.recoveryZone.color, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )),
          if (members.length < 5)
            TextButton(
              onPressed: _add,
              child: Text(_ru ? 'Добавить' : 'Кошуу'),
            ),
        ],
      ),
    );
  }

  void _add() {
    final name = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_ru ? 'Друг' : 'Дос', style: TextStyle(color: AppColors.fg)),
        content: TextField(controller: name, decoration: InputDecoration(hintText: _ru ? 'Имя' : 'Аты')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_ru ? 'Отмена' : 'Жок')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (name.text.trim().isEmpty) return;
              await PrivateLeagueRepository.addFriend(
                name: name.text.trim(),
              );
              await _load();
            },
            child: Text(_ru ? 'Ок' : 'Макул'),
          ),
        ],
      ),
    );
  }
}
