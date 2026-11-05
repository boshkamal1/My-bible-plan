import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/bible_repo.dart';
import '../core/data_backup.dart';
import '../core/books.dart';
import '../core/day_util.dart';
import '../core/i18n.dart';
import '../core/translations.dart';
import '../core/planner.dart';

const String _kKey = 'jb-v1';

class BadgeDef {
  final String id;
  final String ar;
  final String en;
  final String icon;
  final bool earned;
  const BadgeDef(this.id, this.ar, this.en, this.icon, this.earned);
  String get title => gEn ? en : ar;
}

class AppState extends ChangeNotifier {
  AppState(this.prefs);
  final SharedPreferences prefs;
  final BibleRepo repo = BibleRepo();

  // ---- persisted data
  Map<String, String> done = {};
  Set<String> hist = {};
  List<String> delays = [];
  List<String> pb = [];
  List<List<String>>? planOverride;
  Setup? setup;
  int t = 0;
  Map<String, String> notes = {};
  Map<String, int> hl = {};
  Set<String> fav = {};
  Map<String, int> secs = {};
  Map<String, String> badgeDates = {};
  void Function(BadgeDef)? onBadgeEarned;
  List<String> groupCodes = [];

  // ---- settings (not synced except where noted)
  String lang = 'ar';
  String translation = 'svd';
  double fontSize = 20;
  int themeMode = 0; // 0 system 1 light 2 dark
  bool remindOn = true;
  bool riskOn = true;
  int remindH = 8;
  int remindM = 0;
  bool seenWelcome = false;
  String displayName = '';

  // ---- derived
  PlanData? plan;
  List<int> dates = [];
  List<List<Chap>> days = [];
  int today = todayNum();

