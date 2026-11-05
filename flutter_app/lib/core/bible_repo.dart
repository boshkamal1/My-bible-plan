import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'books.dart';
import 'translations.dart';

class ChapterText {
  final List<String> verses;
  final String translation; // translation actually shown
  final bool fallback; // true when the requested translation was not available
  final String? source;
  const ChapterText(this.verses, this.translation, this.fallback,
      {this.source});
}

String normalizeAr(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) continue;
    switch (r) {
      case 0x0623:
      case 0x0625:
      case 0x0622:
      case 0x0671:
        b.writeCharCode(0x0627);
        break;
      case 0x0649:
        b.writeCharCode(0x064A);
        break;
      case 0x0629:
        b.writeCharCode(0x0647);
        break;
      default:
        b.writeCharCode(r);
    }
  }
  return b.toString().toLowerCase();
}

class SearchHit {
  final int b;
  final int c;
  final int v;
  final String text;
  final String? source;
  const SearchHit(this.b, this.c, this.v, this.text, {this.source});
}

class BibleRepo {
  BibleRepo({AssetBundle? bundle, bool preferChapterAssets = kIsWeb})
      : _bundle = bundle ?? rootBundle,
        _preferChapterAssets = preferChapterAssets;

  final AssetBundle _bundle;
  final bool _preferChapterAssets;
  final Map<String, Future<List<String>?>> _chapters = {};
  // Cache the future, including misses, so concurrent readers share decoding.
  final Map<String, Future<List<List<String>>?>> _cache = {};
  final _searchChapters = Expando<_SearchChapter>();

  Future<List<List<String>>?> _book(String tr, int b) {
    final k = '$tr/$b';
    return _cache.putIfAbsent(k, () => _loadBook(tr, b));
  }

  Future<List<List<String>>?> _loadBook(String tr, int b) async {
    List<List<String>>? out;
    try {
      final raw = await _bundle.loadString('assets/bible/$tr/$b.json');
      final j = jsonDecode(raw) as List;
      out = j
          .map<List<String>>(
            (c) => (c as List).map((e) => e.toString()).toList(),
          )
          .toList();
    } catch (_) {
      out = null;
    }
    return out;
  }

  Future<List<String>?> _verses(String tr, int b, int c) {
    return _chapters.putIfAbsent('$tr/$b/$c', () async {
      if (_preferChapterAssets) {
        try {
          final raw =
              await _bundle.loadString('assets/bible/chapters/$tr-$b-$c.json');
          return (jsonDecode(raw) as List).cast<String>();
        } catch (_) {
          // Older offline releases and native builds can use whole-book assets.
        }
      }
      final book = await _book(tr, b);
      return book != null && c >= 1 && c <= book.length ? book[c - 1] : null;
    });
  }

  Future<ChapterText?> chapter(int b, int c, String tr) async {
    if (tr == 'gna' || tr == 'jesuit') {
      if (b == kPsalms && c == 151) {
        final verses = await _verses('ar_extra', 151, 1);
        return verses == null
            ? null
            : ChapterText(verses, 'svd', true, source: 'psalm151-ar');
      }
      if (kDeut.contains(b)) {
        final verses = await _verses('ar_extra', b, c);
        if (verses == null) return null;
        return ChapterText(
            verses, b == 46 ? 'svd' : 'jesuit', tr == 'gna' || b == 46,
            source: b == 46 ? 'manasseh-ar' : 'jesuit-old');
      }
      if (tr == 'jesuit') return null;
      final verses = await _verses('gna', b, c);
      return verses == null
          ? null
          : ChapterText(verses, 'gna', false, source: 'gna');
    }
    if (b == kPsalms && c == 151) {
      if (tr == 'svd') {
        final ar = await _verses('ar_extra', 151, 1);
        if (ar != null) {
          return ChapterText(ar, 'svd', false, source: 'psalm151-ar');
        }
      }
      if (tr == 'web') {
        final web = await _verses('web', b, 151);
        if (web != null) {
          return ChapterText(web, 'web', false);
        }
      }
      final extra = await _verses('kjv', 151, 1);
      if (extra != null) {
        return ChapterText(extra, 'kjv', tr != 'kjv');
      }
      return null;
    }
    if (tr == 'svd') {
      var bk = await _verses(kDeut.contains(b) ? 'ar_extra' : 'svd', b, c);
      bk ??= await _verses(kDeut.contains(b) ? 'svd' : 'ar_extra', b, c);
      if (bk != null) {
        return ChapterText(bk, 'svd', false,
            source: kDeut.contains(b)
                ? (b == 46 ? 'manasseh-ar' : 'jesuit-old')
                : 'svd');
      }
      final k = await _verses('kjv', b, c);
      if (k != null) {
        return ChapterText(k, 'kjv', true);
      }
      return null;
    }
    final requested = await _verses(tr, b, c);
    if (requested != null) {
      return ChapterText(requested, tr, false);
    }
    return null;
  }

