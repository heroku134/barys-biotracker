import 'dart:math' as math;

enum HistoryPeriod {
  day24h('24ч'),
  week7d('7 дн'),
  month30d('30 дн'),
  months6('6 мес');

  final String label;
  const HistoryPeriod(this.label);
}

class HistoricalPoint {
  final DateTime timestamp;
  final double value;
  final String label;

  const HistoricalPoint({
    required this.timestamp,
    required this.value,
    required this.label,
  });
}

class BiometricsHistoryRepository {
  /// Получение исторических точек для спарклайна или графика
  static List<HistoricalPoint> getHrvHistory(HistoryPeriod period) {
    final now = DateTime.now();
    final points = <HistoricalPoint>[];
    final random = math.Random(42); // Фиксированный сид для воспроизводимости

    switch (period) {
      case HistoryPeriod.day24h:
        // 24 часа (почасовой тренд ВСР)
        for (var i = 24; i >= 0; i--) {
          final t = now.subtract(Duration(hours: i));
          // Ночью ВСР выше (65-75), днем ниже (45-60)
          final isNight = t.hour >= 23 || t.hour <= 7;
          final baseVal = isNight ? 68.0 : 52.0;
          final val = baseVal + (math.sin(i * 0.4) * 8.0) + (random.nextDouble() * 4.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: double.parse(val.toStringAsFixed(1)),
            label: '${t.hour}:00',
          ));
        }
        break;

      case HistoryPeriod.week7d:
        // 7 дней
        const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
        for (var i = 6; i >= 0; i--) {
          final t = now.subtract(Duration(days: i));
          final val = 62.0 + (math.cos(i * 0.8) * 9.0) + (random.nextDouble() * 3.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: double.parse(val.toStringAsFixed(1)),
            label: days[(t.weekday - 1) % 7],
          ));
        }
        break;

