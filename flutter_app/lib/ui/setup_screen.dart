import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/books.dart';
import '../core/day_util.dart';
import '../core/i18n.dart';
import '../core/planner.dart';
import '../state/app_state.dart';
import 'theme.dart';

class ReadyPlan {
  final String ar;
  final String en;
  final String descAr;
  final String descEn;
  final String scope;
  final String mode;
  final int days;
  final List<int> skip;
  const ReadyPlan(
    this.ar,
    this.en,
    this.descAr,
    this.descEn,
    this.scope,
    this.mode,
    this.days,
    this.skip,
  );
}

List<int> _onlyOt(List<int> keep) =>
    kPlanOrderOt.where((b) => !keep.contains(b)).toList();
List<int> _onlyNt(List<int> keep) =>
    kPlanOrderNt.where((b) => !keep.contains(b)).toList();

final List<ReadyPlan> kReady = [
  const ReadyPlan(
    'الكتاب المقدس في سنة',
    'Whole Bible in a year',
    'العهد القديم ثم الجديد، ٣٦٥ يوم',
    'Old then New Testament, 365 days',
    'all',
    'seq',
    365,
    [],
  ),
  const ReadyPlan(
    'القديم والجديد معًا في سنة',
    'Both testaments daily, one year',
    'كل يوم من القديم وكل يوم من الجديد',
    'A bit of each testament every day',
    'all',
    'mix',
    365,
    [],
  ),
  const ReadyPlan(
    'الكتاب المقدس في ٩٠ يوم',
    'Whole Bible in 90 days',
    'للمتحمسين، قراءة كثيرة يوميًا',
    'An intensive pace',
    'all',
    'seq',
    90,
    [],
  ),
  const ReadyPlan(
    'العهد الجديد في ٣٠ يوم',
    'New Testament in 30 days',
    'شهر واحد مع العهد الجديد',
    'One month in the New Testament',
    'nt',
    'seq',
    30,
    [],
  ),
  const ReadyPlan(
    'العهد الجديد في ٩٠ يوم',
    'New Testament in 90 days',
    'وتيرة هادئة',
    'A calm pace',
    'nt',
    'seq',
    90,
    [],
  ),
  const ReadyPlan(
    'العهد القديم في سنة',
    'Old Testament in a year',
    'العهد القديم كامل بالأسفار القانونية الثانية',
    'Whole OT including deuterocanon',
    'ot',
    'seq',
    365,
    [],
  ),
  ReadyPlan(
    'الأناجيل وأعمال الرسل',
    'Gospels & Acts',
    '٣٠ يوم',
    '30 days',
    'nt',
    'seq',
    30,
    _onlyNt([49, 50, 51, 52, 53]),
  ),
  ReadyPlan(
    'المزامير والأمثال',
    'Psalms & Proverbs',
    '٦٠ يوم',
    '60 days',
    'ot',
    'seq',
    60,
    _onlyOt([kPsalms, 21]),
  ),
  ReadyPlan(
    'أسفار موسى الخمسة',
    'The Pentateuch',
    '٦٠ يوم',
    '60 days',
    'ot',
    'seq',
    60,
    _onlyOt([0, 1, 2, 3, 4]),
  ),
];

