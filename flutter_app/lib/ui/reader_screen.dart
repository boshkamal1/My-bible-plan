import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/bible_repo.dart';
import '../core/books.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'route_observer.dart';
import 'comparison_screen.dart';

class ReaderScreen extends StatefulWidget {
  final int b;
  final int c;
  final List<Chap>? queue;
  final int? scrollToVerse;
  const ReaderScreen({
    super.key,
    required this.b,
    required this.c,
    this.queue,
    this.scrollToVerse,
  });
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver, RouteAware {
  late int b = widget.b;
  late int c = widget.c;
  ChapterText? text;
  bool loading = true;
  int _loadRevision = 0;
  final Stopwatch _sw = Stopwatch();
  Timer? _timeTick;
  ModalRoute<dynamic>? _route;
  bool _routeVisible = true;
  bool _appActive = true;
  final ScrollController _sc = ScrollController();
  late AppState _st;
  final Map<int, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (_appActive) _sw.start();
    _timeTick =
        Timer.periodic(const Duration(seconds: 30), (_) => _recordTime());
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _st = context.read<AppState>();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) readerRouteObserver.unsubscribe(this);
      _route = route;
      readerRouteObserver.subscribe(this, route);
    }
  }

  void _recordTime() {
    final seconds = _sw.elapsed.inSeconds;
    if (seconds > 0) {
      _sw.reset();
      _st.addSeconds(seconds);
    }
  }

  void _updateTimer() {
    if (_routeVisible && _appActive) {
      _sw.start();
    } else {
      _sw.stop();
      _recordTime();
    }
  }

  @override
  void didPushNext() {
    _routeVisible = false;
    _updateTimer();
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    _updateTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _updateTimer();
  }

  @override
  void dispose() {
    _timeTick?.cancel();
    _sw.stop();
    _recordTime();
    readerRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _sc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    final revision = ++_loadRevision;
    final book = b, chapter = c;
    final translation = st.translation;
    setState(() => loading = true);
    final r = await st.repo.chapter(book, chapter, translation);
    if (!mounted || revision != _loadRevision) return;
    setState(() {
      text = r;
      loading = false;
    });
    if (_sc.hasClients) _sc.jumpTo(0);
    final sv = widget.scrollToVerse;
    if (sv != null && b == widget.b && c == widget.c) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[sv]?.currentContext;
        if (ctx != null)
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
          );
      });
    }
  }

  int get _qi => widget.queue == null
      ? -1
      : widget.queue!.indexWhere((x) => x.b == b && x.c == c);

  bool get _hasNext {
    final q = widget.queue;
    if (q != null && _qi >= 0) return _qi < q.length - 1;
    return !(b == kBookCount - 1 && c == bookChapterCount(b, _st.translation));
  }

  bool get _hasPrev {
    final q = widget.queue;
    if (q != null && _qi >= 0) return _qi > 0;
    return !(b == 0 && c == 1);
  }

  void _go(int dir) {
    final q = widget.queue;
    if (q != null && _qi >= 0) {
      final n = q[_qi + dir];
      b = n.b;
      c = n.c;
    } else if (dir > 0) {
      if (c < bookChapterCount(b, _st.translation)) {
        c++;
      } else {
        b++;
        c = 1;
      }
    } else {
      if (c > 1) {
        c--;
      } else {
        b--;
        c = bookChapterCount(b, _st.translation);
      }
    }
    _load();
  }

  String _ref(int v) {
    final st = context.read<AppState>();
    final shown = displayChapterNumber(b, c, st.translation);
    final book = b == 48 && st.translation == 'web'
        ? (gEn ? 'Esther (Greek)' : 'أستير اليوناني')
        : st.bookName(b);
    final name = b == kPsalms ? '${tr('psalm')} $c' : '$book $shown';
    return b == kPsalms ? '$name:$v' : '$name:$v';
  }

  void _verseSheet(int v, String verse) {
    final st = context.read<AppState>();
    final vk = '$b:$c:$v';
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final cur = st.hl[vk];
          final isFav = st.fav.contains(vk);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _ref(v),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < kHlColors.length; i++)
                        GestureDetector(
                          onTap: () {
                            st.setHighlight(vk, cur == i ? null : i);
                            setM(() {});
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: kHlColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: cur == i ? 3 : 1,
                                color:
                                    cur == i ? Colors.black54 : Colors.black12,
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.format_color_reset),
                        onPressed: () {
                          st.setHighlight(vk, null);
                          setM(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: Icon(isFav ? Icons.star : Icons.star_border),
                        label: Text(tr('favorite')),
                        onPressed: () {
                          st.toggleFav(vk);
                          setM(() {});
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.edit_note),
                        label: Text(tr('note')),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _noteDialog(vk);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.copy),
                        label: Text(tr('copy')),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: '$verse\n— ${_ref(v)}'),
                          );
                          Navigator.pop(ctx);
                          toast(context, tr('copied'));
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.share),
                        label: Text(tr('share')),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Share.share('$verse\n— ${_ref(v)}');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _noteDialog(String vk) async {
    final st = context.read<AppState>();
    final ctl = TextEditingController(text: st.notes[vk] ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('note')),
        content: TextField(controller: ctl, maxLines: 5, autofocus: true),
        actions: [
          if (st.notes.containsKey(vk))
            TextButton(
              onPressed: () {
                st.setNote(vk, '');
                Navigator.pop(ctx);
              },
              child: Text(tr('delete')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              st.setNote(vk, ctl.text);
              Navigator.pop(ctx);
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final key = '$b:$c';
    final done = st.isDone(key);
    final t = text;
    final shownChapter =
        displayChapterNumber(b, c, t?.translation ?? st.translation);
    final title = b == 48 && (t?.translation ?? st.translation) == 'web'
        ? '${gEn ? 'Esther (Greek)' : 'أستير اليوناني'} ${nf(shownChapter)}'
        : b == kPsalms
            ? '${tr('psalm')} ${nf(c)}'
            : '${st.bookName(b)} ${nf(shownChapter)}';
    final rtl = t == null ? !st.en : t.translation == 'svd';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip:
                gEn ? 'Compare Arabic and English' : 'مقارنة العربي والإنجليزي',
            icon: const Icon(Icons.view_column_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ComparisonScreen(b: b, c: c))),
          ),
          PopupMenuButton<String>(
            tooltip: tr('translation'),
            icon: const Icon(Icons.translate),
            onSelected: (value) {
              st.setTranslation(value);
              if (c > bookChapterCount(b, value)) {
                c = bookChapterCount(b, value);
              }
              _load();
            },
            itemBuilder: (_) => [
              for (final id in ['svd', 'kjv', 'web'])
                PopupMenuItem(value: id, child: Text(tr(id))),
            ],
          ),
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields),
            onSelected: (v) => st.setFont(v),
            itemBuilder: (_) => [
              for (final f in [16.0, 18.0, 20.0, 22.0, 26.0, 30.0])
                PopupMenuItem(
                  value: f,
                  child: Text('${f.toInt()}${st.fontSize == f ? '  ✓' : ''}'),
                ),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : t == null
              ? Center(child: Text(tr('error')))
              : Column(
                  children: [
                    if (b == 48 && t.translation == 'web')
                      Container(
                        width: double.infinity,
                        color: kGold.withValues(alpha: 0.15),
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          gEn
                              ? 'WEB presents Greek Esther as a complete book with its additions; its chapter numbering differs from the Arabic edition.'
                              : 'تقدم ترجمة WEB أستير اليوناني كاملًا مع التتمات، ويختلف ترقيمه عن الترجمة العربية.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    if (t.fallback)
                      Container(
                        width: double.infinity,
                        color: kGold.withValues(alpha: 0.15),
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          tr('deutNoteAr'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    Expanded(child: _readingBody(st, t, scheme, rtl)),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _hasPrev ? () => _go(-1) : null,
                            ),
                            Expanded(
                              child: FilledButton.icon(
                                icon: Icon(
                                  done
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                ),
                                label: Text(done ? tr('done') : tr('markDone')),
                                onPressed: () {
                                  st.toggleChapter(key);
                                  if (!done && _hasNext && widget.queue != null)
                                    _go(1);
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _hasNext ? () => _go(1) : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _readingBody(
      AppState st, ChapterText text, ColorScheme scheme, bool rtl) {
    // Targeted links keep eager layout so ensureVisible can reach an exact verse.
    // Ordinary reading builds only visible verses, even in Psalm 119.
    final targeted =
        widget.scrollToVerse != null && b == widget.b && c == widget.c;
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: targeted
          ? SingleChildScrollView(
              controller: _sc,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < text.verses.length; i++)
                      if (text.verses[i].isNotEmpty)
                        _verse(st, i + 1, text.verses[i], scheme),
                  ]))
          : ListView.builder(
              controller: _sc,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              itemCount: text.verses.length,
              itemBuilder: (context, i) => text.verses[i].isEmpty
                  ? const SizedBox.shrink()
                  : _verse(st, i + 1, text.verses[i], scheme)),
    );
  }

  Widget _verse(AppState st, int v, String verse, ColorScheme scheme) {
    final vk = '$b:$c:$v';
    final h = st.hl[vk];
    _keys.putIfAbsent(v, () => GlobalKey());
    return InkWell(
      key: _keys[v],
      borderRadius: BorderRadius.circular(8),
      onTap: () => _verseSheet(v, verse),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: (h != null ? kHlColors[h].withValues(alpha: 0.55) : null),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${nf(v)}  ',
                    style: TextStyle(
                      color: kGold,
                      fontWeight: FontWeight.bold,
                      fontSize: st.fontSize * 0.7,
                    ),
                  ),
                  TextSpan(text: verse),
                  if (st.fav.contains(vk))
                    const TextSpan(
                      text: '  ★',
                      style: TextStyle(color: kGold),
                    ),
                  if (st.notes.containsKey(vk)) const TextSpan(text: '  📝'),
                ],
              ),
              style: TextStyle(
                fontSize: st.fontSize,
                height: 1.8,
                color: h != null ? Colors.black87 : null,
              ),
            ),
            if (st.notes.containsKey(vk))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  st.notes[vk]!,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
