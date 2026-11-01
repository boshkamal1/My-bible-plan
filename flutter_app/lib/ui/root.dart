import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../state/app_state.dart';
import 'books_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'plan_screen.dart';
import 'setup_screen.dart';
import 'stats_screen.dart';
import 'theme.dart';

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.hasPlan) return const WelcomeScreen();
    return Scaffold(
      body: IndexedStack(
        index: _i,
        children: const [
          HomeScreen(),
          PlanScreen(),
          BooksScreen(),
          StatsScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: tr('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: tr('plan'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: tr('books'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: tr('stats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            label: tr('more'),
          ),
        ],
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.auto_stories, size: 88, color: kGold),
              const SizedBox(height: 20),
              Text(
                tr('appName'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(tr('welcomeSub'), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'ar', label: Text(tr('arabic'))),
                  const ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {s.lang},
                onSelectionChanged: (v) => s.setLang(v.first),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(tr('start')),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SetupScreen())),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SetupScreen(showReady: true),
                  ),
                ),
                child: Text(tr('readyPlans')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
