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

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _english = st.translation == 'kjv' ? 'kjv' : 'web';
    _arChapter = math.min(widget.c, bookChapterCount(widget.b, 'svd'));
    _enChapter = math.min(widget.c, bookChapterCount(widget.b, _english));
    _loadArabic();
    _loadEnglish();
  }

  void _loadArabic() => _arabicText =
      context.read<AppState>().repo.chapter(widget.b, _arChapter, 'svd');
  void _loadEnglish() => _englishText =
      context.read<AppState>().repo.chapter(widget.b, _enChapter, _english);

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
        });
      },
    );
  }

  Widget _pane(bool arabic, double font) => Expanded(
          child: Column(children: [
        Padding(
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
        Expanded(
            child: FutureBuilder<ChapterText?>(
          future: arabic ? _arabicText : _englishText,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            final text = snapshot.data;
            if (text == null)
              return Center(
                  child:
                      Text(gEn ? 'Chapter unavailable' : 'الأصحاح غير متاح'));
            if (arabic && text.translation != 'svd')
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(gEn
                          ? 'Arabic text is unavailable for this chapter.'
                          : 'النص العربي غير متاح للأصحاح ده.')));
            return Directionality(
                textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
                child: ListView.builder(
                  key: ValueKey(
                      '${arabic ? 'svd' : _english}-${arabic ? _arChapter : _enChapter}'),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                  itemCount: text.verses.length,
                  itemBuilder: (context, i) => text.verses[i].isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SelectableText('${i + 1}  ${text.verses[i]}',
                              style: TextStyle(fontSize: font, height: 1.8))),
                ));
          },
        )),
      ]));

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
                        ? 'Numbering can differ between editions. Choose each chapter independently; matching row positions do not imply matching verses.'
                        : 'ترقيم الأصحاحات والآيات قد يختلف بين الترجمات. اختار أصحاح كل ترجمة بنفسك؛ مكان الآية في العمودين مش معناه تطابقها.')
                    : (gEn
                        ? 'Read both translations side by side. Each column scrolls independently.'
                        : 'اقرأ الترجمتين جنب بعض. تقدر تمرّر كل عمود وتختار أصحاحه بشكل مستقل.'),
                style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
            child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _pane(false, font),
                      const VerticalDivider(width: 1),
                      Directionality(
                          textDirection: TextDirection.rtl,
                          child: _pane(true, font)),
                    ]))),
      ]),
    );
  }
}
