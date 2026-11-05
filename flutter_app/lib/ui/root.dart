import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../state/app_state.dart';
import 'books_screen.dart';
import 'daily_reminder_card.dart';
import 'daily_verse_card.dart';
import 'groups_screen.dart';
import 'home_screen.dart';
import 'notes_screen.dart';
import 'plan_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';
import 'stats_screen.dart';
import 'tab_navigation.dart';
import 'web_home_bar.dart';
import 'theme.dart';

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int _i = currentTab.value;
  final List<int> _history = [];
  Timer? _dayTimer;
  AppState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (_state != state) {
      _state?.onBadgeEarned = null;
      _state = state;
      state.onBadgeEarned = (badge) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
              content: Text(
                  '${badge.icon} ${gEn ? 'New badge' : 'وسام جديد'}: ${badge.title}'),
              duration: const Duration(seconds: 3),
            ));
          }
        });
      };
    }
  }

  @override
  void initState() {
    super.initState();
    currentTab.addListener(_onBrowserTab);
    _dayTimer = Timer.periodic(const Duration(minutes: 1),
        (_) => context.read<AppState>().refreshToday());
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    currentTab.removeListener(_onBrowserTab);
    _state?.onBadgeEarned = null;
    super.dispose();
  }

  void _select(int index) {
    if (index == _i) return;
    setState(() {
      _history.add(_i);
      _i = index;
    });
    currentTab.value = index;
    if (kIsWeb) {
      final base = Uri.base;
      final fragment =
          base.fragment.startsWith('/') ? Uri.tryParse(base.fragment) : null;
      final params = <String, String>{
        ...base.queryParameters,
        ...?fragment?.queryParameters,
        'tab': '$index'
      };
      SystemNavigator.routeInformationUpdated(
          uri: Uri(path: '/', queryParameters: params), replace: false);
    }
  }

  void _onBrowserTab() {
    if (mounted && _i != currentTab.value) {
      setState(() => _i = currentTab.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return PopScope(
        canPop: _history.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _history.isNotEmpty) {
            final previous = _history.removeLast();
            setState(() => _i = previous);
            currentTab.value = previous;
          }
        },
        child: Scaffold(
          body: IndexedStack(
            index: _i,
            children: [
              TickerMode(
                  enabled: _i == 0,
                  child: s.hasPlan
                      ? HomeScreen(onBrowseBooks: () => _select(2))
                      : WelcomeScreen(onBrowseBooks: () => _select(2))),
              s.hasPlan ? const PlanScreen() : const _NoPlan(),
              const BooksScreen(),
              const StatsScreen(),
              const NotesScreen(),
              const GroupsScreen(),
              const SettingsScreen(),
            ],
          ),
          bottomNavigationBar: Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SafeArea(
                top: false,
                child: SizedBox(
                    height: 66,
                    child: Row(children: [
                      for (final entry in [
                        (Icons.home_rounded, tr('home')),
                        (Icons.calendar_month_rounded, tr('plan')),
                        (Icons.menu_book_rounded, tr('books')),
                        (Icons.insights_rounded, tr('stats')),
                        (Icons.edit_note_rounded, tr('notes')),
                        (Icons.groups_rounded, tr('groups')),
                        (Icons.settings_rounded, tr('settings')),
                      ].indexed)
                        Expanded(
                            child: InkWell(
                          onTap: () => _select(entry.$1),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(entry.$2.$1,
                                    size: 22,
                                    color: _i == entry.$1
                                        ? kGold
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                const SizedBox(height: 3),
                                FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(entry.$2.$2,
                                        maxLines: 1,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: _i == entry.$1
                                                ? kGold
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant))),
                              ]),
                        )),
                    ]))),
          ),
        ));
  }
}

class _NoPlan extends StatelessWidget {
  const _NoPlan();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('plan'))),
        body: Center(
            child: FilledButton.icon(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SetupScreen())),
          icon: const Icon(Icons.add_road),
          label: Text(gEn ? 'Create a reading plan' : 'إنشاء خطة قراءة'),
        )),
      );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onBrowseBooks});
  final VoidCallback onBrowseBooks;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: const WebHomeBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DailyReminderCard(onBrowseBooks: onBrowseBooks),
              DailyVerseCard(state: s),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              gEn ? 'Reading progress' : 'تقدم القراءة',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '0%',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: kGold,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(value: 0),
                      const SizedBox(height: 10),
                      Text(
                        gEn
                            ? 'Create a plan to see your daily chapters here.'
                            : 'أنشئ خطة علشان تظهر الأصحاحات اليومية هنا.',
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book, color: kGold),
                  title: Text(
                    gEn ? 'Your daily chapters' : 'أصحاحاتك اليومية',
                  ),
                  subtitle: Text(
                    gEn
                        ? 'Your readings will appear here after you create a plan.'
                        : 'قراءاتك هتظهر هنا بعد ما تعمل خطة.',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'ar', label: Text(tr('arabic'))),
                  const ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {s.lang},
                onSelectionChanged: (v) => s.setLang(v.first),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add_road),
                label: Text(gEn ? 'Create a reading plan' : 'إنشاء خطة قراءة'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SetupScreen()),
                ),
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
