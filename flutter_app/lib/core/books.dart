import 'book_data.dart';

export 'book_data.dart';

const int kBookCount = 76;
const int kPsalms = 20;
const Set<int> kDeut = {16, 17, 24, 25, 29, 44, 45, 46, 47, 48};
const List<int> kPlanOrderOt = [
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  46,
  14,
  15,
  16,
  17,
  18,
  48,
  44,
  45,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  47,
  32,
  33,
  34,
  35,
  36,
  37,
  38,
  39,
  40,
  41,
  42,
  43,
];
const List<int> kPlanOrderNt = [
  49,
  50,
  51,
  52,
  53,
  54,
  55,
  56,
  57,
  58,
  59,
  60,
  61,
  62,
  63,
  64,
  65,
  66,
  67,
  68,
  69,
  70,
  71,
  72,
  73,
  74,
  75,
];
const List<List<int>> kUnits = [
  [44],
  [45],
];
const Map<int, double> kPsalmWeights = {
  18: 1.5,
  78: 2.5,
  89: 2,
  105: 1.5,
  106: 1.5,
  107: 1.5,
  119: 5,
  136: 1.5,
};

final Map<int, int> kPos = () {
  final m = <int, int>{};
  for (var i = 0; i < kPlanOrderOt.length; i++) {
    m[kPlanOrderOt[i]] = i;
  }
  for (var i = 0; i < kPlanOrderNt.length; i++) {
    m[kPlanOrderNt[i]] = i;
  }
  return m;
}();

class BookGroup {
  final String id;
  final List<int> books;
  const BookGroup(this.id, this.books);
}

List<int> _range(int a, int b) => [for (var i = a; i <= b; i++) i];

final List<BookGroup> kOtGroups = [
  BookGroup('moses', kPlanOrderOt.where((b) => b <= 4).toList()),
  BookGroup(
    'history',
    kPlanOrderOt.where((b) => b >= 5 && b <= 18 && !kDeut.contains(b)).toList(),
  ),
  BookGroup(
    'wisdom',
    kPlanOrderOt
        .where((b) => b >= 19 && b <= 25 && !kDeut.contains(b) && b != kPsalms)
        .toList(),
  ),
  BookGroup(
    'prophets',
    kPlanOrderOt
        .where((b) => b >= 26 && b <= 43 && !kDeut.contains(b))
        .toList(),
  ),
  BookGroup('deut', kPlanOrderOt.where(kDeut.contains).toList()),
];
final List<BookGroup> kNtGroups = [
  BookGroup('gospels', _range(49, 53)),
  BookGroup('paul', _range(54, 67)),
  BookGroup('general', _range(68, 75)),
];

bool isNt(int b) => b >= 49;

class Chap {
  final int b;
  final int c;
  const Chap(this.b, this.c);
  String get key => '$b:$c';
  bool get isPsalm => b == kPsalms;
  double get weight => isPsalm
      ? (kPsalmWeights[c] ?? 1.0)
      : 0.3 * 28.4 + 0.7 * kVerses[b] / kChapters[b];
  static Chap? parse(String k) {
    final p = k.split(':');
    if (p.length != 2) return null;
    final b = int.tryParse(p[0]);
    final c = int.tryParse(p[1]);
    if (b == null ||
        c == null ||
        b < 0 ||
        b >= kBookCount ||
        c < 1 ||
        c > kChapters[b])
      return null;
    return Chap(b, c);
  }

  @override
  bool operator ==(Object o) => o is Chap && o.b == b && o.c == c;
  @override
  int get hashCode => b * 1000 + c;
  @override
  String toString() => key;
}

class Seg {
  final int b;
  final List<int> cs;
  Seg(this.b, this.cs);
}

List<Seg> segsOf(List<Chap> ks) {
  final out = <Seg>[];
  for (final x in ks) {
    if (out.isNotEmpty && out.last.b == x.b) {
      out.last.cs.add(x.c);
    } else {
      out.add(Seg(x.b, [x.c]));
    }
  }
  return out;
}
