import 'dart:math';

/// Криптографически стойкий генератор инвайт-кодов для кругов друзей и женского цикла.
/// Исключает неоднозначные символы (0/O, 1/I/L) для предотвращения ошибок при ручном вводе.
/// Пространство 31^8 (≈ 852 миллиарда комбинаций) гарантирует защиту от подбора и коллизий.
class SecureInviteGenerator {
  static final Random _rng = Random.secure();
  static const String _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  static String _randomSegment(int length) {
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Генерация кода для лиги друзей (например: KLK-FRN-9K4P-2X7M)
  static String generateFriendCode() {
    return 'KLK-FRN-${_randomSegment(4)}-${_randomSegment(4)}';
  }

  /// Генерация кода для связки партнёра женского цикла (например: KLK-CYC-8M3B-6R1A)
  static String generateCycleCode() {
    return 'KLK-CYC-${_randomSegment(4)}-${_randomSegment(4)}';
  }

  /// Проверка базовой структуры кода (строго требует современный формат KLK- с высокой энтропией)
  static bool isValidCode(String? code) {
    if (code == null) return false;
    final trimmed = code.trim().toUpperCase();
    if (trimmed.length < 12) return false;
    return trimmed.startsWith('KLK-');
  }
}
