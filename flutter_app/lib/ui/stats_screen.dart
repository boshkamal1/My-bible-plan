import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../state/app_state.dart';
import 'share_card.dart';
import 'theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.hasPlan) return const SizedBox();
    final st = s.streak;
    final per = s.chaptersPerDay(30);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('stats')),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: tr('shareProgress'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShareProgressScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _tile(context, '🔥', nf(st.cur), tr('streak')),
              _tile(context, '🏆', nf(st.best), tr('bestStreak')),
              _tile(context, '📖', nf(s.totalDone), tr('chaptersRead')),
            ],
          ),
          Row(
            children: [
              _tile(
                context,
                '⏱',
                nf(s.totalMinutesTracked),
                '${tr('readingTime')} (${tr('minutes')})',
              ),
              _tile(context, '🎖️', nf(s.booksFinished), tr('books')),
              _tile(context, '📅', nf(s.daysLeft), tr('daysLeft')),
            ],
          ),
          const SizedBox(height: 12),
          Text(tr('last30'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 120,
                child: CustomPaint(
                  painter: _Bars(
                    per.values.toList(),
                    kGold,
                    scheme.outlineVariant,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(tr('badges'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
            children: [
              for (final b in s.badges)
                Opacity(
                  opacity: b.earned ? 1 : 0.3,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(b.icon, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            b.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext c, String e, String v, String l) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Text(e, style: const TextStyle(fontSize: 22)),
            Text(
              v,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              l,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Bars extends CustomPainter {
  final List<int> v;
  final Color color;
  final Color base;
  _Bars(this.v, this.color, this.base);
  @override
  void paint(Canvas canvas, Size size) {
    final mx = v.fold<int>(1, (a, b) => b > a ? b : a);
    final w = size.width / v.length;
    final p = Paint()..color = color;
    final q = Paint()..color = base;
    for (var i = 0; i < v.length; i++) {
      final h = v[i] == 0 ? 3.0 : (v[i] / mx) * size.height;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * w + 1.5, size.height - h, w - 3, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(r, v[i] == 0 ? q : p);
    }
  }

  @override
  bool shouldRepaint(covariant _Bars o) => o.v != v;
}
