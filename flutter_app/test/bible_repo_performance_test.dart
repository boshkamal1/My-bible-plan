import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bible_journey/core/bible_repo.dart';
import 'package:bible_journey/core/books.dart';

class _Bundle extends AssetBundle {
  _Bundle(this.assets, {this.gate});
  final Map<String, String> assets;
  final Completer<void>? gate;
  final Map<String, int> loads = {};

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loads.update(key, (n) => n + 1, ifAbsent: () => 1);
    if (gate != null) await gate!.future;
    if (!assets.containsKey(key)) throw StateError('Missing $key');
    return assets[key]!;
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

// Independent copy of the previous search algorithm, for behavior comparisons
// and a same-process timing baseline. It caches decoded books, not search text.
class _LegacySearch {
  final Map<String, List<List<String>>?> cache = {};

  Future<List<List<String>>?> book(String tr, int b) async {
    final key = '$tr/$b';
    if (cache.containsKey(key)) return cache[key];
    try {
      final raw = await rootBundle.loadString('assets/bible/$key.json');
      return cache[key] = (jsonDecode(raw) as List)
          .map((c) => (c as List).map((v) => v.toString()).toList())
          .toList();
    } catch (_) {
      return cache[key] = null;
    }
  }

  Future<List<SearchHit>> search(String q, String tr, {int limit = 200}) async {
    final out = <SearchHit>[];
    final query = tr == 'svd' ? normalizeAr(q.trim()) : q.trim().toLowerCase();
    if (query.length < 2) return out;
    for (var b = 0; b < kBookCount; b++) {
      var t = tr;
      var bk = await book(t == 'svd' && kDeut.contains(b) ? 'ar_extra' : t, b);
      if (bk == null) {
        t = 'kjv';
        bk = await book(t, b);
        if (bk == null) continue;
        if (tr == 'svd' && RegExp(r'[؀-ۿ]').hasMatch(q)) continue;
      }
      for (var c = 0; c < bk.length; c++) {
        for (var v = 0; v < bk[c].length; v++) {
          final text = bk[c][v];
          final normalized =
              t == 'svd' ? normalizeAr(text) : text.toLowerCase();
          if (normalized.isNotEmpty && normalized.contains(query)) {
            out.add(SearchHit(b, c + 1, v + 1, text));
            if (out.length >= limit) return out;
          }
        }
      }
    }
    return out;
  }
}

List<Object> _values(List<SearchHit> hits) =>
    hits.map((h) => [h.b, h.c, h.v, h.text]).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup is lazy and concurrent chapter readers share one load',
      () async {
    final gate = Completer<void>();
    final bundle = _Bundle({'assets/bible/kjv/0.json': '[["First","Second"]]'},
        gate: gate);
    final repo = BibleRepo(bundle: bundle);
    expect(bundle.loads, isEmpty);
    final requests = List.generate(20, (_) => repo.chapter(0, 1, 'kjv'));
    expect(bundle.loads.values, [1]);
    gate.complete();
    final chapters = await Future.wait(requests);
    expect(chapters.every((c) => identical(c!.verses, chapters.first!.verses)),
        isTrue);
    expect(await repo.verseCount(0, 1), 2);
    expect(bundle.loads.values, [1]);
  });

  test('missing and malformed assets share cached failures and fallback',
      () async {
    final bundle = _Bundle({
      'assets/bible/svd/0.json': '{}',
      'assets/bible/kjv/0.json': '[["Fallback"]]'
    });
    final repo = BibleRepo(bundle: bundle);
    final chapters =
        await Future.wait(List.generate(10, (_) => repo.chapter(0, 1, 'svd')));
    expect(
        chapters.every((c) => c!.fallback && c.translation == 'kjv'), isTrue);
    expect(bundle.loads, {
      'assets/bible/svd/0.json': 1,
      'assets/bible/ar_extra/0.json': 1,
      'assets/bible/kjv/0.json': 1
    });
  });

  test('short queries do no loading and limited search stops at first book',
      () async {
    final bundle = _Bundle({'assets/bible/kjv/0.json': '[["Match","MATCH"]]'});
    final repo = BibleRepo(bundle: bundle);
    expect(await repo.search(' a ', 'kjv'), isEmpty);
    expect(await repo.search('َ', 'svd'), isEmpty);
    expect(bundle.loads, isEmpty);
    for (final limit in [1, 0, -1]) {
      // Preserve the existing nonpositive-limit behavior (one matching hit).
      expect(_values(await repo.search(' match ', 'kjv', limit: limit)), [
        [0, 1, 1, 'Match']
      ]);
    }
    expect(bundle.loads, {'assets/bible/kjv/0.json': 1});
  });

  test('cached normalization preserves Arabic, ordering and mutable verses',
      () async {
    final bundle = _Bundle({
      'assets/bible/svd/0.json': jsonEncode([
        ['أَلْفَة', 'الفه', '']
      ])
    });
    final repo = BibleRepo(bundle: bundle);
    expect(
        (await repo.search('الفه', 'svd', limit: 2)).map((h) => h.v), [1, 2]);
    final chapter = (await repo.chapter(0, 1, 'svd'))!;
    chapter.verses[0] = 'إِيمَان';
    expect(_values(await repo.search('ايمان', 'svd', limit: 1)), [
      [0, 1, 1, 'إِيمَان']
    ]);
    chapter.verses.add('إِيمَان');
    expect(
        (await repo.search('ايمان', 'svd', limit: 2)).map((h) => h.v), [1, 4]);
  });

  test('Arabic queries skip English fallback but Latin queries search it',
      () async {
    final bundle = _Bundle({
      'assets/bible/kjv/0.json': jsonEncode([
        ['Grace نعمة']
      ])
    });
    final repo = BibleRepo(bundle: bundle);
    expect(await repo.search('نعمه', 'svd'), isEmpty);
    expect(_values(await repo.search('grace', 'svd')), [
      [0, 1, 1, 'Grace نعمة']
    ]);
    expect(bundle.loads.values.every((count) => count == 1), isTrue);
  });

  test('full-corpus scans allow event-loop work before completing', () async {
    final verse = List.filled(100, 'أَلْفَة').join(' ');
    final bundle = _Bundle({
      'assets/bible/svd/0.json': jsonEncode([List.filled(5000, verse)])
    });
    final repo = BibleRepo(bundle: bundle);
    await repo.chapter(0, 1, 'svd');
    var eventRan = false;
    Timer.run(() => eventRan = true);
    expect(await repo.search('zzzzunlikely', 'svd'), isEmpty);
    expect(eventRan, isTrue);
  });

  test('real-asset results match legacy search and report scan timings',
      () async {
    for (final tr in ['svd', 'kjv', 'web']) {
      final repo = BibleRepo();
      final legacy = _LegacySearch();
      final timer = Stopwatch()..start();
      expect(await repo.search('zzzzunlikelymatchzzzz', tr), isEmpty);
      final cold = timer.elapsedMicroseconds;
      await legacy.search('zzzzunlikelymatchzzzz', tr);
      timer.reset();
      for (var i = 0; i < 5; i++) {
        expect(await repo.search('zzzzunlikelymatchzzzz$i', tr), isEmpty);
      }
      final warm = timer.elapsedMicroseconds / 5000;
      timer.reset();
      for (var i = 0; i < 5; i++) {
        expect(await legacy.search('zzzzunlikelymatchzzzz$i', tr), isEmpty);
      }
      final baseline = timer.elapsedMicroseconds / 5000;
      // Informational only: host timings must not make CI flaky.
      print(
          '$tr cold=${cold / 1000}ms warm=${warm}ms legacyWarm=${baseline}ms');
      for (final q in [' GOD ', 'love', 'الله', 'ضابط الكل', 'إِيمَان']) {
        for (final limit in [1, 200]) {
          expect(_values(await repo.search(q, tr, limit: limit)),
              _values(await legacy.search(q, tr, limit: limit)),
              reason: '$tr $q $limit');
        }
      }
    }
  });
}
