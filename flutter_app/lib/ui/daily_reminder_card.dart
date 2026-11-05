import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/day_util.dart';
import '../core/books.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'reader_screen.dart';
import 'theme.dart';

class DailyReminderCard extends StatefulWidget {
  const DailyReminderCard({super.key, required this.onBrowseBooks});
  final VoidCallback onBrowseBooks;

  static List<Chap> nextReadings(AppState state) {
    for (final day in state.days) {
      final unread = day.where((c) => !state.isDone(c.key)).toList();
      if (unread.isNotEmpty) return unread;
    }
    return const [];
  }

  @override
  State<DailyReminderCard> createState() => _DailyReminderCardState();
}

class _DailyReminderCardState extends State<DailyReminderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _glow.stop();
      _glow.value = .65;
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final next = DailyReminderCard.nextReadings(s);
    if ((s.hasPlan && next.isEmpty) ||
        (!s.hasPlan && s.readDates.contains(dayStr(s.today)))) {
      return const SizedBox.shrink();
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = s.streak.cur > 0;
    return AnimatedBuilder(
        animation: _glow,
        builder: (context, child) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1B2940) : const Color(0xFFFFEBC1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: accentColor(context).withValues(alpha: .65)),
                boxShadow: [
                  BoxShadow(
                      color: accentColor(context)
                          .withValues(alpha: .12 + .18 * _glow.value),
                      blurRadius: 10 + 10 * _glow.value)
                ],
              ),
              child: child,
            ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: accentColor(context), size: 32),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          active
                              ? (gEn
                                  ? 'Keep your streak going'
                                  : 'حافظ على سلسلتك — اقرأ النهاردة')
                              : (gEn
                                  ? 'Start your reading streak today'
                                  : 'ابدأ سلسلة قراءتك النهاردة'),
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(active
                          ? (gEn
                              ? 'Read your first chapter today.'
                              : 'اقرأ أول أصحاح النهاردة عشان تكمل سلسلة قراءتك')
                          : (gEn
                              ? 'Start with one chapter.'
                              : 'ابدأ بأصحاح واحد وخد أول خطوة')),
                    ]),
                FilledButton(
                    onPressed: () {
                      final unread = DailyReminderCard.nextReadings(s);
                      if (unread.isEmpty) {
                        widget.onBrowseBooks();
                        return;
                      }
                      final first = unread.first;
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ReaderScreen(
                              b: first.b, c: first.c, queue: unread)));
                    },
                    child: Text(tr('readNow'))),
              ]),
        ));
  }
}
