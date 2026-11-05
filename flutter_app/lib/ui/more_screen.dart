import 'package:flutter/material.dart';

import '../core/i18n.dart';
import 'groups_screen.dart';
import 'notes_screen.dart';
import 'privacy_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';
import 'share_card.dart';
import 'stats_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    void go(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    Widget tile(IconData i, String t, VoidCallback f) => Card(
          child: ListTile(
            leading: Icon(i),
            title: Text(t),
            trailing: const Icon(Icons.chevron_right),
            onTap: f,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(tr('more'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          tile(Icons.search, tr('search'), () => go(const SearchScreen())),
          tile(
            Icons.edit_note,
            '${tr('notes')} / ${tr('favorites')} / ${tr('highlights')}',
            () => go(const NotesScreen()),
          ),
          tile(Icons.groups, tr('groups'), () => go(const GroupsScreen())),
          tile(Icons.insights_outlined, tr('stats'),
              () => go(const StatsScreen())),
          tile(
            Icons.ios_share,
            tr('shareProgress'),
            () => go(const ShareProgressScreen()),
          ),
          tile(
            Icons.auto_awesome,
            tr('readyPlans'),
            () => go(const ReadyPlansScreen()),
          ),
          tile(Icons.add_road, tr('newJourney'), () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                content: Text(tr('restartConfirm')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(tr('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(tr('yes')),
                  ),
                ],
              ),
            );
            if (ok == true && context.mounted) go(const SetupScreen());
          }),
          tile(
            Icons.settings,
            tr('settings'),
            () => go(const SettingsScreen()),
          ),
          tile(
            Icons.privacy_tip_outlined,
            tr('privacy'),
            () => go(const PrivacyScreen()),
          ),
        ],
      ),
    );
  }
}
