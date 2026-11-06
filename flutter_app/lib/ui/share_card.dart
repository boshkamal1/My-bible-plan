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
  Uint8List? _preparedImage;
  Object? _cardVersion;
  int _captureRevision = 0;
  bool _preparing = true;
  bool _captureFailed = false;

  void _prepareImage() {
    final revision = ++_captureRevision;
    _preparedImage = null;
    _preparing = true;
    _captureFailed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // The first route frame can still be offstage during its entrance.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted || revision != _captureRevision) return;
      try {
        final png = await _image();
        if (!mounted || revision != _captureRevision) return;
        setState(() {
          _preparedImage = png;
          _preparing = false;
        });
      } catch (_) {
        if (!mounted || revision != _captureRevision) return;
        setState(() {
          _preparing = false;
          _captureFailed = true;
        });
      }
    });
  }

  Future<Uint8List> _image() async {
    final b = _k.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 3);
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG capture failed');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      img.dispose();
    }
  }

  Future<void> _share({bool save = false}) async {
    final png = _preparedImage;
    if (busy || png == null) return;
    setState(() => busy = true);
    try {
      // The PNG is ready before the tap: web download/share retains the user's
      // activation instead of awaiting asynchronous rasterization first.
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
    final version = (
      s.lang,
      s.hasPlan,
      s.percent,
      s.totalDone,
      s.booksFinished,
      st.cur,
      todayNum(),
      MediaQuery.sizeOf(context).width,
      MediaQuery.textScalerOf(context).scale(22)
    );
    if (_cardVersion != version) {
      _cardVersion = version;
      _prepareImage();
    }
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
              if (_preparing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(gEn ? 'Preparing image…' : 'بنجهّز الصورة…'),
                ),
              if (_captureFailed)
                TextButton.icon(
                  onPressed: () => setState(_prepareImage),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                      gEn ? 'Retry preparing image' : 'جرّب تجهيز الصورة تاني'),
                ),
              FilledButton.icon(
                icon: const Icon(Icons.share),
                label: Text(tr('share')),
                onPressed: busy || _preparedImage == null ? null : _share,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: Text(gEn ? 'Save image' : 'حفظ الصورة'),
                onPressed: busy || _preparedImage == null
                    ? null
                    : () => _share(save: true),
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