class ReadyPlansScreen extends StatelessWidget {
  const ReadyPlansScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('readyPlans'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final r in kReady)
            Card(
              child: ListTile(
                title: Text(
                  gEn ? r.en : r.ar,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(gEn ? r.descEn : r.descAr),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final t = dayStr(todayNum());
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SetupScreen(
                        initial: Setup(
                          scope: r.scope,
                          mode: r.mode,
                          days: r.days,
                          skip: r.skip,
                          start: t,
                          first: t,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  final Setup? initial;
  final bool showReady;
  const SetupScreen({super.key, this.initial, this.showReady = false});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String scope = 'ot';
  String mode = 'seq';
  bool useDate = false;
  int days = 100;
  DateTime? endDate;
  int otB = -1;
  int otC = 0;
  int otP = 0;
  int ntB = -1;
  int ntC = 0;
  Set<int> skip = {};
  final _daysCtl = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      scope = i.scope;
      mode = i.mode;
      days = i.days;
      skip = i.skip.toSet();
      _daysCtl.text = '$days';
    }
    if (widget.showReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ReadyPlansScreen()));
      });
    }
  }

  Setup _build() {
    final t = dayStr(todayNum());
    return Setup(
      scope: scope,
      otB: otB,
      otC: otC,
      otP: otP,
      ntB: ntB,
      ntC: ntC,
      skip: skip.toList(),
      mode: mode,
      days: days,
      end: useDate && endDate != null ? dayStr(dayFromDate(endDate!)) : null,
      start: t,
      first: t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final su = _build();
    PlanData? p;
    try {
      p = buildPlan(su);
    } catch (_) {}
    final okEnd =
        !useDate || (endDate != null && dayFromDate(endDate!) >= todayNum());
    final canStart = p != null && p.total > 0 && p.nDays > 0 && okEnd;
    return Scaffold(
      appBar: AppBar(title: Text(tr('setup'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr('scope'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'ot', label: Text(tr('ot'))),
              ButtonSegment(value: 'nt', label: Text(tr('nt'))),
              ButtonSegment(value: 'all', label: Text(tr('all'))),
            ],
            selected: {scope},
            onSelectionChanged: (v) => setState(() => scope = v.first),
          ),
          if (scope == 'all') ...[
            const SizedBox(height: 16),
            Text(
              tr('order'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'seq', label: Text(tr('seq'))),
                ButtonSegment(value: 'mix', label: Text(tr('mix'))),
              ],
              selected: {mode},
              onSelectionChanged: (v) => setState(() => mode = v.first),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            tr('finishIn'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(tr('inDays'))),
              ButtonSegment(value: true, label: Text(tr('byDate'))),
            ],
            selected: {useDate},
            onSelectionChanged: (v) => setState(() => useDate = v.first),
          ),
          const SizedBox(height: 8),
          if (!useDate) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final d in [30, 60, 90, 100, 180, 365])
                  ChoiceChip(
                    label: Text(nf(d)),
                    selected: days == d,
                    onSelected: (_) => setState(() {
                      days = d;
                      _daysCtl.text = '$d';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _daysCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('daysCount'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  setState(() => days = (int.tryParse(v) ?? 1).clamp(1, 3000)),
            ),
          ] else
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(
                endDate == null ? tr('endDate') : dayStr(dayFromDate(endDate!)),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: endDate ?? now.add(const Duration(days: 100)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 3000)),
                );
                if (d != null) setState(() => endDate = d);
              },
            ),
          if (scope != 'nt') ...[
            const SizedBox(height: 20),
            Text(
              '${tr('startFrom')} (${tr('ot')})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _pointer(true),
            Row(
              children: [
                Expanded(child: Text('${tr('psalm')}: ${tr('done')}')),
                DropdownButton<int>(
                  value: otP,
                  items: [
                    for (var i = 0; i <= 150; i++)
                      DropdownMenuItem(value: i, child: Text(nf(i))),
                  ],
                  onChanged: (v) => setState(() => otP = v ?? 0),
                ),
              ],
            ),
          ],
          if (scope != 'ot') ...[
            const SizedBox(height: 12),
            Text(
              '${tr('startFrom')} (${tr('nt')})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _pointer(false),
          ],
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              shape: const Border(),
              title: Text(tr('skipBooks')),
              children: [
                for (final g in [
                  if (scope != 'nt') ...kOtGroups,
                  if (scope != 'ot') ...kNtGroups,
                ])
                  if (g.books.where((b) => b != kPsalms).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          tr('bookGroup_${g.id}'),
                          style: const TextStyle(
                            color: kGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    for (final b in g.books.where((b) => b != kPsalms))
                      CheckboxListTile(
                        dense: true,
                        value: skip.contains(b),
                        title: Text(gEn ? kEnNames[b] : kArNames[b]),
                        onChanged: (v) => setState(
                          () => v == true ? skip.add(b) : skip.remove(b),
                        ),
                      ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (p != null)
            Card(
              color: kGold.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Text(
                      '${nf(p.total)} ${tr('chapters')} • ${nf(p.nDays)} ${tr('day')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (p.nDays > 0)
                      Text(
                        '≈ ${(p.total / p.nDays).toStringAsFixed(1)} ${tr('chapters')} ${tr('perDay')}',
                      ),
                    Text('${tr('buffer')}: ${nf(p.buf)}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canStart
                ? () {
                    st.newJourney(_build());
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                : null,
            child: Text(tr('start')),
          ),
        ],
      ),
    );
  }

  Widget _pointer(bool ot) {
    final order = (ot ? kPlanOrderOt : kPlanOrderNt)
        .where((b) => b != kPsalms)
        .toList();
    final b = ot ? otB : ntB;
    final c = ot ? otC : ntC;
    return Row(
      children: [
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            value: b,
            items: [
              DropdownMenuItem(value: -1, child: Text(tr('fromStart'))),
              for (final x in order)
                DropdownMenuItem(
                  value: x,
                  child: Text(gEn ? kEnNames[x] : kArNames[x]),
                ),
            ],
            onChanged: (v) => setState(() {
              if (ot) {
                otB = v ?? -1;
                otC = 0;
              } else {
                ntB = v ?? -1;
                ntC = 0;
              }
            }),
          ),
        ),
        const SizedBox(width: 12),
        if (b >= 0)
          DropdownButton<int>(
            value: c,
            items: [
              for (var i = 0; i <= kChapters[b]; i++)
                DropdownMenuItem(value: i, child: Text(nf(i))),
            ],
            onChanged: (v) => setState(() => ot ? otC = v ?? 0 : ntC = v ?? 0),
          ),
      ],
    );
  }
}
