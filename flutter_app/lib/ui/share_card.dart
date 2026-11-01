import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../state/app_state.dart';
import 'theme.dart';

class ShareProgressScreen extends StatefulWidget {
  const ShareProgressScreen({super.key});
  @override
  State<ShareProgressScreen> createState() => _ShareProgressScreenState();
}

class _ShareProgressScreenState extends State<ShareProgressScreen> {
  final GlobalKey _k = GlobalKey();
  bool busy = false;

  Future<void> _share() async {
    setState(() => busy = true);
    try {
      final b = _k.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/progress.png');
      await f.writeAsBytes(data!.buffer.asUint8List());
      await Share.shareXFiles([XFile(f.path)], text: tr('shareText'));
    } catch (_) {
      if (mounted) toast(context, tr('error'));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final st = s.streak;
    return Scaffold(
      appBar: AppBar(title: Text(tr('shareProgress'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            RepaintBoundary(
              key: _k,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                      colors: [kNavy, Color(0xFF3A4A78)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: Column(children: [
                  const Icon(Icons.auto_stories, color: kGold, size: 44),
                  const SizedBox(height: 8),
                  Text(tr('appName'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                            value: s.percent,
                            strokeWidth: 12,
                            color: kGold,
                            backgroundColor: Colors.white24),
                      ),
                      Text('${nf((s.percent * 100).round())}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _stat('🔥', nf(st.cur), tr('streak')),
                        _stat('📖', nf(s.totalDone), tr('chaptersRead')),
                        _stat('🎖️', nf(s.booksFinished), tr('books')),
                      ]),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.share),
              label: Text(tr('share')),
              onPressed: busy ? null : _share,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _stat(String e, String v, String l) => Column(children: [
        Text(e, style: const TextStyle(fontSize: 24)),
        Text(v,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]);
}
