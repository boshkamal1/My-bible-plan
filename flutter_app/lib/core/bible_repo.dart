import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'books.dart';

class ChapterText {
  final List<String> verses;
  final String translation; // translation actually shown
  final bool fallback; // true when the requested translation was not available
  const ChapterText(this.verses, this.translation, this.fallback);
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
  const SearchHit(this.b, this.c, this.v, this.text);
}

class BibleRepo {
  BibleRepo({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
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

  Future<ChapterText?> chapter(int b, int c, String tr) async {
    if (b == kPsalms && c == 151) {
      if (tr == 'svd') {
        final ar = await _book('ar_extra', 151);
        if (ar != null && ar.isNotEmpty) {
          return ChapterText(ar.first, 'svd', false);
        }
      }
      if (tr == 'web') {
        final web = await _book('web', b);
        if (web != null && web.length >= 151) {
          return ChapterText(web[150], 'web', false);
        }
      }
      final extra = await _book('kjv', 151);
      if (extra != null && extra.isNotEmpty) {
        return ChapterText(extra.first, 'kjv', tr != 'kjv');
      }
      return null;
    }
    if (tr == 'svd') {
      var bk = await _book('svd', b);
      bk ??= await _book('ar_extra', b);
      if (bk != null && c >= 1 && c <= bk.length) {
        return ChapterText(bk[c - 1], 'svd', false);
      }
      final k = await _book('kjv', b);
      if (k != null && c >= 1 && c <= k.length) {
        return ChapterText(k[c - 1], 'kjv', true);
      }
      return null;
    }
    final requested = await _book(tr, b);
    if (requested != null && c >= 1 && c <= requested.length) {
      return ChapterText(requested[c - 1], tr, false);
    }
    return null;
  }

  Future<int> verseCount(int b, int c) async {
    final r = await chapter(b, c, 'kjv');
    return r?.verses.length ?? 20;
  }

  Future<List<SearchHit>> search(String q, String tr, {int limit = 200}) async {
    final out = <SearchHit>[];
    final query = tr == 'svd' ? normalizeAr(q.trim()) : q.trim().toLowerCase();
    if (query.length < 2) return out;
    final skipFallback = tr == 'svd' && RegExp(r'[؀-ۿ]').hasMatch(q);
    final slice = Stopwatch()..start();
    var scanned = 0;
    for (var b = 0; b < kBookCount; b++) {
      var t = tr;
      var bk = await _book(t == 'svd' && kDeut.contains(b) ? 'ar_extra' : t, b);
      if (bk == null) {
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
            index.arabic != (t == 'svd') ||
            index.source.length != vs.length) {
          index = _SearchChapter(vs.length, t == 'svd');
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
            out.add(SearchHit(b, c + 1, v + 1, vs[v]));
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
