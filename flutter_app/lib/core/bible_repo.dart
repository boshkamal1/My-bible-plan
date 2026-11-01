import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'books.dart';

class ChapterText {
  final List<String> verses;
  final String translation; // 'svd' or 'kjv' (what is actually shown)
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
  final Map<String, List<List<String>>?> _cache = {};

  Future<List<List<String>>?> _book(String tr, int b) async {
    final k = '$tr/$b';
    if (_cache.containsKey(k)) return _cache[k];
    List<List<String>>? out;
    try {
      final raw = await rootBundle.loadString('assets/bible/$tr/$b.json');
      final j = jsonDecode(raw) as List;
      out = j
          .map<List<String>>(
            (c) => (c as List).map((e) => e.toString()).toList(),
          )
          .toList();
    } catch (_) {
      out = null;
    }
    _cache[k] = out;
    return out;
  }

  Future<ChapterText?> chapter(int b, int c, String tr) async {
    if (tr == 'svd') {
      var bk = await _book('svd', b);
      bk ??= await _book('ar_extra', b);
      if (bk != null && c >= 1 && c <= bk.length)
        return ChapterText(bk[c - 1], 'svd', false);
      final k = await _book('kjv', b);
      if (k != null && c >= 1 && c <= k.length)
        return ChapterText(k[c - 1], 'kjv', true);
      return null;
    }
    final k = await _book('kjv', b);
    if (k != null && c >= 1 && c <= k.length)
      return ChapterText(k[c - 1], 'kjv', false);
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
    for (var b = 0; b < kBookCount; b++) {
      var t = tr;
      var bk = await _book(t, b);
      if (bk == null) {
        t = 'kjv';
        bk = await _book(t, b);
        if (bk == null) continue;
        // only search the fallback with the query if it's latin
        if (tr == 'svd' && RegExp(r'[؀-ۿ]').hasMatch(q)) continue;
      }
      for (var c = 0; c < bk.length; c++) {
        final vs = bk[c];
        for (var v = 0; v < vs.length; v++) {
          final txt = t == 'svd' ? normalizeAr(vs[v]) : vs[v].toLowerCase();
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
