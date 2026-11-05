import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../core/day_util.dart';
import '../services/save_image_stub.dart'
    if (dart.library.io) '../services/save_image_io.dart'
    if (dart.library.js_interop) '../services/save_image_web.dart';
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

  Future<Uint8List> _image() async {
    final b = _k.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> _share({bool save = false}) async {
    setState(() => busy = true);
    try {
      final png = await _image();
      if (save) {
        final path = await saveProgressImage(png);
        if (!kIsWeb && mounted && path != null) {
          toast(context, '${gEn ? 'Saved' : 'اتحفظت الصورة'}: $path');
        }
      } else {
        await Share.shareXFiles(
          [XFile.fromData(png, mimeType: 'image/png', name: 'progress.png')],
          text: tr('shareText'),
        );
      }
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
          child: Column(
            children: [
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
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.auto_stories, color: kGold, size: 44),
                      const SizedBox(height: 8),
                      Text(
                        tr('appName'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dayStr(todayNum()),
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 20),
                      if (s.hasPlan)
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: s.percent,
                                  strokeWidth: 12,
                                  color: kGold,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                              Text(
                                '${nf((s.percent * 100).round())}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _stat('🔥', nf(st.cur), tr('streak')),
                          _stat('📖', nf(s.totalDone), tr('chaptersRead')),
                          _stat('🎖️', nf(s.booksFinished), tr('books')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.share),
                label: Text(tr('share')),
                onPressed: busy ? null : _share,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: Text(gEn ? 'Save image' : 'حفظ الصورة'),
                onPressed: busy ? null : () => _share(save: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String e, String v, String l) => Column(
        children: [
          Text(e, style: const TextStyle(fontSize: 24)),
          Text(
            v,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );
}
