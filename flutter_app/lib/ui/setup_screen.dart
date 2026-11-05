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
    'العهد القديم ثم الجديد، 365 يوم',
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
    'الكتاب المقدس في 90 يوم',
    'Whole Bible in 90 days',
    'للمتحمسين، قراءة كثيرة يوميًا',
    'An intensive pace',
    'all',
    'seq',
    90,
    [],
  ),
  const ReadyPlan(
    'العهد الجديد في 30 يوم',
    'New Testament in 30 days',
    'شهر واحد مع العهد الجديد',
    'One month in the New Testament',
    'nt',
    'seq',
    30,
    [],
  ),
  const ReadyPlan(
    'العهد الجديد في 90 يوم',
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
    '30 يوم',
    '30 days',
    'nt',
    'seq',
    30,
    _onlyNt([49, 50, 51, 52, 53]),
  ),
  ReadyPlan(
    'المزامير والأمثال',
    'Psalms & Proverbs',
    '60 يوم',
    '60 days',
    'ot',
    'seq',
    60,
    _onlyOt([kPsalms, 21]),
  ),
  ReadyPlan(
    'أسفار موسى الخمسة',
    'The Pentateuch',
    '60 يوم',
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
  Set<int> selectedBooks = {...kPlanOrderOt, ...kPlanOrderNt};
  List<int> bookOrder = [];
  final _daysCtl = TextEditingController(text: '100');
  bool _daysValid = true;

  String _westernDigits(String value) => value.replaceAllMapped(
        RegExp(r'[٠-٩۰-۹]'),
        (m) {
          final code = m[0]!.codeUnitAt(0);
          return '${code >= 0x06f0 ? code - 0x06f0 : code - 0x0660}';
        },
      );

  void _chooseDays(int value) {
    setState(() {
      days = value;
      _daysValid = true;
      _daysCtl.text = '$value';
    });
  }

  @override
  void dispose() {
    _daysCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      scope = i.scope;
      mode = i.mode;
      days = i.days;
      _daysValid = days >= 30 && days <= 730;
      skip = i.skip.toSet();
      selectedBooks =
          i.selectedBooks?.toSet() ?? {...kPlanOrderOt, ...kPlanOrderNt};
      bookOrder = List.of(i.bookOrder);
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
      selectedBooks: selectedBooks.toList(),
      bookOrder: bookOrder,
      reserveWithinDuration: true,
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
    final selectedDays =
        endDate == null ? 0 : dayFromDate(endDate!) - todayNum() + 1;
    final okEnd = !useDate || (selectedDays >= 30 && selectedDays <= 730);
    final canStart = p != null &&
        p.total > 0 &&
        p.nDays > 0 &&
        okEnd &&
        (useDate || _daysValid);
    return Scaffold(
      appBar: AppBar(title: Text(tr('setup'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            gEn ? 'Reading scope' : 'نطاق القراءة',
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
              onSelectionChanged: (v) => setState(() {
                mode = v.first;
                bookOrder = [];
              }),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            gEn ? 'Plan duration' : 'مدة الخطة',
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
            LayoutBuilder(builder: (context, constraints) {
              final input = SizedBox(
                width: constraints.maxWidth < 440 ? constraints.maxWidth : 150,
                child: TextField(
                  controller: _daysCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('daysCount'),
                    border: const OutlineInputBorder(),
                    errorText: _daysValid
                        ? null
                        : (gEn
                            ? 'Choose 30 to 730 days'
                            : 'اختار مدة من 30 إلى 730 يوم'),
                  ),
                  onChanged: (v) => setState(() {
                    final parsed = int.tryParse(_westernDigits(v));
                    _daysValid =
                        parsed != null && parsed >= 30 && parsed <= 730;
                    if (_daysValid) days = parsed!;
                  }),
                ),
              );
              final slider = Column(children: [
                Slider(
                  value: days.clamp(30, 730).toDouble(),
                  min: 30,
                  max: 730,
                  divisions: 700,
                  activeColor: kGold,
                  label: '$days',
                  onChanged: (v) => _chooseDays(v.round()),
                ),
                LayoutBuilder(builder: (context, bounds) {
                  const choices = [30, 90, 180, 365, 730];
                  return SizedBox(
                      height: 48,
                      child: Stack(children: [
                        for (final d in choices)
                          PositionedDirectional(
                            start: (((bounds.maxWidth - 48) * (d - 30) / 700))
                                .clamp(0, bounds.maxWidth - 48),
                            top: d == 90 || d == 365 ? 21 : 0,
                            width: 48,
                            child: InkWell(
                                onTap: () => _chooseDays(d),
                                child: Text(
                                  d == 730
                                      ? (gEn ? '2 yrs' : 'سنتين')
                                      : '$d ${gEn ? 'd' : 'يوم'}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: days == d
                                          ? kGold
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                )),
                          ),
                      ]));
                }),
              ]);
              return constraints.maxWidth < 440
                  ? Column(children: [input, const SizedBox(height: 8), slider])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Expanded(child: slider),
                          const SizedBox(width: 12),
                          input
                        ]);
            }),
            if (p != null && p.nDays > 0)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    gEn
                        ? 'About ${(p.total / p.nDays).toStringAsFixed(1)} chapters daily'
                        : 'حوالي ${(p.total / p.nDays).toStringAsFixed(1)} أصحاح يوميًا',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: kGold),
                  )),
            if (p != null && p.nDays > p.total)
              Text(gEn
                  ? 'Some days will be for rest or review.'
                  : 'بعض الأيام هتكون للراحة أو المراجعة.'),
          ] else
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(
                  endDate == null
                      ? tr('endDate')
                      : dayStr(dayFromDate(endDate!)),
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: (endDate != null &&
                            selectedDays >= 30 &&
                            selectedDays <= 730)
                        ? endDate!
                        : now.add(const Duration(days: 99)),
                    firstDate: now.add(const Duration(days: 29)),
                    lastDate: now.add(const Duration(days: 729)),
                  );
                  if (d != null) setState(() => endDate = d);
                },
              ),
              if (endDate != null && !okEnd)
                Text(
                    gEn
                        ? 'Choose 30 to 730 days'
                        : 'اختار مدة من 30 إلى 730 يوم',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ]),
          const SizedBox(height: 20),
          _bookPicker(false),
          if (scope != 'nt')
            Row(children: [
              Expanded(child: Text('${tr('psalm')}: ${tr('done')}')),
              DropdownButton<int>(
                  value: otP,
                  items: [
                    for (var i = 0; i <= 150; i++)
                      DropdownMenuItem(value: i, child: Text(nf(i)))
                  ],
                  onChanged: (v) => setState(() => otP = v ?? 0)),
            ]),
          const SizedBox(height: 12),
          _bookPicker(true),
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                  icon: const Icon(Icons.reorder),
                  label: Text(
                      gEn ? 'Advanced: book order' : 'Advanced: ترتيب الأسفار'),
                  onPressed: _editOrder)),
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
                    Text(gEn
                        ? '${nf(p.buf)} reserve days deducted from duration'
                        : 'تم خصم ${nf(p.buf)} أيام احتياطي من المدة المختارة'),
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

  List<BookGroup> get _groups => [
        if (scope != 'nt') ...kOtGroups,
        if (scope != 'ot') ...kNtGroups,
      ];
  Widget _bookPicker(bool excluding) {
    final values = excluding ? skip : selectedBooks;
    return Card(
        child: ExpansionTile(
      title: Text(excluding
          ? tr('skipBooks')
          : (gEn ? 'What will you read?' : 'هتقرا إيه؟')),
      children: [
        for (final g in _groups) ...[
          CheckboxListTile(
              tristate: true,
              value: g.books.every(values.contains)
                  ? true
                  : g.books.any(values.contains)
                      ? null
                      : false,
              title: Text(
                  g.id == 'psalms' ? tr('psalm') : tr('bookGroup_${g.id}'),
                  style: const TextStyle(
                      color: kGold, fontWeight: FontWeight.bold)),
              subtitle:
                  Text(gEn ? 'Select / clear group' : 'تحديد / إلغاء المجموعة'),
              onChanged: (_) => setState(() {
                    if (g.books.every(values.contains)) {
                      values.removeAll(g.books);
                    } else {
                      values.addAll(g.books);
                    }
                  })),
          for (final b in g.books)
            CheckboxListTile(
                dense: true,
                value: values.contains(b),
                title: Text(gEn ? kEnNames[b] : kArNames[b]),
                onChanged: (v) => setState(() {
                      if (v == true) {
                        values.add(b);
                      } else {
                        values.remove(b);
                      }
                    })),
        ]
      ],
    ));
  }

  Future<void> _editOrder() async {
    final available = scopeBooks(scope)
        .where((b) => selectedBooks.contains(b) && !skip.contains(b))
        .toSet();
    final order = [
      ...bookOrder.where(available.contains),
      ...scopeBooks(scope).where(available.contains)
    ].toSet().toList();
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: Text(gEn
                    ? 'Drag books to reorder'
                    : 'اسحب الأسفار لترتيب القراءة'),
                content: SizedBox(
                    width: 420,
                    height: 420,
                    child: ReorderableListView.builder(
                        itemCount: order.length,
                        onReorder: (oldIndex, newIndex) => update(() {
                              if (newIndex > oldIndex) newIndex--;
                              order.insert(newIndex, order.removeAt(oldIndex));
                            }),
                        itemBuilder: (context, index) => ListTile(
                            key: ValueKey(order[index]),
                            title: Text(gEn
                                ? kEnNames[order[index]]
                                : kArNames[order[index]]),
                            leading: Text('${index + 1}'),
                            trailing: ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.drag_handle)))),
                        buildDefaultDragHandles: false)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, <int>[]),
                      child: Text(gEn ? 'Default order' : 'الترتيب الافتراضي')),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(gEn ? 'Cancel' : 'إلغاء')),
                  FilledButton(
                      onPressed: order.isEmpty
                          ? null
                          : () => Navigator.pop(context, order),
                      child: Text(gEn ? 'Save' : 'حفظ')),
                ],
              )),
    );
    if (result != null && mounted)
      setState(() {
        bookOrder = result;
        if (result.isNotEmpty) mode = 'seq';
      });
  }
}
