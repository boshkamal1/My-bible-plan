import 'package:flutter_test/flutter_test.dart';
import 'package:bible_journey/core/planner.dart';
import 'package:bible_journey/core/day_util.dart';

void main() {
  const start = '2026-11-05';
  test('new 100-day journey finishes in 93 days with every chapter once', () {
    final p = buildPlan(
        const Setup(start: start, first: start, reserveWithinDuration: true));
    expect(p.nDays, 93);
    expect(p.end, parseDay(start) + 92);
    expect(p.buf, 7);
    final keys = p.base.expand((d) => d).map((c) => c.key).toList();
    expect(keys.length, p.total);
    expect(keys.toSet().length, p.total);
  });
  test('old stored journeys keep their duration', () {
    final setup = Setup.fromJson({'start': start, 'days': 100});
    expect(buildPlan(setup).nDays, 100);
  });
  test('selection and exclusion combine and survive serialization', () {
    final setup = Setup.fromJson(const Setup(
            start: start,
            first: start,
            selectedBooks: [0, 1, 2],
            skip: [1],
            bookOrder: [2, 0],
            reserveWithinDuration: true)
        .toJson());
    final p = buildPlan(setup);
    expect(p.all.map((c) => c.b).toSet(), {0, 2});
    expect(p.base.expand((d) => d).first.b, 2);
    expect(setup.copyWith(start: start).bookOrder, [2, 0]);
  });
  test('custom order includes psalms and survives rebalance', () {
    final p = buildPlan(const Setup(
        start: start,
        first: start,
        selectedBooks: [0, 20, 49],
        scope: 'all',
        bookOrder: [49, 20, 0]));
    final keys = p.base.expand((d) => d).map((c) => c.key).toList();
    expect(keys, p.all.map((c) => c.key).toList());
    final rows =
        rebalanceDays(p: p, days: p.base, lastFrozen: -1, isDone: (_) => false);
    expect(rows.expand((d) => d).toList(), keys);
  });
  test('empty selection creates no readings', () {
    expect(
        buildPlan(const Setup(start: start, first: start, selectedBooks: []))
            .total,
        0);
  });
  test('date-based duration also deducts reserves', () {
    final p = buildPlan(Setup(
        start: start,
        first: start,
        end: dayStr(parseDay(start) + 99),
        reserveWithinDuration: true));
    expect(p.nDays, 93);
  });
}
