import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../core/day_util.dart';
import '../core/planner.dart';
import '../services/cloud.dart';
import '../state/app_state.dart';
import 'setup_screen.dart';
import 'group_create_screen.dart';
import 'day_view.dart';
import 'account_screen.dart';
import 'reader_screen.dart';
import 'theme.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _linkHandled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_linkHandled) return;
    final code = Uri.base.queryParameters['group'];
    final cloud = context.watch<Cloud>();
    if (code == null || !cloud.signedIn) return;
    if (PageStorage.maybeOf(context)
            ?.readState(context, identifier: 'joined-link-$code') ==
        true) return;
    _linkHandled = true;
    PageStorage.maybeOf(context)
        ?.writeState(context, true, identifier: 'joined-link-$code');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final error = await cloud.joinGroup(context.read<AppState>(), code);
      if (mounted)
        toast(
            context,
            error ??
                (gEn
                    ? 'Request sent to group admins'
                    : 'تم إرسال طلب الانضمام للأدمن'));
    });
  }

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
                  child: FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: Text(tr('signIn')),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const AccountScreen(),
                  )),
                ))
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
                              final setup =
                                  await Navigator.of(context).push<Setup>(
                                MaterialPageRoute(
                                    builder: (_) => const GroupCreateScreen()),
                              );
                              if (setup != null && context.mounted) {
                                Navigator.of(context)
                                    .push(MaterialPageRoute<void>(
                                  builder: (_) =>
                                      _GroupPlanScreen(setup: setup),
                                ));
                              }
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
  String? myStatus;
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
    final status = await cl.myGroupStatus(widget.code);
    if (!mounted) return;
    setState(() {
      info = i;
      members = m;
      myStatus = status;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cl = context.read<Cloud>();
    final me = members.where((m) => m.uid == cl.user?.uid).firstOrNull;
    final isAdmin = info?.owner == cl.user?.uid ||
        (me?.role == 'admin' && me?.status == 'approved');
    final approved = isAdmin || myStatus == 'approved';
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
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
            if (info?.setup != null && approved) ...[
              FilledButton.tonalIcon(
                icon: const Icon(Icons.calendar_month),
                label: Text(gEn ? 'Group plan' : 'خطة المجموعة'),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) =>
                      _GroupPlanScreen(setup: Setup.fromJson(info!.setup!)),
                )),
              ),
              const SizedBox(height: 8),
            ],
            if (isAdmin) ...[
              OutlinedButton.icon(
                onPressed: () => Share.share(
                    'https://mybibleplan.web.app/?group=${widget.code}'),
                icon: const Icon(Icons.share),
                label: Text(gEn ? 'Share group' : 'مشاركة المجموعة'),
              ),
              const SizedBox(height: 8),
            ],
            if (!approved && !loading)
              Text(myStatus == 'rejected'
                  ? (gEn ? 'Request declined' : 'تم رفض طلب الانضمام')
                  : (gEn
                      ? 'Waiting for admin approval'
                      : 'بانتظار موافقة الأدمن')),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (!approved)
              const SizedBox.shrink()
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
                    m.status == 'pending'
                        ? (gEn ? 'Pending approval' : 'طلب انضمام')
                        : m.status == 'rejected'
                            ? (gEn ? 'Rejected' : 'مرفوض')
                            : m.role == 'admin'
                                ? (gEn ? 'Admin' : 'أدمن')
                                : (gEn ? 'Member' : 'عضو'),
                  ),
                  trailing: isAdmin && m.uid != cl.user?.uid
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          if (m.status != 'approved') ...[
                            IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                tooltip: gEn ? 'Approve' : 'قبول',
                                onPressed: () async {
                                  await cl.reviewMember(
                                      widget.code, m.uid, 'approved');
                                  _load();
                                }),
                            IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                tooltip: gEn ? 'Reject' : 'رفض',
                                onPressed: () async {
                                  await cl.reviewMember(
                                      widget.code, m.uid, 'rejected');
                                  _load();
                                }),
                          ] else if (m.status == 'approved')
                            IconButton(
                                icon: Icon(m.role == 'admin'
                                    ? Icons.admin_panel_settings
                                    : Icons.person_add_alt_1),
                                tooltip: gEn
                                    ? 'Change admin role'
                                    : 'تغيير صلاحية الأدمن',
                                onPressed: () async {
                                  await cl.setAdmin(
                                      widget.code, m.uid, m.role != 'admin');
                                  _load();
                                }),
                        ])
                      : m.readToday
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.radio_button_unchecked),
                ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (info?.setup != null && approved)
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
                if (info?.owner != cl.user?.uid)
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

class _GroupPlanScreen extends StatelessWidget {
  const _GroupPlanScreen({required this.setup});
  final Setup setup;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final plan = buildPlan(setup);
    final dates = makeDates(plan, const {});
    final days = layoutDays(plan, dates, todayNum(), null);
    return Scaffold(
      appBar: AppBar(title: Text(gEn ? 'Group plan' : 'خطة المجموعة')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: days.length,
        itemBuilder: (context, index) => Card(
          child: ExpansionTile(
            title: Text(
                '${tr('day')} ${nf(index + 1)} • ${dateLabel(dates[index])}'),
            subtitle: Text(state.rangeLabel(days[index])),
            children: [
              for (final chapter in days[index])
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(state.chapLabel(chapter)),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => ReaderScreen(
                      b: chapter.b,
                      c: chapter.c,
                      queue: days[index],
                    ),
                  )),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
