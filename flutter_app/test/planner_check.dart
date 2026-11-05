import 'package:bible_journey/core/planner.dart';
import 'package:bible_journey/core/day_util.dart';

void main() {
  final s0 = dayStr(dayNum(2026, 11, 1));
  for (final sc in ['ot', 'nt', 'all']) {
    for (final n in [30, 100, 365]) {
      final p = buildPlan(Setup(scope: sc, days: n, start: s0, first: s0));
      final keys = <String>[];
      for (final d in p.base) {
        keys.addAll(d.map((x) => x.key));
      }
      assert(
          keys.length == p.total, '$sc $n count ${keys.length} vs ${p.total}');
      assert(keys.toSet().length == keys.length, 'dupes');
      assert(p.base.length == n);
      final empty = p.base.where((d) => d.isEmpty).length;
      print('$sc $n total=${p.total} empty=$empty buf=${p.buf}');
    }
  }
  // rebalance
  final p = buildPlan(Setup(scope: 'ot', days: 100, start: s0, first: s0));
  final dates = makeDates(p, {});
  final days = layoutDays(p, dates, p.start, null);
  final out =
      rebalanceDays(p: p, days: days, lastFrozen: 4, isDone: (k) => false);
  assert(out.expand((e) => e).length == p.total);
  for (var k = 0; k <= 4; k++) assert(out[k].isEmpty);
  assert(out[5].isNotEmpty);
  final alreadyRead = days[2].take(2).map((chapter) => chapter.key).toSet();
  final withDone = rebalanceDays(
    p: p,
    days: days,
    lastFrozen: 4,
    isDone: alreadyRead.contains,
  );
  assert(withDone[2].toSet().containsAll(alreadyRead));
  assert(withDone.expand((day) => day).toSet().length == p.total);
  print('ok');
}