      case HistoryPeriod.month30d:
        // 30 дней
        for (var i = 29; i >= 0; i--) {
          final t = now.subtract(Duration(days: i));
          final val = 64.0 + (math.sin(i * 0.3) * 11.0) + (random.nextDouble() * 4.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: double.parse(val.toStringAsFixed(1)),
            label: '${t.day}.${t.month}',
          ));
        }
        break;

      case HistoryPeriod.months6:
        // 6 месяцев (по неделям, 24 точки)
        for (var i = 23; i >= 0; i--) {
          final t = now.subtract(Duration(days: i * 7));
          // Долгосрочный тренд роста тренированности ВСР (с 54 до 66 мс)
          final trend = (23 - i) * 0.5;
          final val = 54.0 + trend + (math.sin(i * 0.5) * 5.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: double.parse(val.toStringAsFixed(1)),
            label: '${t.day}/${t.month}',
          ));
        }
        break;
    }

    return points;
  }

  /// Получение истории оценок Recovery (0..100)
  static List<HistoricalPoint> getRecoveryHistory(HistoryPeriod period) {
    final now = DateTime.now();
    final points = <HistoricalPoint>[];
    final random = math.Random(108);

    switch (period) {
      case HistoryPeriod.day24h:
      case HistoryPeriod.week7d:
        const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
        for (var i = 6; i >= 0; i--) {
          final t = now.subtract(Duration(days: i));
          final val = (68.0 + (math.sin(i * 1.1) * 18.0) + (random.nextDouble() * 5.0)).clamp(20.0, 96.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: val.round().toDouble(),
            label: days[(t.weekday - 1) % 7],
          ));
        }
        break;

      case HistoryPeriod.month30d:
        for (var i = 29; i >= 0; i--) {
          final t = now.subtract(Duration(days: i));
          final val = (66.0 + (math.cos(i * 0.5) * 20.0) + (random.nextDouble() * 6.0)).clamp(22.0, 98.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: val.round().toDouble(),
            label: '${t.day}.${t.month}',
          ));
        }
        break;

      case HistoryPeriod.months6:
        for (var i = 23; i >= 0; i--) {
          final t = now.subtract(Duration(days: i * 7));
          final val = (64.0 + (math.sin(i * 0.4) * 14.0) + (random.nextDouble() * 6.0)).clamp(30.0, 95.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: val.round().toDouble(),
            label: '${t.day}/${t.month}',
          ));
        }
        break;
    }

    return points;
  }

  /// 24-часовой почасовой профиль пульса
  static List<HistoricalPoint> getHourlyHeartRate24h() {
    final now = DateTime.now();
    final points = <HistoricalPoint>[];
    const vals = [
      52, 50, 49, 48, 51, 58, 72, 84, 76, 74, 92, 118, 142, 138, 98, 82, 75, 71, 68, 62, 56, 53, 51, 52
    ];
    for (var i = 23; i >= 0; i--) {
      final t = now.subtract(Duration(hours: i));
      final val = vals[23 - i].toDouble();
      points.add(HistoricalPoint(timestamp: t, value: val, label: '${t.hour}:00'));
    }
    return points;
  }

  /// Получение тренда пульса по выбранному периоду
  static List<HistoricalPoint> getHeartRateHistory(HistoryPeriod period) {
    final now = DateTime.now();
    final points = <HistoricalPoint>[];
    final random = math.Random(77);

    switch (period) {
      case HistoryPeriod.day24h:
        return getHourlyHeartRate24h();

      case HistoryPeriod.week7d:
        const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
        for (var i = 6; i >= 0; i--) {
          final t = now.subtract(Duration(days: i));
          final val = (54.0 + (math.sin(i * 0.9) * 8.0) + (random.nextDouble() * 4.0)).clamp(48.0, 95.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: double.parse(val.toStringAsFixed(1)),
            label: days[(t.weekday - 1) % 7],
          ));
        }
        break;

      case HistoryPeriod.month30d:
        for (var i = 29; i >= 0; i--) {
          final t = now.subtract(Duration(days: i));
          final val = (53.0 + (math.cos(i * 0.4) * 7.0) + (random.nextDouble() * 3.0)).clamp(47.0, 92.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: double.parse(val.toStringAsFixed(1)),
            label: '${t.day}.${t.month}',
          ));
        }
        break;

      case HistoryPeriod.months6:
        for (var i = 23; i >= 0; i--) {
          final t = now.subtract(Duration(days: i * 7));
          // Тренд снижения пульса покоя благодаря тренировкам (с 58 до 50 уд/мин)
          final trend = (23 - i) * -0.3;
          final val = (58.0 + trend + (math.sin(i * 0.4) * 4.0)).clamp(48.0, 85.0);
          points.add(HistoricalPoint(
            timestamp: t,
            value: double.parse(val.toStringAsFixed(1)),
            label: '${t.day}/${t.month}',
          ));
        }
        break;
    }

    return points;
  }

  static List<HistoricalPoint> getStrainHistory(HistoryPeriod period) {
    final now = DateTime.now();
    final points = <HistoricalPoint>[];
    final random = math.Random(21);
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final count = period == HistoryPeriod.month30d ? 14 : 7;
    for (var i = count - 1; i >= 0; i--) {
      final t = now.subtract(Duration(days: i));
      final val = (9.5 + (math.sin(i * 0.9) * 5.0) + random.nextDouble() * 2).clamp(3.0, 18.5);
      points.add(HistoricalPoint(
        timestamp: t,
        value: double.parse(val.toStringAsFixed(1)),
        label: days[(t.weekday - 1) % 7],
      ));
    }
    return points;
  }

  static List<HistoricalPoint> getSleepHistory(HistoryPeriod period) {
    final now = DateTime.now();
    final points = <HistoricalPoint>[];
    final random = math.Random(88);
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    for (var i = 6; i >= 0; i--) {
      final t = now.subtract(Duration(days: i));
      final val = (78.0 + (math.cos(i * 0.7) * 12.0) + random.nextDouble() * 4).clamp(52.0, 98.0);
      points.add(HistoricalPoint(
        timestamp: t,
        value: val.round().toDouble(),
        label: days[(t.weekday - 1) % 7],
      ));
    }
    return points;
  }
}
