import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final body = AppLocaleNotifier.pick(
      'КАЛКАН показывает сон, восстановление и нагрузку по данным часов. Это не диагноз, не лечение и не замена врачу. Цикл и беременность — дневник и ориентир нагрузки, не медицинский сервис. Решения о тренировках и здоровье принимаете вы.',
      'КАЛКАН сааттын дайындары боюнча уйку, калыбына келүү жана жүктөмдү көрсөтөт. Бул диагноз же дарылоо эмес. Цикл менен кош бойлуулук — күндөлүк, медициналык кызмат эмес.',
      'KALKAN shows sleep, recovery and strain from your watch. It is not a diagnosis, treatment or a substitute for a clinician. Cycle and pregnancy tools are a training diary, not a medical service. You decide how to train.',
    );
    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        title: Text(AppLocaleNotifier.pick('Правила', 'Эрежелер', 'Terms'), style: AppTypography.screenTitle(palette.fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(body, style: AppTypography.body(palette.fg).copyWith(height: 1.45)),
        ],
      ),
    );
  }
}
