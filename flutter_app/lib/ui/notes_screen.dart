import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/books.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'reader_screen.dart';
import 'theme.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('notes')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('notes')),
              Tab(text: tr('favorites')),
              Tab(text: tr('highlights')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_List(kind: 0), _List(kind: 1), _List(kind: 2)],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final int kind;
  const _List({required this.kind});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final keys =
        (kind == 0
                ? s.notes.keys
                : kind == 1
                ? s.fav
                : s.hl.keys)
            .toList();
    keys.sort((a, b) {
      final x = a.split(':').map(int.parse).toList();
      final y = b.split(':').map(int.parse).toList();
      for (var i = 0; i < 3; i++) {
        if (x[i] != y[i]) return x[i] - y[i];
      }
      return 0;
    });
    if (keys.isEmpty) return Center(child: Text(tr('noResults')));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: keys.length,
      itemBuilder: (ctx, i) {
        final k = keys[i];
        final p = k.split(':').map(int.parse).toList();
        final name = p[0] == kPsalms ? tr('psalm') : s.bookName(p[0]);
        return Card(
          child: ListTile(
            leading: kind == 2
                ? CircleAvatar(radius: 10, backgroundColor: kHlColors[s.hl[k]!])
                : null,
            title: Text(
              '$name ${nf(p[1])}:${nf(p[2])}',
              style: const TextStyle(color: kGold, fontWeight: FontWeight.bold),
            ),
            subtitle: kind == 0 ? Text(s.notes[k]!) : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                if (kind == 0) s.setNote(k, '');
                if (kind == 1) s.toggleFav(k);
                if (kind == 2) s.setHighlight(k, null);
              },
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ReaderScreen(b: p[0], c: p[1], scrollToVerse: p[2]),
              ),
            ),
          ),
        );
      },
    );
  }
}
