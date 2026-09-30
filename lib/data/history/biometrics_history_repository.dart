import '../storage/day_snapshot_repository.dart';

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

/// Репозиторий исторических биометрических данных
/// Исключительно достоверные данные из реальных замеров DaySnapshot (без генераторов случайных чисел)
class BiometricsHistoryRepository {
  static List<HistoricalPoint> _buildFromSnapshots(
    List<DaySnapshot> snapshots,
    double Function(DaySnapshot s) valuePicker,
  ) {
    if (snapshots.length < 2) return const [];
    final valid = snapshots.where((s) => valuePicker(s) > 0).toList();
    if (valid.length < 2) return const [];

    return valid.map((s) {
      final t = DateTime.tryParse(s.dateKey) ?? DateTime.now();
      return HistoricalPoint(
        timestamp: t,
        value: valuePicker(s),
        label: s.dateKey.length >= 10 ? s.dateKey.substring(5).replaceAll('-', '.') : s.dateKey,
      );
    }).toList();
  }

  /// Получение тренда пульса покоя из реальных дневных снимков
  static List<HistoricalPoint> getHeartRateHistory(HistoryPeriod period, [List<DaySnapshot>? snapshots]) {
    final list = snapshots ?? const [];
    return _buildFromSnapshots(list, (s) => s.rhr.toDouble());
  }

  /// Получение тренда ВСР (HRV) из реальных дневных снимков
  static List<HistoricalPoint> getHrvHistory(HistoryPeriod period, [List<DaySnapshot>? snapshots]) {
    final list = snapshots ?? const [];
    return _buildFromSnapshots(list, (s) => s.hrv);
  }

  /// Получение истории оценок Recovery (0..100) из реальных дневных снимков
  static List<HistoricalPoint> getRecoveryHistory(HistoryPeriod period, [List<DaySnapshot>? snapshots]) {
    final list = snapshots ?? const [];
    return _buildFromSnapshots(list, (s) => s.recovery.toDouble());
  }

  /// Получение истории Strain из реальных дневных снимков
  static List<HistoricalPoint> getStrainHistory(HistoryPeriod period, [List<DaySnapshot>? snapshots]) {
    final list = snapshots ?? const [];
    return _buildFromSnapshots(list, (s) => s.strain);
  }

  /// Получение истории сна из реальных дневных снимков
  static List<HistoricalPoint> getSleepHistory(HistoryPeriod period, [List<DaySnapshot>? snapshots]) {
    final list = snapshots ?? const [];
    return _buildFromSnapshots(list, (s) => s.sleep.toDouble());
  }
}
