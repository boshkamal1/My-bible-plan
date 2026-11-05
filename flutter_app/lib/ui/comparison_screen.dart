import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/bible_repo.dart';
import '../core/books.dart';
import '../core/i18n.dart';
import '../core/translations.dart';
import 'translation_sources_screen.dart';
import '../state/app_state.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key, required this.b, required this.c});
  final int b;
  final int c;
  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  late int _chapter;
  late String _left;
  late String _right;
  late Future<ChapterText?> _rightText;
  late Future<ChapterText?> _leftText;
  late Future<List<ChapterText?>> _texts;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _right = st.translation;
    _left = isArabicTranslation(_right) ? 'web' : 'svd';
    _chapter = math.min(widget.c, _chapterCount);
    _loadRight();
    _loadLeft();
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadRight() => _rightText =
      context.read<AppState>().repo.chapter(widget.b, _chapter, _right);
  void _loadLeft() => _leftText =
      context.read<AppState>().repo.chapter(widget.b, _chapter, _left);

  void _refresh() {
    _texts = Future.wait([_rightText, _leftText]);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  int get _chapterCount => math.max(
      bookChapterCount(widget.b, _right), bookChapterCount(widget.b, _left));

  Widget _chapterChoice() => SizedBox(
        width: 200,
        child: DropdownButton<int>(
          key: const ValueKey('comparison-chapter'),
          isExpanded: true,
          isDense: true,
          value: _chapter,
          items: [
            for (var c = 1; c <= _chapterCount; c++)
              DropdownMenuItem(
                value: c,
                child: Text(_chapterLabel(c),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14)),
              ),
          ],
          onChanged: (c) {
            if (c == null) return;
            setState(() {
              _chapter = c;
              _loadRight();
              _loadLeft();
              _refresh();
            });
          },
        ),
      );

  String _chapterLabel(int c) {
    final right = c <= bookChapterCount(widget.b, _right)
        ? displayChapterNumber(widget.b, c, _right).toString()
        : '—';
    final left = c <= bookChapterCount(widget.b, _left)
        ? displayChapterNumber(widget.b, c, _left).toString()
        : '—';
    final label = gEn ? 'Chapter' : 'أصحاح';
    return right == left ? '$label $right' : '$label $right / $left';
  }

  Widget _header(bool right) {
    final selected = right ? _right : _left;
    return Expanded(
        child: Directionality(
      textDirection:
          isArabicTranslation(selected) ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Column(children: [
            DropdownButton<String>(
                key: ValueKey(right
                    ? 'comparison-right-translation'
                    : 'comparison-left-translation'),
                value: selected,
                isExpanded: true,
                isDense: true,
                items: [
                  for (final id in kTranslationIds)
                    DropdownMenuItem(
                        value: id,
                        child: Tooltip(
                            message: tr(id),
                            child: Text(tr(id),
                                maxLines: 2,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis)))
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    if (right) {
                      _right = value;
                    } else {
                      _left = value;
                    }
                    _chapter = math.min(_chapter, _chapterCount);
                    _loadRight();
                    _loadLeft();
                    _refresh();
                  });
                }),
            SizedBox(
                height: 24,
                child: Center(
                    child: Text(
                        widget.b == 48 && selected == 'web'
                            ? (gEn ? 'Esther (Greek)' : 'أستير اليوناني')
                            : isArabicTranslation(selected)
                                ? kArNames[widget.b]
                                : kEnNames[widget.b],
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center))),
          ])),
    ));
  }

  Widget _verse(bool right, ChapterText? text, int i, double font) {
    final selected = right ? _right : _left;
    final arabic = isArabicTranslation(text?.translation ?? selected);
    final verse = text != null && i < text.verses.length ? text.verses[i] : '';
    final note = translationSourceNote(selected, text?.source, widget.b);
    return Expanded(
        child: Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (i == 0 && note != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(note, style: const TextStyle(fontSize: 12))),
            if (text == null && i == 0)
              Text(translationUnavailable(selected))
            else if (verse.isNotEmpty)
              SelectableText(
                  '${editionVerseLabel(widget.b, _chapter, i + 1, text?.translation ?? selected)}  $verse',
                  key: ValueKey(
                      'comparison-${right ? 'right' : 'left'}-${i + 1}'),
                  style: TextStyle(fontSize: font, height: 1.8)),
          ])),
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
          if (count == 0) {
            return Center(
                child: Text(translationUnavailable(
                    _right == 'jesuit' || _left == 'jesuit'
                        ? 'jesuit'
                        : _right)));
          }
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
          title: Text(gEn ? 'Compare translations' : 'مقارنة الترجمات'),
          actions: [
            PopupMenuButton<double>(
              key: const ValueKey('comparison-font'),
              tooltip: gEn ? 'Font size' : 'حجم الخط',
              icon: const Icon(Icons.text_fields),
              onSelected: (value) => context.read<AppState>().setFont(value),
              itemBuilder: (_) => [
                for (final size in [16.0, 18.0, 20.0, 22.0, 26.0, 30.0])
                  PopupMenuItem(
                    value: size,
                    child: Text('${size.toInt()}${font == size ? '  ✓' : ''}'),
                  ),
              ],
            ),
            IconButton(
                tooltip: gEn ? 'Text sources' : 'مصادر النصوص',
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const TranslationSourcesScreen()))),
          ]),
      body: Column(children: [
        if (_left == 'gna' || _right == 'gna')
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child:
                  Text(gnaAttribution, style: const TextStyle(fontSize: 10))),
        Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [
              _header(false),
              SizedBox(
                  height: 56,
                  width: 1,
                  child: ColoredBox(color: Theme.of(context).dividerColor)),
              _header(true)
            ])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: _chapterChoice(),
        ),
        Expanded(child: _reading(font)),
      ]),
    );
  }
}
