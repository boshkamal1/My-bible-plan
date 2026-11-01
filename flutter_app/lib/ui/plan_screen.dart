import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/day_util.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'day_view.dart';
import 'theme.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  ScrollController? _sc;

  @override
  void dispose() {
    _sc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.hasPlan) return const SizedBox();
    final p = s.plan!;
    final cur = s.dayIndex;
    return Scaffold(
      appBar: AppBar(title: Text(tr('plan'))),
      body: ListView.builder(
        controller: _sc ??= ScrollController(
          initialScrollOffset: (cur * 76.0 - 120)
              .clamp(0, double.infinity)
              .toDouble(),
        ),
        padding: const EdgeInsets.all(12),
        itemCount: p.nDays + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('buffer'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var j = 0; j < p.buf; j++)
                          Container(
                            margin: const EdgeInsetsDirectional.only(end: 6),
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: j < s.delays.length + s.pb.length
                                  ? kGold
                                  : Colors.transparent,
                              border: Border.all(color: kGold),
                            ),
                            child: Text(
                              nf(j + 1),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          final k = i - 1;
          final date = s.dates.length > k ? s.dates[k] : s.today;
          final list = s.chaptersOfDay(k);
          final complete = s.dayComplete(k);
          final frozen = s.frozenDates.contains(dayStr(date));
          final isCur = k == cur;
          return Card(
            color: isCur ? kGold.withValues(alpha: 0.14) : null,
            child: ListTile(
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => DayScreen(k: k))),
              leading: CircleAvatar(
                backgroundColor: complete
                    ? Colors.green
                    : (date < s.today
                          ? Colors.orange.withValues(alpha: 0.4)
                          : null),
                child: complete
                    ? const Icon(Icons.check, color: Colors.white)
                    : Text(nf(k + 1)),
              ),
              title: Text(
                s.rangeLabel(list),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${dateLabel(date)}${frozen ? '  🛡' : ''}'),
              trailing: Text('${nf(s.doneInDay(k))}/${nf(list.length)}'),
            ),
          );
        },
      ),
    );
  }
}

class DayScreen extends StatelessWidget {
  final int k;
  const DayScreen({super.key, required this.k});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${tr('day')} ${nf(k + 1)}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [DayView(k: k)],
      ),
    );
  }
}
