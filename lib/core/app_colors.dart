import 'package:flutter/material.dart';

/// Строгая минималистичная палитра CIRCA (Nordic Bio-Minimalism / Whoop 5.0 / Oura)
/// Лимит хроматических цветов — строго 3:
/// 1. sage #7D9A92 — Восстановление (Recovery), успех, готовность
/// 2. amber #C4A574 — Нагрузка (Strain), внимание, фокус, Барыс
/// 3. rose #C45C5C — Пульс, предупреждение, стоп
class AppColors {
  // Базовые фоны и поверхности (90% площади экрана)
  static const Color stage = Color(0xFF050506);    // Глубокий монохромный стейдж
  static const Color bg = Color(0xFF08090B);       // Фоновый оттенок
  static const Color surface = Color(0xFF111217);  // Карточки и поверхности
  static const Color raised = Color(0xFF181A21);   // Внутренние плашки, треки

  // Текстовая иерархия
  static const Color fg = Color(0xFFE2E6EC);       // Основной читаемый текст
  static const Color muted = Color(0xFF7E8494);    // Вторичные подписи, единицы
  static const Color faint = Color(0xFF555865);    // Разделители, неактивные элементы

  // Строгие 1px hairline границы (без теней и псевдо-блюра)
  static const Color line = Color(0x1DF2F3F5);      // 12% белого
  static const Color lineStrong = Color(0x38F2F3F5);// 22% белого

  // 3 фирменных хроматических акцента
  static const Color sage = Color(0xFF7D9A92);  // Благородный матовый шалфей
  static const Color amber = Color(0xFFC4A574); // Теплый нордический янтарь
  static const Color rose = Color(0xFFC45C5C);  // Рубиновый терракот пульса

  // Совместимые алиасы (перенаправлены на 3-цветную палитру)
  static const Color cyan = sage;               // Устранение циана в пользу шалфея
  static const Color accent = fg;
  static const Color bgDark = stage;
  static const Color surfaceCard = surface;
  static const Color borderGlass = line;
  static const Color textPrimary = fg;
  static const Color textSecondary = muted;
  static const Color textMuted = faint;
  static const Color emerald = sage;
  static const Color gold = amber;
  static const Color pulseRed = rose;

  // Однотонные зоны восстановления (без радужных градиентов)
  static const Color zoneOptimal = sage;
  static const Color zoneModerate = amber;
  static const Color zoneLow = rose;
}
