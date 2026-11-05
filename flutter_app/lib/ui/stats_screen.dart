import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/day_util.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'share_card.dart';
import 'theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final per = s.chaptersPerDay(30);
    final earned = s.badges.where((b) => b.earned).length;
    final completed = s.hasPlan && s.planDone >= s.plan!.total;
    final days = !s.hasPlan
        ? (gEn ? 'No plan' : 'لا توجد خطة')
        : completed
            ? (gEn ? 'Plan completed' : 'اكتملت الخطة')
            : nf(s.daysLeft);
    final metrics = <(IconData, Color, String, String)>[
      (
        Icons.local_fire_department,
        const Color(0xFFD59D34),
        nf(s.streak.cur),
        tr('streak')
      ),
      (
        Icons.emoji_events,
        const Color(0xFFEC8B24),
        nf(s.streak.best),
        tr('bestStreak')
      ),
      (
        Icons.menu_book,
        const Color(0xFF55A46B),
        nf(s.totalDone),
        tr('chaptersRead')
      ),
      (
        Icons.schedule,
        const Color(0xFF5B8ED2),
        nf(s.totalMinutesTracked),
        '${tr('readingTime')} (${tr('minutes')})'
      ),
      (
        Icons.military_tech,
        const Color(0xFF946AC8),
        nf(s.booksFinished),
        gEn ? 'Books finished' : 'أسفار منتهية'
      ),
      (Icons.calendar_today, const Color(0xFFCF76A3), days, tr('daysLeft')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('stats'))),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tr('stats'),
                                    style: const TextStyle(
                                        color: kGold,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(
                                    gEn
                                        ? 'Your progress and reading streak'
                                        : 'إنجازاتك وسلسلة القراءة',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Text(gEn
                                    ? 'Follow your reading, progress and badges.'
                                    : 'تابع انتظامك في القراءة وتقدمك والأوسمة اللي حققتها'),
                              ]),
                          FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ShareProgressScreen())),
                              icon: const Icon(Icons.ios_share),
                              label: Text(tr('shareProgress'))),
                        ],
                      ))),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth >= 700
                    ? 3
                    : box.maxWidth >= 300
                        ? 2
                        : 1;
                final width = (box.maxWidth - 8 * (cols - 1)) / cols;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final m in metrics)
                    SizedBox(
                        width: width,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: m.$2.withValues(alpha: .14),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Icon(m.$1, color: m.$2, size: 22)),
                                  const SizedBox(height: 8),
                                  Text(m.$3,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  Text(m.$4,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              )),
                        )),
                ]);
              }),
              const SizedBox(height: 12),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('last30'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final e in per.entries)
                              Semantics(
                                  button: true,
                                  label:
                                      '${e.key}: ${e.value} ${tr('chapters')}',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => showDialog<void>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                              title: Text(e.key),
                                              content: Text(
                                                  '${nf(e.value)} ${tr('chaptersRead')}\n${nf((s.secs[e.key] ?? 0) ~/ 60)} ${tr('minutes')}'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: Text(gEn
                                                        ? 'Close'
                                                        : 'إغلاق'))
                                              ],
                                            )),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: e.value == 0
                                            ? Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                            : kGold.withValues(
                                                alpha: (0.35 + e.value * .12)
                                                    .clamp(0.0, 1.0)),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: e.key == dayStr(s.today)
                                                ? kGold
                                                : Colors.transparent,
                                            width: 2),
                                      ),
                                      child: Text(
                                          e.value == 0 ? '·' : nf(e.value),
                                          style: const TextStyle(fontSize: 10)),
                                    ),
                                  )),
                          ]),
                          const SizedBox(height: 10),
                          Text(
                              gEn
                                  ? 'Gold marks days with reading; the border marks today. Tap a day for details.'
                                  : 'الذهبي يوم فيه قراءة، والإطار يحدد النهاردة. اضغط على أي يوم للتفاصيل.',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ))),
              const SizedBox(height: 14),
              Text('${tr('badges')}  $earned / ${s.badges.length}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth >= 700
                    ? 3
                    : box.maxWidth >= 300
                        ? 2
                        : 1;
                final width = (box.maxWidth - 8 * (cols - 1)) / cols;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final badge in s.badges)
                    SizedBox(
                        width: width,
                        child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Opacity(
                                  opacity: badge.earned ? 1 : .6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(badge.icon,
                                            style:
                                                const TextStyle(fontSize: 25)),
                                        const Spacer(),
                                        if (badge.earned)
                                          const Icon(Icons.check_circle,
                                              color: Colors.green, size: 20)
                                      ]),
                                      const SizedBox(height: 8),
                                      Text(badge.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(_badgeCondition(badge.id),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                      const SizedBox(height: 4),
                                      Text(
                                          badge.earned
                                              ? ((s.badgeDates[badge.id]
                                                          ?.isNotEmpty ??
                                                      false)
                                                  ? s.badgeDates[badge.id]!
                                                  : (gEn
                                                      ? 'Date unavailable'
                                                      : 'تاريخ التحقيق غير متاح'))
                                              : _badgeProgress(badge.id, s),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: kGold)),
                                    ],
                                  )),
                            )))
                ]);
              }),
            ]),
      )),
    );
  }

  String _badgeCondition(String id) => switch (id) {
        'first' => gEn ? 'Read your first chapter' : 'اقرأ أول أصحاح',
        's3' => gEn ? 'Read for 3 consecutive days' : 'اقرأ 3 أيام متتالية',
        's7' => gEn ? 'Read for 7 consecutive days' : 'اقرأ 7 أيام متتالية',
        's30' =>
          gEn ? 'Read for 30 consecutive days' : 'اقرأ 30 يومًا متتاليًا',
        's100' => gEn ? 'Read for 100 consecutive days' : 'اقرأ 100 يوم متتالٍ',
        'c50' => gEn ? 'Read 50 chapters' : 'اقرأ 50 أصحاحًا',
        'c250' => gEn ? 'Read 250 chapters' : 'اقرأ 250 أصحاحًا',
        'c1000' => gEn ? 'Read 1000 chapters' : 'اقرأ 1000 أصحاح',
        'b1' => gEn ? 'Finish one book' : 'أكمل سفرًا كاملًا',
        'b10' => gEn ? 'Finish 10 books' : 'أكمل 10 أسفار',
        _ => gEn ? 'Finish your reading plan' : 'أكمل خطة القراءة',
      };

  String _badgeProgress(String id, AppState s) {
    final (current, target) = switch (id) {
      'first' => (s.totalDone, 1),
      's3' => (s.streak.best, 3),
      's7' => (s.streak.best, 7),
      's30' => (s.streak.best, 30),
      's100' => (s.streak.best, 100),
      'c50' => (s.totalDone, 50),
      'c250' => (s.totalDone, 250),
      'c1000' => (s.totalDone, 1000),
      'b1' => (s.booksFinished, 1),
      'b10' => (s.booksFinished, 10),
      _ => (s.planDone, s.plan?.total ?? 0),
    };
    if (target == 0) return gEn ? 'No plan' : 'لا توجد خطة';
    return '${nf(current.clamp(0, target))} / ${nf(target)}';
  }
}
