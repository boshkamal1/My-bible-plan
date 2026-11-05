import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/bible_repo.dart';
import '../core/books.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key, required this.b, required this.c});
  final int b;
  final int c;
  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  late int _arChapter;
  late int _enChapter;
  late String _english;
  late Future<ChapterText?> _arabicText;
  late Future<ChapterText?> _englishText;
  late Future<List<ChapterText?>> _texts;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _english = st.translation == 'kjv' ? 'kjv' : 'web';
    _arChapter = math.min(widget.c, bookChapterCount(widget.b, 'svd'));
    _enChapter = math.min(widget.c, bookChapterCount(widget.b, _english));
    _loadArabic();
    _loadEnglish();
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadArabic() => _arabicText =
      context.read<AppState>().repo.chapter(widget.b, _arChapter, 'svd');
  void _loadEnglish() => _englishText =
      context.read<AppState>().repo.chapter(widget.b, _enChapter, _english);

  void _refresh() {
    _texts = Future.wait([_arabicText, _englishText]);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _chapterChoice(bool arabic) {
    final trId = arabic ? 'svd' : _english;
    return DropdownButton<int>(
      key: ValueKey(arabic ? 'arabic-chapter' : 'english-chapter'),
      isExpanded: true,
      value: arabic ? _arChapter : _enChapter,
      items: [
        for (var c = 1; c <= bookChapterCount(widget.b, trId); c++)
          DropdownMenuItem(
              value: c,
              child: Text(arabic
                  ? 'أصحاح ${nf(displayChapterNumber(widget.b, c, trId))}'
                  : 'Chapter ${displayChapterNumber(widget.b, c, trId)}'))
      ],
      onChanged: (c) {
        if (c == null) return;
        setState(() {
          if (arabic) {
            _arChapter = c;
            _loadArabic();
          } else {
            _enChapter = c;
            _loadEnglish();
          }
          _refresh();
        });
      },
    );
  }

  Widget _header(bool arabic) => Expanded(
          child: Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(children: [
              if (arabic)
                SizedBox(
                    height: 48,
                    child: Center(
                        child: Text(tr('svd'),
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))))
              else
                DropdownButton<String>(
                    key: const ValueKey('comparison-translation'),
                    value: _english,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'web', child: Text('WEB')),
                      DropdownMenuItem(value: 'kjv', child: Text('KJV'))
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _english = value;
                        _enChapter = math.min(
                            _enChapter, bookChapterCount(widget.b, value));
                        _loadEnglish();
                        _refresh();
                      });
                    }),
              SizedBox(
                  height: 40,
                  child: Center(
                      child: Text(
                          arabic ? kArNames[widget.b] : kEnNames[widget.b],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center))),
              _chapterChoice(arabic),
            ])),
      ));

  Widget _verse(bool arabic, ChapterText? text, int i, double font) {
    final unavailable = text == null || (arabic && text.translation != 'svd');
    final verse = !unavailable && i < text.verses.length ? text.verses[i] : '';
    return Expanded(
        child: Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
          child: unavailable && i == 0
              ? Text(arabic
                  ? 'النص العربي غير متاح للأصحاح ده.'
                  : 'Chapter unavailable')
              : verse.isEmpty
                  ? const SizedBox.shrink()
                  : SelectableText('${i + 1}  $verse',
                      key: ValueKey(
                          'comparison-${arabic ? 'ar' : 'en'}-${i + 1}'),
                      style: TextStyle(fontSize: font, height: 1.8))),
    ));
  }

  Widget _reading(double font) => FutureBuilder<List<ChapterText?>>(
        future: _texts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final arabic = snapshot.data?[0];
          final english = snapshot.data?[1];
          final count =
              math.max(arabic?.verses.length ?? 0, english?.verses.length ?? 0);
          if (count == 0)
            return Center(
                child: Text(gEn ? 'Chapter unavailable' : 'الأصحاح غير متاح'));
          return Stack(children: [
            ListView.builder(
              key: const ValueKey('comparison-scroll'),
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: count,
              itemBuilder: (context, i) => Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                      key: ValueKey('comparison-row-${i + 1}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _verse(false, english, i, font),
                        const SizedBox(width: 1),
                        _verse(true, arabic, i, font),
                      ])),
            ),
            Positioned.fill(
                child: IgnorePointer(
                    child: Center(
                        child: SizedBox(
                            width: 1,
                            child: ColoredBox(
                                color: Theme.of(context).dividerColor))))),
          ]);
        },
      );

  @override
  Widget build(BuildContext context) {
    final font = context.select<AppState, double>((s) => s.fontSize);
    return Scaffold(
      appBar: AppBar(
          title: Text(gEn ? 'Arabic / English' : 'مقارنة العربي والإنجليزي')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
                widget.b == 48 || widget.b == 47 || kDeut.contains(widget.b)
                    ? (gEn
                        ? 'Both columns scroll together. Numbering may differ between editions; matching row positions do not guarantee equivalent verses.'
                        : 'العمودين بيتحركوا مع بعض. الترقيم قد يختلف بين الترجمات؛ وجود آيتين في نفس الصف مش بالضرورة معناه تطابقهما.')
                    : (gEn
                        ? 'Scroll either column to move both translations together.'
                        : 'مرّر من أي ناحية، العربي والإنجليزي هيتحركوا مع بعض في صفحة واحدة.'),
                style: Theme.of(context).textTheme.bodySmall)),
        Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [
              _header(false),
              SizedBox(
                  height: 144,
                  width: 1,
                  child: ColoredBox(color: Theme.of(context).dividerColor)),
              _header(true)
            ])),
        Expanded(child: _reading(font)),
      ]),
    );
  }
}
