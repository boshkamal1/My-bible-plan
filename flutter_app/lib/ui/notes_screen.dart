import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/books.dart';
import '../core/i18n.dart';
import '../core/translations.dart';
import '../state/app_state.dart';
import 'reader_screen.dart';
import 'theme.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabs == null) {
      final index = PageStorage.maybeOf(context)
              ?.readState(context, identifier: 'notes-tab') as int? ??
          0;
      _tabs = TabController(length: 3, initialIndex: index, vsync: this)
        ..addListener(_saveTab);
    }
  }

  void _saveTab() {
    PageStorage.maybeOf(context)
        ?.writeState(context, _tabs!.index, identifier: 'notes-tab');
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('notes')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: tr('notes')),
            Tab(text: tr('favorites')),
            Tab(text: tr('highlights')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_List(kind: 0), _List(kind: 1), _List(kind: 2)],
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
    final keys = (kind == 0
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
      key: PageStorageKey('notes-list-$kind'),
      padding: const EdgeInsets.all(12),
      itemCount: keys.length,
      itemBuilder: (ctx, i) {
        final k = keys[i];
        final p = k.split(':').map(int.parse).toList();
        final name = p[0] == kPsalms ? tr('psalm') : s.bookName(p[0]);
        final ref = sourceVerseReference(p[0], p[1], p[2], s.translation);
        return Card(
          child: ListTile(
            leading: kind == 2
                ? CircleAvatar(radius: 10, backgroundColor: kHlColors[s.hl[k]!])
                : null,
            title: Text(
              bibleReference(name, ref.chapter, ref.verse),
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
