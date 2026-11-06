import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/books.dart';
import '../core/day_util.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'reader_screen.dart';
import 'theme.dart';

String dateLabel(int n) {
  final d = dayToDate(n);
  const ar = [
    '',
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  const en = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const wAr = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  const wEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final w = gEn ? wEn[d.weekday - 1] : wAr[d.weekday - 1];
  return '$w ${nf(d.day)} ${gEn ? en[d.month] : ar[d.month]}';
}

class DayView extends StatelessWidget {
  final int k;
  const DayView({super.key, required this.k});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.plan!;
    final list = s.chaptersOfDay(k);
    final date = s.dates.length > k ? s.dates[k] : s.today;
    final ds = dayStr(date);
    final isPast = date < s.today;
    final isToday = date == s.today;
    final incomplete = list.isNotEmpty && list.any((c) => !s.isDone(c.key));
    final isDelay = s.delays.contains(ds);
    final isPb = s.pb.contains(ds);
    final canBuf = s.bufLeft > 0 && !isDelay && !isPb;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tr('day')} ${nf(k + 1)} ${tr('of')} ${nf(p.nDays)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      dateLabel(date),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '≈ ${nf(s.minutesForDay(k))} ${tr('minutes')}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                if (isDelay || isPb) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(Icons.shield, size: 18),
                    label: Text(tr('bufferUsed')),
                    onDeleted: () =>
                        isDelay ? s.removeDelay(ds) : s.removePastBuffer(ds),
                  ),
                ],
                const SizedBox(height: 8),
                if (list.isEmpty) Text('—'),
                for (final c in list)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: s.isDone(c.key),
                    onChanged: (_) => s.toggleChapter(c.key),
                    title: Text(s.chapLabel(c)),
                    secondary: IconButton(
                      icon: const Icon(Icons.chrome_reader_mode_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ReaderScreen(b: c.b, c: c.c, queue: list),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.menu_book),
                        label: Text(tr('readNow')),
                        onPressed: list.isEmpty
                            ? null
                            : () {
                                final first = list.firstWhere(
                                  (c) => !s.isDone(c.key),
                                  orElse: () => list.first,
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReaderScreen(
                                      b: first.b,
                                      c: first.c,
                                      queue: list,
                                    ),
                                  ),
                                );
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: Icon(incomplete ? Icons.done_all : Icons.undo),
                      label: Text(
                        incomplete ? tr('markDone') : tr('markUndone'),
                      ),
                      onPressed:
                          list.isEmpty ? null : () => s.markDay(k, incomplete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (incomplete && (isPast || isToday))
          Card(
            color: kGold.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (canBuf)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shield_outlined),
                      label: Text('${tr('useBuffer')} (${nf(s.bufLeft)})'),
                      onPressed: () {
                        final ok =
                            isToday ? s.useBuffer() : s.usePastBuffer(ds, k);
                        if (ok) toast(context, tr('bufferUsed'));
                      },
                    ),
                  if (k < p.nDays - 1)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.shuffle),
                      label: Text(tr('redistribute')),
                      onPressed: () {
                        final undo = s.redistribute(k);
                        if (undo == null) return;
                        ScaffoldMessenger.of(context)
                          ..removeCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: Text(tr('redistributed')),
                            duration: const Duration(seconds: 5),
                            persist: false,
                            action: SnackBarAction(
                              label: tr('undo'),
                              onPressed: undo,
                            ),
                          ));
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String bookGroupLabel(String id) => tr('bookGroup_$id');
bool isDeutBook(int b) => kDeut.contains(b);
