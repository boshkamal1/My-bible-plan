import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/books.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'reader_screen.dart';
import 'theme.dart';

class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final groups = [...kOtGroups, ...kNtGroups];
    return Scaffold(
      appBar: AppBar(title: Text(tr('books'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final g in groups)
            if (g.books.isNotEmpty)
              Card(
                child: ExpansionTile(
                  shape: const Border(),
                  title: Text(tr('bookGroup_${g.id}'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: [
                    for (final b in g.books)
                      ListTile(
                        title: Text(s.bookName(b)),
                        subtitle: LinearProgressIndicator(
                            value: _prog(s, b), color: kGold, minHeight: 4),
                        trailing: Text(nf(kChapters[b])),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ChapterGrid(b: b))),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  double _prog(AppState s, int b) {
    var n = 0;
    final pre = s.plan?.pre[b] ?? 0;
    for (var c = 1; c <= kChapters[b]; c++) {
      if (s.isDone('$b:$c') || c <= pre) n++;
    }
    return n / kChapters[b];
  }
}

class ChapterGrid extends StatelessWidget {
  final int b;
  const ChapterGrid({super.key, required this.b});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(s.bookName(b))),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 64, mainAxisSpacing: 10, crossAxisSpacing: 10),
        itemCount: kChapters[b],
        itemBuilder: (ctx, i) {
          final c = i + 1;
          final d = s.isDone('$b:$c');
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ReaderScreen(b: b, c: c))),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: d ? Colors.green.withValues(alpha: 0.25) : null,
                border: Border.all(
                    color: d ? Colors.green : kGold.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(nf(c),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }
}
