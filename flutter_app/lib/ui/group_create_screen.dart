import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/day_util.dart';
import '../core/i18n.dart';
import '../core/planner.dart';
import '../services/cloud.dart';
import '../state/app_state.dart';
import 'theme.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});
  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final name = TextEditingController();
  String scope = 'all';
  int days = 100;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('createGroup'))),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextField(
              controller: name,
              maxLength: 60,
              decoration: InputDecoration(
                  labelText: tr('groupName'),
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text(gEn ? 'Group reading plan' : 'خطة قراءة المجموعة',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final option in ['ot', 'nt', 'all'])
                ChoiceChip(
                  label: Text(tr(option)),
                  selected: scope == option,
                  onSelected: (_) => setState(() => scope = option),
                ),
            ]),
            const SizedBox(height: 16),
            Text(tr('daysCount')),
            Wrap(spacing: 8, children: [
              for (final value in [30, 60, 90, 100, 180, 365])
                ChoiceChip(
                    label: Text(nf(value)),
                    selected: days == value,
                    onSelected: (_) => setState(() => days = value)),
            ]),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : _create,
              icon: const Icon(Icons.group_add),
              label:
                  Text(gEn ? 'Create group and plan' : 'إنشاء المجموعة والخطة'),
            ),
          ]),
        )),
      );

  Future<void> _create() async {
    if (name.text.trim().isEmpty) {
      toast(context, gEn ? 'Enter a group name' : 'اكتب اسم المجموعة');
      return;
    }
    setState(() => busy = true);
    final today = dayStr(todayNum());
    final setup = Setup(scope: scope, days: days, start: today, first: today);
    final error = await context.read<Cloud>().createGroup(
          context.read<AppState>(),
          name.text,
          setup,
        );
    if (!mounted) return;
    setState(() => busy = false);
    if (error != null) {
      toast(context, error);
      return;
    }
    Navigator.pop(context, setup);
  }
}
