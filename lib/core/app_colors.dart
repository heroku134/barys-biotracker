import 'package:flutter/material.dart';

/// Строгая минималистичная палитра CIRCA (Nordic Bio-Minimalism / Whoop 5.0 / Oura)
/// Лимит хроматических цветов — строго 3:
/// 1. sage #7D9A92 — Восстановление (Recovery), успех, готовность
/// 2. amber #C4A574 — Нагрузка (Strain), внимание, фокус, Барыс
/// 3. rose #C45C5C — Пульс, предупреждение, стоп
class AppColors {
  // Базовые фоны и поверхности (мягкий глубокий титан/графит вместо тяжелого черного)
  static const Color stage = Color(0xFF12141A);    // Мягкий глубокий титановый графит
  static const Color bg = Color(0xFF171A23);       // Фоновый оттенок
  static const Color surface = Color(0xFF1E222D);  // Карточки и поверхности
  static const Color raised = Color(0xFF272C39);   // Внутренние плашки, треки

  // Текстовая иерархия
  static const Color fg = Color(0xFFEFF2F7);       // Основной читаемый текст (мягкий ясный контраст)
  static const Color muted = Color(0xFF9299AA);    // Вторичные подписи, единицы
  static const Color faint = Color(0xFF62697A);    // Разделители, неактивные элементы

  // Строгие 1px границы с мягкой прозрачностью
  static const Color line = Color(0x24FFFFFF);      // 14% белого
  static const Color lineStrong = Color(0x3AFFFFFF);// 23% белого

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
