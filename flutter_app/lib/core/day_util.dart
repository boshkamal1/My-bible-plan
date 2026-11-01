const int _dayMs = 86400000;

int dayNum(int y, int m, int d) =>
    DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ _dayMs;

int dayFromDate(DateTime d) => dayNum(d.year, d.month, d.day);

int todayNum() => dayFromDate(DateTime.now());

DateTime dayToDate(int n) =>
    DateTime.fromMillisecondsSinceEpoch(n * _dayMs, isUtc: true);

String dayStr(int n) {
  final d = dayToDate(n);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int parseDay(String s) {
  final a = s.split('-').map(int.parse).toList();
  return dayNum(a[0], a[1], a[2]);
}
