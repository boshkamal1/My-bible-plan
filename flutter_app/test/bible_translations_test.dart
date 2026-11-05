import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bible_journey/core/bible_repo.dart';
import 'package:bible_journey/core/books.dart';
import 'package:bible_journey/core/translations.dart';
import 'package:bible_journey/core/day_util.dart';
import 'package:bible_journey/core/planner.dart';
import 'package:bible_journey/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every advertised full edition has all its navigable chapters',
      () async {
    final repo = BibleRepo();
    for (final tr in ['svd', 'gna', 'kjv', 'web']) {
      for (var b = 0; b < kBookCount; b++) {
        for (var c = 1; c <= bookChapterCount(b, tr); c++) {
          final text = await repo.chapter(b, c, tr);
          expect(text, isNotNull, reason: '$tr $b:$c');
          expect(text!.verses.any((v) => v.trim().isNotEmpty), isTrue,
              reason: '$tr $b:$c empty');
        }
      }
    }
  });

  test('Arabic source covers the requested books with vocalized text',
      () async {
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
    expect((await repo.search('ضابط الكل', 'svd')).any((hit) => hit.b == 46),
        isTrue);
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
    final expected =
        old.base.map((day) => day.map((c) => c.key).toList()).toList();
    expect(state.planOverride, expected);
    expect(state.plan!.all.any((c) => c.key == '48:7'), isTrue);
  });

  test('GNA has real source text and explicitly attributed old supplements',
      () async {
    final repo = BibleRepo();
    final gna = await repo.chapter(0, 1, 'gna');
    final original = await repo.chapter(0, 1, 'svd');
    expect(gna!.translation, 'gna');
    expect(gna.verses.first, isNot(original!.verses.first));
    expect(gna.fallback, false);
    final gnaTobit = await repo.chapter(16, 1, 'gna');
    final jesuit = await repo.chapter(16, 1, 'jesuit');
    expect(gnaTobit!.source, 'jesuit-old');
    expect(gnaTobit.fallback, true);
    expect(jesuit!.fallback, false);
    expect(gnaTobit.verses, jesuit.verses);
    expect(await repo.chapter(0, 1, 'jesuit'), isNull);
    for (final tr in ['gna', 'jesuit']) {
      final prayer = await repo.chapter(46, 1, tr);
      expect(prayer!.verses.length, 15);
      expect(prayer.source, 'manasseh-ar');
      expect(prayer.fallback, true);
      final psalm = await repo.chapter(kPsalms, 151, tr);
      expect(psalm!.verses.length, 8);
      expect(psalm.source, 'psalm151-ar');
      expect(psalm.fallback, true);
    }
  });

  test('GNA search normalizes Arabic and searches attributed supplements',
      () async {
    final repo = BibleRepo();
    final hit = await repo.search('خلق الله', 'gna');
    expect(hit.any((h) => h.b == 0 && h.c == 1 && h.v == 1), true);
    final extras = await repo.search('ضابط الكل', 'gna');
    expect(extras.any((h) => h.b == 46 && h.source == 'manasseh-ar'), true);
    final psalm = await repo.chapter(kPsalms, 151, 'gna');
    final matches =
        await repo.search(psalm!.verses.first, 'gna', limit: 100000);
    expect(
        matches.any(
            (h) => h.b == kPsalms && h.c == 151 && h.source == 'psalm151-ar'),
        true);
  });

  test('GNA citations preserve original Joel and Malachi reference numbers',
      () {
    expect(sourceVerseReference(33, 2, 28, 'gna'), (chapter: 3, verse: 1));
    expect(sourceVerseReference(33, 3, 1, 'gna'), (chapter: 4, verse: 1));
    expect(sourceVerseReference(43, 4, 6, 'gna'), (chapter: 3, verse: 24));
    expect(sourceVerseReference(33, 2, 28, 'svd'), (chapter: 2, verse: 28));
    expect(sourceVerseReference(47, 2, 1, 'jesuit'), (chapter: 13, verse: 1));
  });
}
