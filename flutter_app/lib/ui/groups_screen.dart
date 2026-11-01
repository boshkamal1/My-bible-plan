import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/planner.dart';
import '../services/cloud.dart';
import '../state/app_state.dart';
import 'setup_screen.dart';
import 'theme.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  Future<String?> _ask(String title) async {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: Text(tr('ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cl = context.watch<Cloud>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('groups'))),
      body: !cl.available
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('cloudOff'), textAlign: TextAlign.center),
              ),
            )
          : !cl.signedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('needSignIn'), textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(tr('createGroup')),
                        onPressed: () async {
                          final n = await _ask(tr('groupName'));
                          if (n == null || n.trim().isEmpty) return;
                          final e = await cl.createGroup(s, n);
                          if (mounted && e != null) toast(context, e);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.group_add),
                        label: Text(tr('joinGroup')),
                        onPressed: () async {
                          final n = await _ask(tr('groupCode'));
                          if (n == null || n.trim().isEmpty) return;
                          final e = await cl.joinGroup(s, n);
                          if (mounted && e != null)
                            toast(
                              context,
                              e == 'notfound' ? tr('noResults') : e,
                            );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final code in s.groupCodes) _GroupCard(code: code),
              ],
            ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  final String code;
  const _GroupCard({required this.code});
  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  GroupInfo? info;
  List<GroupMember> members = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cl = context.read<Cloud>();
    final i = await cl.groupInfo(widget.code);
    final m = await cl.members(widget.code);
    if (!mounted) return;
    setState(() {
      info = i;
      members = m;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cl = context.read<Cloud>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    info?.name ?? widget.code,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ],
            ),
            Row(
              children: [
                Text(
                  '${tr('groupCode')}: ',
                  style: const TextStyle(fontSize: 13),
                ),
                SelectableText(
                  widget.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: kGold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.code));
                    toast(context, tr('copied'));
                  },
                ),
              ],
            ),
            const Divider(),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (members.isEmpty)
              Text(tr('members0'))
            else
              for (final m in members)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(m.name.isEmpty ? '?' : m.name.characters.first),
                  ),
                  title: Text(m.name),
                  subtitle: Text(
                    '${nf(m.done)} ${tr('chapters')} • 🔥 ${nf(m.streak)}',
                  ),
                  trailing: m.readToday
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.radio_button_unchecked),
                ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (info?.setup != null)
                  FilledButton.tonal(
                    onPressed: () {
                      final j = Map<String, dynamic>.from(info!.setup!);
                      final t = DateTime.now();
                      final ts =
                          '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
                      j['start'] = ts;
                      j['first'] = ts;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SetupScreen(initial: Setup.fromJson(j)),
                        ),
                      );
                    },
                    child: Text(tr('useGroupPlan')),
                  ),
                TextButton(
                  onPressed: () => cl.leaveGroup(s, widget.code),
                  child: Text(tr('leave')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