  Future<int> verseCount(int b, int c) async {
    final r = await chapter(b, c, 'kjv');
    return r?.verses.length ?? 20;
  }

  Future<List<SearchHit>> search(String q, String tr, {int limit = 200}) async {
    final out = <SearchHit>[];
    final query = isArabicTranslation(tr)
        ? normalizeAr(q.trim())
        : q.trim().toLowerCase();
    if (query.length < 2) return out;
    final skipFallback =
        isArabicTranslation(tr) && RegExp(r'[؀-ۿ]').hasMatch(q);
    final slice = Stopwatch()..start();
    var scanned = 0;
    for (var b = 0; b < kBookCount; b++) {
      if (tr == 'jesuit' && !kDeut.contains(b) && b != kPsalms) continue;
      var t = tr;
      var bk = await _book(
          isArabicTranslation(t) && kDeut.contains(b) ? 'ar_extra' : t, b);
      if ((tr == 'gna' || tr == 'jesuit') && b == kPsalms) {
        final extra = await _book('ar_extra', 151);
        final normal =
            tr == 'jesuit' ? List<List<String>>.filled(150, const []) : bk;
        if (normal != null && extra != null && extra.isNotEmpty) {
          bk = [...normal.take(150), extra.first];
        }
      }
      if (bk == null) {
        if (tr == 'gna' || tr == 'jesuit') continue;
        t = 'kjv';
        bk = await _book(t, b);
        if (bk == null) continue;
        // only search the fallback with the query if it's latin
        if (skipFallback) continue;
      }
      for (var c = 0; c < bk.length; c++) {
        final vs = bk[c];
        var index = _searchChapters[vs];
        if (index == null ||
            index.arabic != isArabicTranslation(t) ||
            index.source.length != vs.length) {
          index = _SearchChapter(vs.length, isArabicTranslation(t));
          _searchChapters[vs] = index;
        }
        for (var v = 0; v < vs.length; v++) {
          // Completed asset futures only yield to microtasks. Give the event
          // loop a turn during long scans so frames and input can progress.
          if (++scanned % 256 == 0 && slice.elapsedMilliseconds >= 4) {
            await Future<void>.delayed(Duration.zero);
            slice.reset();
          }
          final txt = index.text(vs[v], v);
          if (txt.isEmpty) continue;
          if (txt.contains(query)) {
            out.add(SearchHit(b, c + 1, v + 1, vs[v],
                source:
                    (tr == 'gna' || tr == 'jesuit') && b == kPsalms && c == 150
                        ? 'psalm151-ar'
                        : isArabicTranslation(tr) && kDeut.contains(b)
                            ? (b == 46 ? 'manasseh-ar' : 'jesuit-old')
                            : t));
            if (out.length >= limit) return out;
          }
        }
      }
    }
    return out;
  }
}

// Built only for chapters actually searched; limited searches normalize only
// the verses they visit. Keep source values to respect the mutable verses API.
class _SearchChapter {
  _SearchChapter(int length, this.arabic)
      : source = List<String?>.filled(length, null),
        normalized = List<String?>.filled(length, null);

  final bool arabic;
  final List<String?> source;
  final List<String?> normalized;

  String text(String verse, int index) {
    if (source[index] != verse) {
      source[index] = verse;
      normalized[index] = arabic ? normalizeAr(verse) : verse.toLowerCase();
    }
    return normalized[index]!;
  }
}