  // ---- hooks
  void Function(AppState s)? afterChange;
  Timer? _deb;
  Timer? _saveDeb;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _deb?.cancel();
    _saveDeb?.cancel();
    super.dispose();
  }

  bool get hasPlan => setup != null && plan != null && plan!.nDays > 0;
  bool get en => lang == 'en';

  void load() {
    final raw = prefs.getString(_kKey);
    if (raw != null) {
      try {
        _fromMap(jsonDecode(raw) as Map<String, dynamic>, withSettings: true);
      } catch (_) {}
    }
    gEn = en;
    _recompute();
  }

  void _fromMap(Map<String, dynamic> j, {required bool withSettings}) {
    done = ((j['done'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, v as String),
    );
    hist = ((j['hist'] as List?) ?? []).map((e) => e as String).toSet();
    delays = ((j['delays'] as List?) ?? []).map((e) => e as String).toList();
    pb = ((j['pb'] as List?) ?? []).map((e) => e as String).toList();
    final p = j['plan'];
    if (p is List) {
      planOverride = p.map<List<String>>((e) {
        if (e is String) return e.isEmpty ? <String>[] : e.split(',');
        return (e as List).map((x) => x.toString()).toList();
      }).toList();
    } else {
      planOverride = null;
    }
    final s = j['setup'];
    setup = s is Map ? Setup.fromJson(Map<String, dynamic>.from(s)) : null;
    if (setup != null && planOverride == null && j['plannerVersion'] == null) {
      final previous = buildPlan(setup!, legacyEsther: true);
      planOverride = previous.base
          .map((day) => day.map((chapter) => chapter.key).toList())
          .toList();
    }
    t = (j['t'] as num?)?.toInt() ?? 0;
    notes = ((j['notes'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, v as String),
    );
    hl = ((j['hl'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    );
    fav = ((j['fav'] as List?) ?? []).map((e) => e as String).toSet();
    secs = ((j['secs'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    );
    badgeDates = ((j['badgeDates'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
    if (withSettings) {
      groupCodes =
          ((j['groups'] as List?) ?? []).map((e) => e as String).toList();
      final st = (j['settings'] as Map?) ?? {};
      lang = (st['lang'] as String?) ?? 'ar';
      translation = (st['tr'] as String?) ?? 'svd';
      fontSize = (st['fs'] as num?)?.toDouble() ?? 20;
      themeMode = (st['theme'] as num?)?.toInt() ?? 0;
      remindOn = (st['rem'] as bool?) ?? true;
      riskOn = (st['risk'] as bool?) ?? true;
      remindH = (st['rh'] as num?)?.toInt() ?? 8;
      remindM = (st['rm'] as num?)?.toInt() ?? 0;
      seenWelcome = (st['welcome'] as bool?) ?? false;
      displayName = (st['name'] as String?) ?? '';
    }
  }

  Map<String, dynamic> toMap({bool cloud = false}) => {
        'done': done,
        'hist': hist.toList(),
        'delays': delays,
        'pb': pb,
        // Firestore does not allow nested arrays; store each day as a comma string.
        'plan': planOverride?.map((d) => d.join(',')).toList(),
        'plannerVersion': 14,
        'setup': setup?.toJson(),
        't': t,
        'notes': notes,
        'hl': hl,
        'fav': fav.toList(),
        'secs': secs,
        'badgeDates': badgeDates,
        if (!cloud) ...{
          'groups': groupCodes,
          'settings': {
            'lang': lang,
            'tr': translation,
            'fs': fontSize,
            'theme': themeMode,
            'rem': remindOn,
            'risk': riskOn,
            'rh': remindH,
            'rm': remindM,
            'welcome': seenWelcome,
            'name': displayName,
          },
        },
      };

  String exportBackup() {
    final snapshot = Map<String, dynamic>.from(toMap());
    // Freeze the actual daily assignments, including changes made by the user.
    snapshot['plan'] = setup == null
        ? null
        : days.map((day) => day.map((c) => c.key).join(',')).toList();
    return DataBackup.encode(snapshot);
  }

  Future<void> restoreBackup(DataBackup backup) async {
    // Revalidate a copy: callers cannot mutate a preview and bypass validation.
    final checked = DataBackup.decode(DataBackup.encode(backup.data));
    final candidate = AppState(prefs);
    try {
      candidate._fromMap(checked.data, withSettings: true);
      candidate._recompute();
      final now = DateTime.now().millisecondsSinceEpoch;
      candidate.t =
          [now, t + 1, candidate.t + 1].reduce((a, b) => a > b ? a : b);
      final snapshot = candidate.toMap();
      // Persist first. A failed file or failed write leaves the current state intact.
      _saveDeb?.cancel();
      final saved = await prefs.setString(_kKey, jsonEncode(snapshot));
      if (!saved) {
        _persist();
        throw StateError('Could not save backup');
      }
      _fromMap(snapshot, withSettings: true);
      _recompute();
      gEn = en;
      notifyListeners();
      _scheduleAfter();
    } finally {
      candidate.dispose();
    }
  }

  /// Applies a cloud snapshot if it is newer. Returns true when applied.
  bool applyRemote(Map<String, dynamic> j) {
    final rt = (j['t'] as num?)?.toInt() ?? 0;
    if (rt <= t) return false;
    final groups = groupCodes;
    final keep = {
      'lang': lang,
      'tr': translation,
      'fs': fontSize,
      'theme': themeMode,
      'rem': remindOn,
      'risk': riskOn,
      'rh': remindH,
      'rm': remindM,
      'welcome': seenWelcome,
      'name': displayName,
    };
    final localBadges = Map<String, String>.from(badgeDates);
    _fromMap(j, withSettings: false);
    badgeDates = {...localBadges, ...badgeDates};
    groupCodes = groups;
    lang = keep['lang'] as String;
    translation = keep['tr'] as String;
    fontSize = keep['fs'] as double;
    themeMode = keep['theme'] as int;
    remindOn = keep['rem'] as bool;
    riskOn = keep['risk'] as bool;
    remindH = keep['rh'] as int;
    remindM = keep['rm'] as int;
    seenWelcome = keep['welcome'] as bool;
    displayName = keep['name'] as String;
    _recompute();
    _persist();
    notifyListeners();
    _scheduleAfter();
    return true;
  }

  void _persist() {
    _saveDeb?.cancel();
    _saveDeb = Timer(const Duration(milliseconds: 250), () {
      prefs.setString(_kKey, jsonEncode(toMap()));
    });
  }

  void _scheduleAfter() {
    _deb?.cancel();
    _deb = Timer(
      const Duration(milliseconds: 900),
      () => afterChange?.call(this),
    );
  }

  /// Mark a data change (bumps the sync timestamp).
  void touch({bool data = true, bool recompute = false}) {
    if (data) t = DateTime.now().millisecondsSinceEpoch;
    if (recompute) _recompute();
    _persist();
    notifyListeners();
    _scheduleAfter();
  }

  void refreshToday() {
    final n = todayNum();
    if (n != today) {
      today = n;
      _recompute();
      notifyListeners();
      _scheduleAfter();
    }
  }

  void _recompute() {
    today = todayNum();
    final s = setup;
    if (s == null) {
      plan = null;
      dates = [];
      days = [];
      return;
    }
    final p = buildPlan(s);
    plan = p;
    final dl = delays.map(parseDay).toSet();
    dates = makeDates(p, dl);
    days = layoutDays(p, dates, today, planOverride);
  }

  // ---- settings setters
  void setLang(String l) {
    lang = l;
    gEn = l == 'en';
    if (l == 'en' && isArabicTranslation(translation)) translation = 'kjv';
    touch(data: false);
  }

  void setTranslation(String x) {
    translation = x;
    touch(data: false);
  }

  void setFont(double d) {
    fontSize = d;
    touch(data: false);
  }

  void setTheme(int m) {
    themeMode = m;
    touch(data: false);
  }

  void setReminders({bool? on, bool? risk, int? h, int? m}) {
    remindOn = on ?? remindOn;
    riskOn = risk ?? riskOn;
    remindH = h ?? remindH;
    remindM = m ?? remindM;
    touch(data: false);
  }

  void setWelcomeSeen() {
    seenWelcome = true;
    touch(data: false);
  }

  void setName(String n) {
    displayName = n;
    touch(data: false);
  }

  void addGroup(String code) {
    if (!groupCodes.contains(code)) groupCodes.add(code);
    touch(data: false);
  }

  void removeGroup(String code) {
    groupCodes.remove(code);
    touch(data: false);
  }

  // ---- plan queries
  bool isDone(String key) => done.containsKey(key);

  int get dayIndex {
    if (!hasPlan) return 0;
    final k = firstIndexOnOrAfter(dates, today);
    return k >= plan!.nDays ? plan!.nDays - 1 : k;
  }

  /// Index of the day whose date is `today`, or -1 if today is a skipped/buffer day or outside plan.
  int get todayIndexExact {
    if (!hasPlan) return -1;
    return dates.indexOf(today);
  }

  List<Chap> chaptersOfDay(int k) =>
      (k >= 0 && k < days.length) ? days[k] : const [];

  int doneInDay(int k) => chaptersOfDay(k).where((c) => isDone(c.key)).length;

  bool dayComplete(int k) {
    final l = chaptersOfDay(k);
    return l.isNotEmpty && l.every((c) => isDone(c.key));
  }

  int get bufLeft => plan == null ? 0 : plan!.buf - delays.length - pb.length;

  Set<String> get frozenDates => {...delays, ...pb};

  int get planDone =>
      plan == null ? 0 : plan!.inPlan.where(done.containsKey).length;
  int get totalDone => done.length;

  double get percent {
    final p = plan;
    if (p == null || p.total == 0) return 0;
    return planDone / p.total;
  }

  int get daysLeft {
    if (!hasPlan) return 0;
    final last = dates.isEmpty ? 0 : dates.last;
    return (last - today + 1).clamp(0, 100000);
  }

  Set<String> get readDates => {...done.values, ...hist};

  StreakInfo get streak => streakOf(
        readDates: readDates,
        frozen: const {},
        today: today,
        first: readDates.isEmpty
            ? today
            : readDates.map(parseDay).reduce((a, b) => a < b ? a : b),
      );

  // ---- mutations
  void toggleChapter(String key) {
    refreshToday();
    final previous =
        badges.where((badge) => badge.earned).map((badge) => badge.id).toSet();
    if (done.containsKey(key)) {
      done.remove(key);
    } else {
      done[key] = dayStr(today);
    }
    _recordNewBadges(previous);
    touch();
  }

  void markChapter(String key, bool v) {
    refreshToday();
    final previous =
        badges.where((badge) => badge.earned).map((badge) => badge.id).toSet();
    if (v) {
      done.putIfAbsent(key, () => dayStr(today));
    } else {
      done.remove(key);
    }
    _recordNewBadges(previous);
    touch();
  }

  void markDay(int k, bool v) {
    refreshToday();
    final previous =
        badges.where((badge) => badge.earned).map((badge) => badge.id).toSet();
    for (final c in chaptersOfDay(k)) {
      if (v) {
        done.putIfAbsent(c.key, () => dayStr(today));
      } else {
        done.remove(c.key);
      }
    }
    _recordNewBadges(previous);
    touch();
  }

  void _recordNewBadges(Set<String> previous) {
    for (final badge in badges) {
      if (badge.earned &&
          !previous.contains(badge.id) &&
          !badgeDates.containsKey(badge.id)) {
        badgeDates.putIfAbsent(badge.id, () => dayStr(today));
        onBadgeEarned?.call(badge);
      }
    }
  }

  /// Buffer day for *today*: shifts the whole plan by one day.
  bool useBuffer() {
    final p = plan;
    if (p == null) return false;
    final s = dayStr(today);
    if (delays.contains(s) || pb.contains(s) || bufLeft <= 0) return false;
    if (today < p.start || today >= p.xmas - 1) return false;
    delays.add(s);
    touch(recompute: true);
    return true;
  }

  void removeDelay(String s) {
    delays.remove(s);
    touch(recompute: true);
  }

  /// Buffer for a *past* day k (viewed): freezes it and moves its unread chapters forward.
  bool usePastBuffer(String dateS, int k) {
    final p = plan;
    if (p == null) return false;
    if (delays.contains(dateS) || pb.contains(dateS) || bufLeft <= 0)
      return false;
    pb.add(dateS);
    if (p.nDays - 1 - k > 0) {
      _rebalance(k, [k]);
    }
    touch(recompute: true);
    return true;
  }

  void removePastBuffer(String s) {
    pb.remove(s);
    touch(recompute: true);
  }

  /// Redistribute unread chapters (from days <= k, or only the viewed day if [onlyThis]) over days after k.
  void redistribute(int k, {bool onlyThis = false}) {
    if (plan == null) return;
    _rebalance(k, onlyThis ? [k] : null);
    touch(recompute: true);
  }

  void _rebalance(int k, List<int>? only) {
    final p = plan!;
    final out = rebalanceDays(
      p: p,
      days: days,
      lastFrozen: k,
      isDone: isDone,
      only: only,
    );
    planOverride = out;
  }

  void newJourney(Setup s) {
    for (final badge in badges.where((badge) => badge.earned)) {
      badgeDates.putIfAbsent(badge.id, () => '');
    }
    hist.addAll(done.values);
    done = {};
    delays = [];
    pb = [];
    planOverride = null;
    setup = s;
    touch(recompute: true);
  }

  void clearPlan() {
    for (final badge in badges.where((badge) => badge.earned)) {
      badgeDates.putIfAbsent(badge.id, () => '');
    }
    hist.addAll(done.values);
    done = {};
    delays = [];
    pb = [];
    planOverride = null;
    setup = null;
    touch(recompute: true);
  }

  Future<void> wipeLocal() async {
    done = {};
    hist = {};
    delays = [];
    pb = [];
    planOverride = null;
    setup = null;
    notes = {};
    hl = {};
    fav = {};
    secs = {};
    badgeDates = {};
    groupCodes = [];
    t = DateTime.now().millisecondsSinceEpoch;
    _recompute();
    await prefs.remove(_kKey);
    notifyListeners();
    _scheduleAfter();
  }

  // ---- notes / highlights / favorites (key 'b:c:v')
  void setNote(String vk, String text) {
    if (text.trim().isEmpty) {
      notes.remove(vk);
    } else {
      notes[vk] = text.trim();
    }
    touch();
  }

  void setHighlight(String vk, int? color) {
    if (color == null) {
      hl.remove(vk);
    } else {
      hl[vk] = color;
    }
    touch();
  }

  void toggleFav(String vk) {
    if (!fav.remove(vk)) fav.add(vk);
    touch();
  }

  void addSeconds(int s) {
    if (s <= 0) return;
    final k = dayStr(todayNum());
    secs[k] = (secs[k] ?? 0) + s;
    _persist();
    t = DateTime.now().millisecondsSinceEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
    _scheduleAfter();
  }

  // ---- naming helpers
  String bookName(int b) => b == 48 && translation == 'web'
      ? (en ? 'Esther (Greek)' : 'أستير اليوناني')
      : en
          ? kEnNames[b]
          : kArNames[b];

  String chapLabel(Chap c) => c.isPsalm
      ? '${tr('psalm')} ${nf(c.c)}'
      : '${bookName(c.b)} ${nf(displayChapterNumber(c.b, c.c, translation))}';

  /// Compact label for a list of chapters: "تكوين 1-3، خروج 1"
  String rangeLabel(List<Chap> l) {
    if (l.isEmpty) return '—';
    final parts = <String>[];
    final ps = l.where((c) => c.isPsalm).map((c) => c.c).toList();
    if (ps.isNotEmpty) parts.add('${tr('psalm')} ${_rng(ps)}');
    for (final s in segsOf(l.where((c) => !c.isPsalm).toList())) {
      parts.add(
          '${bookName(s.b)} ${_rng(s.cs.map((c) => displayChapterNumber(s.b, c, translation)).toList())}');
    }
    return parts.join(gEn ? ', ' : '، ');
  }

  String _rng(List<int> cs) {
    final out = <String>[];
    var i = 0;
    while (i < cs.length) {
      var j = i;
      while (j + 1 < cs.length && cs[j + 1] == cs[j] + 1) {
        j++;
      }
      out.add(j > i ? '${nf(cs[i])}-${nf(cs[j])}' : nf(cs[i]));
      i = j + 1;
    }
    return out.join(gEn ? ', ' : '،');
  }

  int minutesForChap(Chap c) {
    return c.weight.ceil().clamp(1, 120);
  }

  int minutesForDay(int k) =>
      chaptersOfDay(k).fold<double>(0, (a, c) => a + c.weight).ceil();

  bool bookFinished(int b) {
    for (var c = 1; c <= kChapters[b]; c++) {
      if (!done.containsKey('$b:$c') &&
          !(plan != null &&
              !plan!.inPlan.contains('$b:$c') &&
              _preDone(b, c))) {
        return false;
      }
    }
    return true;
  }

  bool _preDone(int b, int c) => plan != null && c <= (plan!.pre[b] ?? 0);

  int get booksFinished {
    var n = 0;
    for (var b = 0; b < kBookCount; b++) {
      if (bookFinished(b)) n++;
    }
    return n;
  }

  Map<String, int> chaptersPerDay(int lastN) {
    final m = <String, int>{};
    for (final d in done.values) {
      m[d] = (m[d] ?? 0) + 1;
    }
    final out = <String, int>{};
    for (var i = lastN - 1; i >= 0; i--) {
      final s = dayStr(today - i);
      out[s] = m[s] ?? 0;
    }
    return out;
  }

  int get totalMinutesTracked => secs.values.fold(0, (a, b) => a + b) ~/ 60;

  List<BadgeDef> get badges {
    final st = streak;
    final best = st.best;
    final n = done.length; // chapters currently done
    final bk = booksFinished;
    bool earned(String id, bool condition) =>
        badgeDates.containsKey(id) || condition;
    return [
      BadgeDef(
          'first', 'أول أصحاح', 'First chapter', '🌱', earned('first', n >= 1)),
      BadgeDef('s3', '3 أيام متتالية', '3-day streak', '🔥',
          earned('s3', best >= 3)),
      BadgeDef(
          's7', 'أسبوع كامل', '7-day streak', '🔥', earned('s7', best >= 7)),
      BadgeDef(
          's30', 'شهر كامل', '30-day streak', '🏅', earned('s30', best >= 30)),
      BadgeDef('s100', '100 يوم', '100-day streak', '🏆',
          earned('s100', best >= 100)),
      BadgeDef('c50', '50 أصحاح', '50 chapters', '📖', earned('c50', n >= 50)),
      BadgeDef(
          'c250', '250 أصحاح', '250 chapters', '📚', earned('c250', n >= 250)),
      BadgeDef('c1000', '1000 أصحاح', '1000 chapters', '👑',
          earned('c1000', n >= 1000)),
      BadgeDef(
          'b1', 'أول سفر كامل', 'First full book', '✅', earned('b1', bk >= 1)),
      BadgeDef('b10', '10 أسفار', '10 books', '🎖️', earned('b10', bk >= 10)),
      BadgeDef(
        'plan',
        'خلصت الخطة',
        'Plan completed',
        '🎉',
        earned(
            'plan', plan != null && plan!.total > 0 && planDone >= plan!.total),
      ),
    ];
  }

  // ---- widget/notification helpers
  String todaySummary() {
    if (!hasPlan) return tr('widgetNone');
    final k = dayIndex;
    return rangeLabel(chaptersOfDay(k));
  }

  ThemeMode get flutterThemeMode => themeMode == 1
      ? ThemeMode.light
      : (themeMode == 2 ? ThemeMode.dark : ThemeMode.system);
}
