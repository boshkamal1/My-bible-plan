import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../core/translations.dart';
import '../core/bible_repo.dart';
import '../core/books.dart';
import '../state/app_state.dart';
import 'reader_screen.dart';
import 'theme.dart';

class DailyVerseCard extends StatefulWidget {
  const DailyVerseCard({super.key, required this.state});
  final AppState state;

  // A fixed sequence avoids repeating a verse until the whole list has cycled.
  static const _verses = <(int, int, int)>[
    (20, 119, 105),
    (26, 41, 10),
    (52, 14, 27),
    (50, 10, 27),
    (20, 23, 1),
    (54, 8, 28),
    (59, 4, 13),
    (21, 3, 5),
    (49, 11, 28),
    (20, 46, 1),
    (52, 3, 16),
    (26, 40, 31),
    (20, 27, 1),
    (52, 15, 5),
    (5, 1, 9),
    (55, 13, 4),
    (20, 121, 2),
    (21, 16, 3),
    (51, 1, 37),
    (27, 29, 11),
    (20, 34, 8),
    (75, 21, 4),
    (49, 6, 33),
    (20, 91, 1),
    (52, 8, 12),
    (37, 6, 8),
    (20, 139, 14),
    (49, 5, 14),
  ];

  static (int, int, int) verseForDay(int day) => _verses[day % _verses.length];

  static (int, int, int) chooseVerse(int day, List<Chap> readings,
      {(int, int, int)? previous}) {
    final matching = _verses
        .where((v) =>
            v != previous && readings.any((c) => c.b == v.$1 && c.c == v.$2))
        .toList();
    final pool = matching.isNotEmpty
        ? matching
        : _verses.where((v) => v != previous).toList();
    return pool[day % pool.length];
  }

  static (int, int, int) verseForState(AppState state) {
    final saved = state.prefs.getStringList('dailyEncouragementVerse');
    final values = saved?.map(int.tryParse).toList();
    (int, int, int)? old;
    if (values != null &&
        values.length == 4 &&
        values.every((v) => v != null)) {
      old = (values[1]!, values[2]!, values[3]!);
      if (values[0] == state.today && _verses.contains(old)) return old;
      if (values[0] != state.today - 1) old = null;
    }
    final index = state.todayIndexExact;
    final verse = chooseVerse(
        state.today, index < 0 ? const [] : state.chaptersOfDay(index),
        previous: old);
    state.prefs.setStringList('dailyEncouragementVerse',
        ['${state.today}', '${verse.$1}', '${verse.$2}', '${verse.$3}']);
    return verse;
  }

  @override
  State<DailyVerseCard> createState() => _DailyVerseCardState();
}

class _DailyVerseCardState extends State<DailyVerseCard> {
  Future<ChapterText?>? _chapter;
  Object? _chapterKey;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final verse = DailyVerseCard.verseForState(state);
    final key = (state.repo, state.today, state.translation);
    if (key != _chapterKey) {
      _chapterKey = key;
      _chapter = state.repo.chapter(verse.$1, verse.$2, state.translation);
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ReaderScreen(b: verse.$1, c: verse.$2, scrollToVerse: verse.$3),
        )),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: dark
                    ? [const Color(0xFF243858), const Color(0xFF1B2940)]
                    : [const Color(0xFFFFF4D7), const Color(0xFFFFFBF0)]),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: accentColor(context).withValues(alpha: .7)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.auto_awesome, color: accentColor(context), size: 19),
              const SizedBox(width: 8),
              Text(gEn ? 'Verse of the day' : 'آية اليوم',
                  style: TextStyle(
                      color: accentColor(context),
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            FutureBuilder(
              future: _chapter,
              builder: (context, snapshot) {
                final chapter = snapshot.data;
                if (chapter == null) {
                  return snapshot.connectionState == ConnectionState.done
                      ? Text(translationUnavailable(state.translation),
                          textAlign: TextAlign.center)
                      : CircularProgressIndicator(color: accentColor(context));
                }
                if (chapter.verses.length < verse.$3 ||
                    chapter.verses[verse.$3 - 1].isEmpty) {
                  return Text(gEn ? 'Verse unavailable' : 'الآية غير متاحة');
                }
                final text = chapter.verses[verse.$3 - 1];
                final reference = bibleReference(
                    state.bookName(verse.$1), verse.$2, verse.$3);
                return Column(children: [
                  Text('«$text»',
                      textAlign: TextAlign.center,
                      textDirection: isArabicTranslation(chapter.translation)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(height: 1.7)),
                  const SizedBox(height: 14),
                  Text(reference,
                      style: TextStyle(
                          color: accentColor(context),
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: Icon(Icons.ios_share, size: 18),
                      label: Text(gEn ? 'Share verse' : 'مشاركة الآية'),
                      onPressed: () async {
                        final content = '$text\n— $reference';
                        try {
                          await Share.share(content);
                        } catch (_) {
                          await Clipboard.setData(ClipboardData(text: content));
                          if (context.mounted) toast(context, tr('copied'));
                        }
                      },
                    ),
                  ),
                ]);
              },
            ),
          ]),
        ),
      ),
    );
  }
}
