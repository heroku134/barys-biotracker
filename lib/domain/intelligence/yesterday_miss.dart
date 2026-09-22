import '../../data/storage/day_journal_repository.dart';
import '../../data/storage/day_snapshot_repository.dart';

class YesterdayMiss {
  static Future<String?> line({required bool ru, String? en}) async {
    final y = await DaySnapshotRepository.yesterday();
    final journal = await DayJournalRepository.loadDay(DateTime.now().subtract(const Duration(days: 1)));
    if (y == null && journal == null) return null;

    if (y != null && y.sleep < 70) {
      return ru ? 'Вчера не добрали сон.' : (en ?? 'Sleep ran short yesterday.');
    }
    if (y != null && y.strain > 16) {
      return ru ? 'Вчера перебрали нагрузку.' : (en ?? 'Strain ran high yesterday.');
    }
    final text = '${journal?.note ?? ''} ${journal?.sleepNote ?? ''} ${journal?.workoutNote ?? ''}'.toLowerCase();
    if (text.contains('ужин') || text.contains('late') || text.contains('кеч')) {
      return ru ? 'Вчера поздний ужин.' : (en ?? 'Late dinner yesterday.');
    }
    return null;
  }
}
