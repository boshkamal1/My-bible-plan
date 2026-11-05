import 'dart:math' as math;

import 'books.dart';
import 'day_util.dart';

class Setup {
  final String scope;
  final List<int>? selectedBooks;
  final List<int> bookOrder;
  final bool reserveWithinDuration;
  final int otB;
  final int otC;
  final int otP;
  final int ntB;
  final int ntC;
  final List<int> skip;
  final String mode;
  final int days;
  final String? end;
  final String start;
  final String first;

  const Setup({
    this.scope = 'ot',
    this.selectedBooks,
    this.bookOrder = const [],
    this.reserveWithinDuration = false,
    this.otB = -1,
    this.otC = 0,
    this.otP = 0,
    this.ntB = -1,
    this.ntC = 0,
    this.skip = const [],
    this.mode = 'seq',
    this.days = 100,
    this.end,
    required this.start,
    required this.first,
  });

  Setup copyWith({String? start, String? first}) => Setup(
        scope: scope,
        selectedBooks: selectedBooks,
        bookOrder: bookOrder,
        reserveWithinDuration: reserveWithinDuration,
        otB: otB,
        otC: otC,
        otP: otP,
        ntB: ntB,
        ntC: ntC,
        skip: skip,
        mode: mode,
        days: days,
        end: end,
        start: start ?? this.start,
        first: first ?? this.first,
      );

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'selectedBooks': selectedBooks,
        'bookOrder': bookOrder,
        'reserveWithinDuration': reserveWithinDuration,
        'ot': {'b': otB, 'c': otC, 'p': otP},
        'nt': {'b': ntB, 'c': ntC},
        'skip': skip,
        'mode': mode,
        'days': days,
        'end': end,
        'start': start,
        'first': first,
      };

  static Setup fromJson(Map<String, dynamic> j) {
    final ot = (j['ot'] as Map?) ?? const {};
    final nt = (j['nt'] as Map?) ?? const {};
    return Setup(
      scope: (j['scope'] as String?) ?? 'ot',
      selectedBooks: (j['selectedBooks'] as List?)?.cast<int>(),
      bookOrder: (j['bookOrder'] as List?)?.cast<int>() ?? const [],
      reserveWithinDuration: j['reserveWithinDuration'] == true,
      otB: (ot['b'] as num?)?.toInt() ?? -1,
      otC: (ot['c'] as num?)?.toInt() ?? 0,
      otP: (ot['p'] as num?)?.toInt() ?? 0,
      ntB: (nt['b'] as num?)?.toInt() ?? -1,
      ntC: (nt['c'] as num?)?.toInt() ?? 0,
      skip: ((j['skip'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      mode: (j['mode'] as String?) ?? 'seq',
      days: (j['days'] as num?)?.toInt() ?? 100,
      end: j['end'] as String?,
      start: j['start'] as String,
      first: (j['first'] as String?) ?? (j['start'] as String),
    );
  }
}

List<int> cutsFor(List<double> w, int n) {
  final out = <int>[];
  if (n <= 0) return out;
  final len = w.length;
  final cum = <double>[];
  var a = 0.0;
  for (final x in w) {
    a += x;
    cum.add(a);
  }
  final tot = a;
  var prev = 0;
  for (var k = 1; k <= n; k++) {
    final target = tot * k / n;
    var best = prev;
    var bd = double.infinity;
    for (var t = prev; t <= len; t++) {
      final v = t > 0 ? cum[t - 1] : 0.0;
      final d = (v - target).abs();
      if (d < bd) {
        bd = d;
        best = t;
      } else if (v > target) {
        break;
      }
    }
    if (len >= n) best = math.min(math.max(best, prev + 1), len - (n - k));
    if (k == n) best = len;
    out.add(best);
    prev = best;
  }
  return out;
}

// Every chapter can be scheduled independently, including long books.
double itemWeight(List<Chap> it) => it.fold(0.0, (a, x) => a + x.weight);

List<List<Chap>> itemsOf(List<Chap> chapters) => [
      for (final chapter in chapters) [chapter],
    ];

List<List<Chap>> rowsFor(List<Chap> chapters, int days) {
  if (days <= 0) return [];
  final cuts =
      cutsFor(chapters.map((chapter) => chapter.weight).toList(), days);
  return [
    for (var day = 0; day < days; day++)
      chapters.sublist(day == 0 ? 0 : cuts[day - 1], cuts[day]),
  ];
}

Map<int, int> preFor(Setup? su, bool useOt, bool useNt) {
  final o = <int, int>{};
  for (var i = 0; i < kBookCount; i++) {
    final n = kChapters[i];
    if (i == kPsalms) {
      o[i] = useOt && su != null ? su.otP : 0;
    } else if (i >= 49) {
      if (!useNt || su == null || su.ntB < 0) {
        o[i] = 0;
      } else {
        o[i] = kPos[i]! < kPos[su.ntB]! ? n : (i == su.ntB ? su.ntC : 0);
      }
    } else {
      if (!useOt || su == null || su.otB < 0) {
        o[i] = 0;
      } else {
        o[i] = kPos[i]! < kPos[su.otB]! ? n : (i == su.otB ? su.otC : 0);
      }
    }
  }
  return o;
}

List<int> scopeBooks(String scope) => [
      if (scope != 'nt') ...kPlanOrderOt,
      if (scope != 'ot') ...kPlanOrderNt,
    ];

({int ch, int ps}) remainingFor(
  Map<int, int> pre,
  List<int> skip,
  String scope,
) {
  final sk = skip.toSet();
  var ch = 0;
  var ps = 0;
  for (final i in scopeBooks(scope)) {
    if (i == kPsalms) {
      ps = kChapters[kPsalms] - pre[i]!;
    } else if (!sk.contains(i)) {
      ch += kChapters[i] - pre[i]!;
    }
  }
  return (ch: ch, ps: ps);
}

class PlanData {
  final Setup setup;
  final Map<int, int> pre;
  final Set<int> skip;
  final List<Chap> ch;
  final List<Chap> ps;
  final List<Chap> all;
  final Set<String> inPlan;
  final int start;
  final int first;
  final int nDays;
  final int end;
  final int buf;
  final int xmas;
  final List<List<Chap>> base;

  PlanData({
    required this.setup,
    required this.pre,
    required this.skip,
    required this.ch,
    required this.ps,
    required this.all,
    required this.inPlan,
    required this.start,
    required this.first,
    required this.nDays,
    required this.end,
    required this.buf,
    required this.xmas,
    required this.base,
  });

  int get total => all.length;
}

PlanData buildPlan(Setup su, {bool legacyEsther = false}) {
  final sc = su.scope;
  final start = parseDay(su.start);
  final first = parseDay(su.first);
  final pre = preFor(su, sc != 'nt', sc != 'ot');
  final skip = <int>{...su.skip};
  if (sc == 'nt') skip.addAll(kPlanOrderOt);
  if (sc == 'ot') skip.addAll(kPlanOrderNt);
  if (su.selectedBooks != null)
    skip.addAll(scopeBooks(sc).where((b) => !su.selectedBooks!.contains(b)));
  final chOt = <Chap>[];
  final chNt = <Chap>[];
  final ps = <Chap>[];
  for (final i in kPlanOrderOt) {
    if (skip.contains(i)) continue;
    final chapterCount = legacyEsther && i == 48 ? 6 : kChapters[i];
    for (var c = pre[i]! + 1; c <= chapterCount; c++) {
      if (i == kPsalms) {
        ps.add(Chap(i, c));
      } else {
        chOt.add(Chap(i, c));
      }
    }
  }
  for (final i in kPlanOrderNt) {
    if (skip.contains(i)) continue;
    for (var c = pre[i]! + 1; c <= kChapters[i]; c++) {
      chNt.add(Chap(i, c));
    }
  }
  final ch = [...chOt, ...chNt];
  if (su.bookOrder.isNotEmpty) {
    ch.addAll(ps);
    ps.clear();
    final order = [...su.bookOrder, ...scopeBooks(sc)].toSet().toList();
    ch.sort((a, b) {
      final cmp = order.indexOf(a.b).compareTo(order.indexOf(b.b));
      return cmp == 0 ? a.c.compareTo(b.c) : cmp;
    });
  }
  final all = [...ch, ...ps];
  final inPlan = all.map((x) => x.key).toSet();
  var nDays = 0;
  if (all.isNotEmpty) {
    if (su.end != null) {
      nDays = math.max(1, parseDay(su.end!) - start + 1);
    } else {
      nDays = math.max(1, su.days);
    }
  }
  final int buf = math.min(7, nDays ~/ 10);
  if (su.reserveWithinDuration && nDays > 0) nDays = math.max(1, nDays - buf);
  final int end = start + (nDays > 1 ? nDays : 1) - 1;
  final int xmas = end + buf + 1;
  List<List<Chap>> rows;
  if (su.bookOrder.isNotEmpty) {
    final cuts = cutsFor(ch.map((c) => c.weight).toList(), nDays);
    rows = [
      for (var i = 0; i < cuts.length; i++)
        ch.sublist(i == 0 ? 0 : cuts[i - 1], cuts[i])
    ];
  } else if (sc == 'all' && su.mode == 'mix') {
    final a = rowsFor(chOt, nDays);
    final b = rowsFor(chNt, nDays);
    rows = [
      for (var k = 0; k < nDays; k++) [...a[k], ...b[k]],
    ];
  } else {
    rows = rowsFor(ch, nDays);
  }
  final bp = cutsFor(ps.map((x) => x.weight).toList(), nDays);
  final base = <List<Chap>>[];
  for (var k = 0; k < nDays; k++) {
    base.add([
      ...ps.sublist(k > 0 ? bp[k - 1] : 0, bp[k]),
      ...(k < rows.length ? rows[k] : <Chap>[]),
    ]);
  }
  if (su.bookOrder.isEmpty) _balanceDailyRows(base, all.length >= nDays);
  return PlanData(
    setup: su,
    pre: pre,
    skip: skip,
    ch: ch,
    ps: ps,
    all: all,
    inPlan: inPlan,
    start: start,
    first: first,
    nDays: nDays,
    end: end,
    buf: buf,
    xmas: xmas,
    base: base,
  );
}

void _balanceDailyRows(List<List<Chap>> days, bool avoidEmptyDays,
    {bool Function(Chap)? movable}) {
  if (days.length < 2) return;
  final total =
      days.expand((day) => day).fold<double>(0, (a, c) => a + c.weight);
  final target = total / days.length;
  double cost(double a, double b) =>
      (a - target) * (a - target) + (b - target) * (b - target);
  for (var pass = 0; pass < 4; pass++) {
    var changed = false;
    for (var i = 0; i < days.length - 1; i++) {
      final left = days[i];
      final right = days[i + 1];
      final lw = left.fold<double>(0, (a, c) => a + c.weight);
      final rw = right.fold<double>(0, (a, c) => a + c.weight);
      final old = cost(lw, rw);
      final leftCandidate = left.isNotEmpty &&
              !left.last.isPsalm &&
              (movable == null || movable(left.last)) &&
              (!avoidEmptyDays || left.length > 1)
          ? left.last
          : null;
      final rightIndex = right.indexWhere((c) => !c.isPsalm);
      final rightCandidate = rightIndex >= 0 &&
              (movable == null || movable(right[rightIndex])) &&
              (!avoidEmptyDays || right.length > 1)
          ? right[rightIndex]
          : null;
      final moveRight = leftCandidate == null
          ? double.infinity
          : cost(lw - leftCandidate.weight, rw + leftCandidate.weight);
      final moveLeft = rightCandidate == null
          ? double.infinity
          : cost(lw + rightCandidate.weight, rw - rightCandidate.weight);
      if (moveRight + 0.001 < old && moveRight <= moveLeft) {
        left.removeLast();
        right.insert(
            rightIndex < 0 ? right.length : rightIndex, leftCandidate!);
        changed = true;
      } else if (moveLeft + 0.001 < old) {
        right.removeAt(rightIndex);
        left.add(rightCandidate!);
        changed = true;
      }
    }
    if (!changed) break;
  }
}

List<int> makeDates(PlanData p, Set<int> delays) {
  final dates = <int>[];
  var n = p.start;
  while (dates.length < p.nDays) {
    if (!delays.contains(n)) dates.add(n);
    n++;
  }
  return dates;
}

int firstIndexOnOrAfter(List<int> dates, int today) {
  for (var i = 0; i < dates.length; i++) {
    if (dates[i] >= today) return i;
  }
  return dates.length;
}

Map<String, int> _orderMap(PlanData p) {
  final m = <String, int>{};
  for (var i = 0; i < p.all.length; i++) {
    m[p.all[i].key] = i;
  }
  return m;
}

void sortChaps(List<Chap> a, Map<String, int> ord, {bool custom = false}) {
  a.sort((p, q) {
    final pa = p.isPsalm ? 0 : 1;
    final qa = q.isPsalm ? 0 : 1;
    if (!custom && pa != qa) return pa - qa;
    return (ord[p.key] ?? 0) - (ord[q.key] ?? 0);
  });
}

List<List<Chap>> layoutDays(
  PlanData p,
  List<int> dates,
  int today,
  List<List<String>>? saved,
) {
  final kT = firstIndexOnOrAfter(dates, today);
  final useSaved = saved != null && saved.length == p.nDays;
  final days = <List<Chap>>[];
  for (var k = 0; k < p.nDays; k++) {
    if (useSaved) {
      final row = <Chap>[];
      for (final s in saved[k]) {
        final c = Chap.parse(s);
        if (c != null && p.inPlan.contains(c.key)) row.add(c);
      }
      days.add(row);
    } else {
      days.add(List<Chap>.from(p.base[k]));
    }
  }
  if (useSaved && p.nDays > 0) {
    final have = <String>{};
    for (final d in days) {
      for (final x in d) {
        have.add(x.key);
      }
    }
    final miss = p.all.where((x) => !have.contains(x.key)).toList();
    final m0 = math.min(kT, p.nDays - 1);
    final mn = p.nDays - m0;
    if (miss.isNotEmpty && mn > 0) {
      final it = itemsOf(miss);
      final mc = cutsFor(it.map(itemWeight).toList(), mn);
      for (var i = 0; i < mc.length; i++) {
        days[m0 + i].addAll(
          it.sublist(i > 0 ? mc[i - 1] : 0, mc[i]).expand((e) => e),
        );
      }
      final ord = _orderMap(p);
      for (final d in days) {
        sortChaps(d, ord, custom: p.setup.bookOrder.isNotEmpty);
      }
    }
  }
  return days;
}

List<List<String>> rebalanceDays({
  required PlanData p,
  required List<List<Chap>> days,
  required int lastFrozen,
  required bool Function(String key) isDone,
  List<int>? only,
}) {
  final m = p.nDays - 1 - lastFrozen;
  final ord = _orderMap(p);
  final out = [for (var k = 0; k < days.length; k++) <Chap>[]];
  if (m <= 0) {
    return [for (final d in days) d.map((x) => x.key).toList()];
  }
  final pc = <Chap>[];
  final pp = <Chap>[];
  for (var k = 0; k < days.length; k++) {
    for (final x in days[k]) {
      if (isDone(x.key)) {
        out[k].add(x);
      } else if (only == null || only.contains(k) || k > lastFrozen) {
        (x.isPsalm && p.setup.bookOrder.isEmpty ? pp : pc).add(x);
      } else {
        out[k].add(x);
      }
    }
  }
  sortChaps(pc, ord, custom: p.setup.bookOrder.isNotEmpty);
  sortChaps(pp, ord);
  final ci = itemsOf(pc);
  final c = cutsFor(ci.map(itemWeight).toList(), m);
  final pcut = cutsFor(pp.map((x) => x.weight).toList(), m);
  for (var i = 0; i < m; i++) {
    final j = lastFrozen + 1 + i;
    out[j].addAll(pp.sublist(i > 0 ? pcut[i - 1] : 0, pcut[i]));
    out[j].addAll(ci.sublist(i > 0 ? c[i - 1] : 0, c[i]).expand((e) => e));
  }
  if (p.setup.bookOrder.isEmpty) _balanceDailyRows(out.sublist(lastFrozen + 1), pc.length + pp.length >= m,
      movable: (chapter) => !isDone(chapter.key));
  for (final d in out) {
    sortChaps(d, ord, custom: p.setup.bookOrder.isNotEmpty);
  }
  return [for (final d in out) d.map((x) => x.key).toList()];
}

class StreakInfo {
  final int cur;
  final int best;
  final bool atRisk;
  final bool readToday;
  final bool frozenToday;
  const StreakInfo(
    this.cur,
    this.best,
    this.atRisk,
    this.readToday,
    this.frozenToday,
  );
}

StreakInfo streakOf({
  required Set<String> readDates,
  required Set<String> frozen,
  required int today,
  required int first,
}) {
  final ts = dayStr(today);
  var n = today;
  var atRisk = false;
  if (!readDates.contains(ts)) {
    atRisk = !frozen.contains(ts);
    n--;
  }
  var cur = 0;
  while (n >= first - 1) {
    final s = dayStr(n);
    if (readDates.contains(s)) {
      cur++;
    } else if (!frozen.contains(s)) {
      break;
    }
    n--;
  }
  var best = 0;
  var run = 0;
  if (readDates.isNotEmpty) {
    final sorted = readDates.toList()..sort();
    for (var x = parseDay(sorted.first); x <= today; x++) {
      final s = dayStr(x);
      if (readDates.contains(s)) {
        run++;
        best = math.max(best, run);
      } else if (!frozen.contains(s)) {
        run = 0;
      }
    }
  }
  return StreakInfo(
    cur,
    best,
    atRisk,
    readDates.contains(ts),
    frozen.contains(ts),
  );
}
