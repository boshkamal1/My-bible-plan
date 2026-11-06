import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/books.dart';
import '../core/day_util.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'daily_verse_card.dart';
import 'daily_reminder_card.dart';
import 'day_view.dart';
import 'reader_screen.dart';
import 'streak_candle.dart';
import 'theme.dart';
import 'web_home_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onBrowseBooks});
  final VoidCallback onBrowseBooks;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.hasPlan) return const SizedBox();
    final day = s.dayIndex;
    final readings = s.chaptersOfDay(day);
    return Scaffold(
      appBar: const WebHomeBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              DailyReminderCard(onBrowseBooks: onBrowseBooks),
              const SizedBox(height: 12),
              _WeekCard(state: s),
              DailyVerseCard(state: s),
              const SizedBox(height: 12),
              _PlanCard(state: s, day: day, readings: readings),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.state, required this.day, required this.readings});
  final AppState state;
  final int day;
  final List<Chap> readings;

  @override
  Widget build(BuildContext context) {
    final groups = <int, List<Chap>>{};
    for (final chapter in readings) {
      groups.putIfAbsent(chapter.b, () => <Chap>[]).add(chapter);
    }
    final completed =
        readings.where((chapter) => state.isDone(chapter.key)).length;
    final color = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(gEn ? "Today's reading" : 'قراءات اليوم',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: accentColor(context))),
          const SizedBox(height: 5),
          Text(
              '${tr('day')} ${nf(day + 1)} ${tr('of')} ${nf(state.plan!.nDays)}  •  ${dateLabel(state.dates[day])}',
              style: TextStyle(color: color.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(state.rangeLabel(readings),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          for (final entry in groups.entries) ...[
            Row(children: [
              Expanded(
                  child: Text(state.bookName(entry.key),
                      style: TextStyle(fontWeight: FontWeight.bold))),
              OutlinedButton.icon(
                onPressed: () {
                  final queue = entry.value;
                  final first = queue.firstWhere(
                    (chapter) => !state.isDone(chapter.key),
                    orElse: () => queue.first,
                  );
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        ReaderScreen(b: first.b, c: first.c, queue: queue),
                  ));
                },
                icon: Icon(Icons.menu_book_outlined, size: 17),
                label: Text(gEn ? 'Read' : 'اقرأ'),
              ),
            ]),
            const SizedBox(height: 7),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final chapter in entry.value)
                InputChip(
                  label: Text(nf(displayChapterNumber(
                      chapter.b, chapter.c, state.translation))),
                  selected: state.isDone(chapter.key),
                  selectedColor: accentColor(context).withValues(alpha: .23),
                  side: BorderSide(
                      color: accentColor(context).withValues(alpha: .7)),
                  onPressed: () => state.toggleChapter(chapter.key),
                  tooltip: state.isDone(chapter.key)
                      ? tr('markUndone')
                      : tr('markDone'),
                ),
            ]),
            const SizedBox(height: 14),
          ],
          if (readings.isEmpty)
            Text(gEn ? 'No chapters scheduled.' : 'لا توجد أصحاحات مجدولة.'),
          Row(children: [
            Expanded(
                child: LinearProgressIndicator(
              value: readings.isEmpty ? 0 : completed / readings.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: accentColor(context),
              backgroundColor: color.surfaceContainerHighest,
            )),
            const SizedBox(width: 12),
            Text('${nf(completed)}/${nf(readings.length)}'),
          ]),
        ]),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final perDay = state.chaptersPerDay(7).values.toList();
    final chapters = perDay.fold<int>(0, (sum, count) => sum + count);
    final readingDays = perDay.where((count) => count > 0).length;
    final seconds = List.generate(7, (i) => dayStr(state.today - i))
        .fold<int>(0, (sum, day) => sum + (state.secs[day] ?? 0));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(gEn ? 'Last 7 days' : 'إنجازات آخر 7 أيام',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: accentColor(context))),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 4 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              _metric(
                  context,
                  width,
                  const Text('📖', style: TextStyle(fontSize: 24)),
                  nf(chapters),
                  tr('chaptersRead')),
              _metric(
                  context,
                  width,
                  const Text('📅', style: TextStyle(fontSize: 24)),
                  '${nf(readingDays)}/7',
                  gEn ? 'Reading days' : 'أيام قراءة'),
              _metric(context, width, const StreakCandle(size: 32),
                  nf(state.streak.cur), tr('streak')),
              _metric(
                  context,
                  width,
                  const Text('⏱', style: TextStyle(fontSize: 24)),
                  nf(seconds ~/ 60),
                  '${tr('readingTime')} (${tr('minutes')})'),
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _metric(BuildContext context, double width, Widget icon, String value,
      String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        SizedBox(height: 32, child: Center(child: icon)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, textAlign: TextAlign.center),
      ]),
    );
  }
}
