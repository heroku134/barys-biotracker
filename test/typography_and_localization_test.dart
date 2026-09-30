import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barys_biotracker/core/app_language.dart';
import 'package:barys_biotracker/core/app_typography.dart';
import 'package:barys_biotracker/domain/models/readiness.dart';

void main() {
  group('Typography Scale & Localization Tests', () {
    test('1. AppTypography frozen scale strictly conforms to design tokens', () {
      // heroNumber: 54 sans, -1.6 tracking
      expect(AppTypography.heroNumber.fontSize, equals(54.0));
      expect(AppTypography.heroNumber.fontFamily, equals('Manrope'));
      expect(AppTypography.heroNumber.letterSpacing, equals(-1.6));
      expect(AppTypography.heroNumber.fontWeight, equals(FontWeight.w600));

      // metricLarge: 32 sans, -0.8 tracking
      expect(AppTypography.metricLarge.fontSize, equals(32.0));
      expect(AppTypography.metricLarge.letterSpacing, equals(-0.8));

      // metricMedium (named exception): 24 sans
      expect(AppTypography.metricMedium.fontSize, equals(24.0));

      // metric / metricValue: 16 sans, -0.3 tracking
      expect(AppTypography.metric.fontSize, equals(16.0));
      expect(AppTypography.metricValue.fontSize, equals(16.0));

      // screenTitle: 18 sans, -0.3 tracking, w600
      expect(AppTypography.screenTitle.fontSize, equals(18.0));
      expect(AppTypography.screenTitle.fontWeight, equals(FontWeight.w600));

      // body & bodySemibold: 14 sans
      expect(AppTypography.body.fontSize, equals(14.0));
      expect(AppTypography.body.fontWeight, equals(FontWeight.w400));
      expect(AppTypography.bodySemibold.fontSize, equals(14.0));
      expect(AppTypography.bodySemibold.fontWeight, equals(FontWeight.w600));

      // bodyMuted: 12.5 sans
      expect(AppTypography.bodyMuted.fontSize, equals(12.5));

      // caption: 11 sans
      expect(AppTypography.caption.fontSize, equals(11.0));
      expect(AppTypography.caption.fontFamily, equals('Manrope'));

      // monoLabel / overline: 11 mono +1.4
      expect(AppTypography.monoLabel.fontSize, equals(11.0));
      expect(AppTypography.monoLabel.fontFamily, equals('IBM Plex Mono'));
      expect(AppTypography.monoLabel.letterSpacing, equals(1.4));
      expect(AppTypography.overline.fontSize, equals(11.0));

      // monoUnit: 10 mono +1.1
      expect(AppTypography.monoUnit.fontSize, equals(10.0));
      expect(AppTypography.monoUnit.letterSpacing, equals(1.1));

      // monoBadge (named exception): 9.5 mono +1.3
      expect(AppTypography.monoBadge.fontSize, equals(9.5));
      expect(AppTypography.monoBadge.letterSpacing, equals(1.3));
    });

    test('2. AppTextStyle colorKind resolves with semantic primary/secondary/muted', () {
      expect(AppTypographyColor.primary, equals(AppTypographyColor.nearWhite));

      const primaryStyle = AppTextStyle(colorKind: AppTypographyColor.primary);
      expect(primaryStyle.color, isNotNull);

      const secondaryStyle = AppTextStyle(colorKind: AppTypographyColor.secondary);
      expect(secondaryStyle.color, isNotNull);

      const mutedStyle = AppTextStyle(colorKind: AppTypographyColor.muted);
      expect(mutedStyle.color, isNotNull);

      const noneStyle = AppTextStyle(colorKind: AppTypographyColor.none);
      expect(noneStyle.color, isNull);
    });

    test('3. RecoveryZone provides reactive localization across Russian, Kyrgyz, and English', () {
      // RU
      AppLocaleNotifier.instance.value = AppLanguage.russian;
      expect(RecoveryZone.optimal.localizedLabel, equals('Оптимально'));
      expect(RecoveryZone.optimal.localizedBadge, equals('Готово'));
      expect(RecoveryZone.moderate.localizedLabel, equals('Умеренно'));
      expect(RecoveryZone.recovery.localizedLabel, equals('Восстановление'));

      // KY
      AppLocaleNotifier.instance.value = AppLanguage.kyrgyz;
      expect(RecoveryZone.optimal.localizedLabel, equals('Оптималдуу'));
      expect(RecoveryZone.optimal.localizedBadge, equals('Даяр'));
      expect(RecoveryZone.moderate.localizedLabel, equals('Орточо'));
      expect(RecoveryZone.recovery.localizedLabel, equals('Калыбына келүү'));

      // EN
      AppLocaleNotifier.instance.value = AppLanguage.english;
      expect(RecoveryZone.optimal.localizedLabel, equals('Optimal'));
      expect(RecoveryZone.optimal.localizedBadge, equals('Ready'));
      expect(RecoveryZone.moderate.localizedLabel, equals('Moderate'));
      expect(RecoveryZone.recovery.localizedLabel, equals('Recovery'));

      // Direct language parameter
      expect(RecoveryZone.optimal.localizedName(AppLanguage.english), equals('Optimal'));
      expect(RecoveryZone.optimal.localizedName(AppLanguage.kyrgyz), equals('Оптималдуу'));
      expect(RecoveryZone.optimal.localizedName(AppLanguage.russian), equals('Оптимально'));

      // Reset
      AppLocaleNotifier.instance.value = AppLanguage.russian;
    });
  });
}
