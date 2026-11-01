import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/bible_repo.dart';
import '../core/books.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'reader_screen.dart';
import 'theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  List<SearchHit> hits = [];
  bool busy = false;
  bool searched = false;

  Future<void> _go() async {
    final st = context.read<AppState>();
    setState(() {
      busy = true;
      searched = true;
    });
    final r = await st.repo.search(_ctl.text, st.translation);
    if (!mounted) return;
    setState(() {
      hits = r;
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _go(),
          decoration: InputDecoration(
              hintText: tr('searchHint'), border: InputBorder.none),
        ),
        actions: [
          TextButton(
            onPressed: () {
              st.setTranslation(st.translation == 'svd' ? 'kjv' : 'svd');
              if (_ctl.text.isNotEmpty) _go();
            },
            child: Text(st.translation == 'svd' ? 'SVD' : 'KJV'),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: _go),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : hits.isEmpty
              ? Center(child: Text(searched ? tr('noResults') : ''))
              : ListView.separated(
                  itemCount: hits.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final h = hits[i];
                    final name =
                        h.b == kPsalms ? tr('psalm') : st.bookName(h.b);
                    return ListTile(
                      title: Text('$name ${nf(h.c)}:${nf(h.v)}',
                          style: const TextStyle(
                              color: kGold, fontWeight: FontWeight.bold)),
                      subtitle: Text(h.text,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ReaderScreen(
                              b: h.b, c: h.c, scrollToVerse: h.v))),
                    );
                  },
                ),
    );
  }
}
