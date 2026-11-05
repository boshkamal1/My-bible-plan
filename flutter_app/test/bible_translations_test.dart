import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bible_journey/core/bible_repo.dart';
import 'package:bible_journey/core/books.dart';
import 'package:bible_journey/core/day_util.dart';
import 'package:bible_journey/core/planner.dart';
import 'package:bible_journey/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Arabic source covers the requested books with vocalized text', () async {
    final repo = BibleRepo();
    for (final book in [0, 16, 17, 24, 25, 29, 44, 45, 46, 47, 48]) {
      final chapter = await repo.chapter(book, 1, 'svd');
      expect(chapter, isNotNull, reason: 'book $book');
      expect(chapter!.translation, 'svd');
      expect(chapter.verses.join(), matches(RegExp(r'[\u064b-\u065f]')));
    }
    final psalm = await repo.chapter(kPsalms, 151, 'svd');
    expect(psalm?.verses.length, 8);
    final prayer = await repo.chapter(46, 1, 'svd');
    expect(prayer?.fallback, isFalse);
    expect(prayer?.verses.length, 15);
    expect(prayer?.verses.first, contains('ضَابِطَ الْكُلِّ'));
    expect((await repo.search('ضابط الكل', 'svd')).any((hit) => hit.b == 46), isTrue);
    expect(displayChapterNumber(48, 7, 'svd'), 16);
    expect(displayChapterNumber(47, 2, 'svd'), 13);
  });

  test('WEB includes the deuterocanon and its own Psalm 151', () async {
    final repo = BibleRepo();
    for (final book in [0, 16, 17, 24, 25, 29, 44, 45, 46, 47, 48]) {
      final chapter = await repo.chapter(book, 1, 'web');
      expect(chapter, isNotNull, reason: 'book $book');
      expect(chapter!.translation, 'web');
      expect(chapter.fallback, isFalse);
    }
    expect((await repo.chapter(kPsalms, 151, 'web'))?.translation, 'web');
    expect((await repo.chapter(48, 10, 'web'))?.verses, isNotEmpty);
    expect((await repo.chapter(48, 7, 'kjv'))?.verses, isNotEmpty);
  });

  test('an existing plan retains its original daily assignments', () async {
    final start = dayStr(dayNum(2026, 11, 3));
    final setup = Setup(scope: 'ot', days: 100, start: start, first: start);
    final old = buildPlan(setup, legacyEsther: true);
    SharedPreferences.setMockInitialValues({
      'jb-v1': jsonEncode({'setup': setup.toJson()}),
    });
    final state = AppState(await SharedPreferences.getInstance())..load();
    final expected = old.base.map((day) => day.map((c) => c.key).toList()).toList();
    expect(state.planOverride, expected);
    expect(state.plan!.all.any((c) => c.key == '48:7'), isTrue);
  });
}
