import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../state/app_state.dart';
import 'day_view.dart';
import 'search_screen.dart';
import 'theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.hasPlan) return const SizedBox();
    final st = s.streak;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('appName')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('${nf((s.percent * 100).round())}%',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold, color: kGold)),
                    ),
                    Text('${nf(s.daysLeft)} ${tr('daysLeft')}'),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: s.percent,
                        minHeight: 10,
                        color: kGold,
                        backgroundColor: scheme.surfaceContainerHighest),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${nf(s.totalDone)} / ${nf(s.plan!.total)} ${tr('chapters')}',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          Card(
            color: st.atRisk ? Colors.orange.withValues(alpha: 0.15) : null,
            child: ListTile(
              leading: const Text('🔥', style: TextStyle(fontSize: 30)),
              title: Text('${nf(st.cur)} ${tr('streak')}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(st.atRisk
                  ? tr('streakRisk')
                  : '${tr('bestStreak')}: ${nf(st.best)}'),
            ),
          ),
          if (s.percent >= 1)
            Card(
                child: ListTile(
                    title: Text(tr('planDone')),
                    leading: const Text('🎉', style: TextStyle(fontSize: 28)))),
          DayView(k: s.dayIndex),
        ],
      ),
    );
  }
}
