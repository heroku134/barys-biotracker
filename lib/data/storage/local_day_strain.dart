class LocalDayStrain {
  static String _day = '';
  static double extra = 0;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static void add(double session) {
    final d = _today();
    if (_day != d) {
      _day = d;
      extra = 0;
    }
    extra += session;
  }

  static double current() {
    if (_day != _today()) {
      extra = 0;
      _day = _today();
    }
    return extra;
  }
}
