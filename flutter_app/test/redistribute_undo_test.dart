import 'package:bible_journey/core/day_util.dart';
import 'package:bible_journey/core/planner.dart';
import 'package:bible_journey/state/app_state.dart';
import 'package:bible_journey/ui/day_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppState> state() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance())
      ..load()
      ..newJourney(Setup(
          start: dayStr(todayNum()),
          first: dayStr(todayNum()),
          days: 30,
          selectedBooks: const [0]));
  }

  List<List<String>> rows(AppState s) =>
      s.days.map((row) => row.map((c) => c.key).toList()).toList();
  test(
      'undo restores exact prior distribution and keeps later reading progress',
      () async {
    final s = await state();
    final before = rows(s);
    final undo = s.redistribute(0)!;
    expect(rows(s), isNot(before));
    s.markChapter('0:3', true);
    undo();
    expect(rows(s), before);
    expect(s.isDone('0:3'), isTrue);
    s.redistribute(0);
    final previous = rows(s);
    final second = s.redistribute(1)!;
    second();
    expect(rows(s), previous);
    expect(s.planOverride, isNotNull);
    s.planOverride = null;
    s.touch(recompute: true);
    await s.flush();
    final reloaded = AppState(s.prefs)..load();
    expect(rows(reloaded), before);
    expect(reloaded.isDone('0:3'), isTrue);
    reloaded.dispose();
    s.dispose();
  });
  test('stale undo cannot replace a newer distribution or journey', () async {
    final s = await state();
    final undo = s.redistribute(0)!;
    s.redistribute(1);
    final newer = rows(s);
    undo();
    expect(rows(s), newer);
    final oldJourneyUndo = s.redistribute(1)!;
    s.newJourney(
        Setup(start: dayStr(todayNum()), first: dayStr(todayNum()), days: 40, selectedBooks: const [1]));
    final newJourney = rows(s);
    oldJourneyUndo();
    expect(rows(s), newJourney);
    final oldSessionUndo = s.redistribute(0)!;
    s.sessionRevision++;
    final newSession = rows(s);
    oldSessionUndo();
    expect(rows(s), newSession);
    s.dispose();
  });
  test('normal cloud sync keeps undo usable', () async {
    final s = await state();
    final before = rows(s);
    final undo = s.redistribute(0)!;
    final sent = s.toMap(cloud: true);
    await s.acceptSynced(sent, sent);
    undo();
    expect(rows(s), before);
    s.dispose();
  });
  for (final cancel in [true, false]) {
    testWidgets(
        cancel
            ? 'undo action restores chapters'
            : 'undo expires after five seconds', (tester) async {
      final s = await state();
      final before = rows(s);
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: s,
          child: MaterialApp(
              home: Scaffold(
                  body: SingleChildScrollView(child: DayView(k: 0))))));
      final button = find.text('وزّع الأصحاحات');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(rows(s), isNot(before));
      expect(find.text('تراجع'), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 5));
      if (cancel) {
        await tester.tap(find.text('تراجع'));
        await tester.pumpAndSettle();
        expect(rows(s), before);
      } else {
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text('تراجع'), findsNothing);
        expect(rows(s), isNot(before));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      s.dispose();
    });
  }
}
