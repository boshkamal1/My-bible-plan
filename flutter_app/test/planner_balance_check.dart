import 'dart:math' as math;

import 'package:bible_journey/core/chapter_lengths.dart';
import 'package:bible_journey/core/day_util.dart';
import 'package:bible_journey/core/planner.dart';

void main() {
  final start = dayStr(dayNum(2026, 11, 3));
  for (final (scope, days) in [
    ('ot', 30),
    ('ot', 100),
    ('nt', 90),
    ('all', 100),
    ('all', 365)
  ]) {
    final plan =
        buildPlan(Setup(scope: scope, days: days, start: start, first: start));
    final minutes = plan.base
        .map((day) => day.fold<double>(
            0,
            (total, chapter) =>
                total + kChapterMinutes[chapter.b][chapter.c - 1]))
        .toList();
    final mean = minutes.reduce((a, b) => a + b) / minutes.length;
    final sd = math.sqrt(minutes.fold<double>(
            0, (total, value) => total + math.pow(value - mean, 2)) /
        minutes.length);
    final maximum = minutes.reduce(math.max);
    final minimum = minutes.reduce(math.min);
    print('$scope $days: mean=${mean.toStringAsFixed(1)} '
        'min=${minimum.toStringAsFixed(1)} max=${maximum.toStringAsFixed(1)} '
        'cv=${(sd / mean).toStringAsFixed(3)}');
    assert(plan.base.expand((day) => day).length == plan.total);
    assert(sd / mean < 0.20, '$scope $days has uneven reading time');
    assert(maximum / mean < 2.0, '$scope $days has an overloaded day');
  }
  final mixed = buildPlan(
      Setup(scope: 'all', mode: 'mix', days: 365, start: start, first: start));
  assert(mixed.base.expand((day) => day).length == mixed.total);
}
