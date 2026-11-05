import 'dart:convert';

import 'books.dart';
import 'day_util.dart';
import 'planner.dart';
import 'translations.dart';

/// A portable snapshot of application data, never authentication credentials.
class DataBackup {
  static const format = 'bible-journey-backup';
  static const maxBytes = 10 * 1024 * 1024;
  final Map<String, dynamic> data;
  final String createdAt;
  DataBackup._(this.data, this.createdAt);

  static String encode(Map<String, dynamic> data) => jsonEncode({
        'format': format,
        'version': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'data': data,
      });

  static DataBackup decode(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('Backup too large');
    }
    final envelope = jsonDecode(source);
    if (envelope is! Map ||
        envelope['format'] != format ||
        envelope['version'] != 1 ||
        envelope['data'] is! Map ||
        envelope['createdAt'] is! String ||
        DateTime.tryParse(envelope['createdAt']) == null) {
      throw const FormatException('Unsupported backup');
    }
    final data = Map<String, dynamic>.from(envelope['data']);
    _validate(data);
    return DataBackup._(data, envelope['createdAt']);
  }

  int get completed => (data['done'] as Map).length;
  int get noteCount => (data['notes'] as Map).length;
  int get favorites => (data['fav'] as List).length;
  int? get readingDays => data['setup'] == null
      ? null
      : buildPlan(Setup.fromJson(Map<String, dynamic>.from(data['setup'])))
          .nDays;

  static Never _invalid() => throw const FormatException('Invalid backup data');

  static bool _integer(dynamic value, int min, int max) =>
      value is int && value >= min && value <= max;

  static bool _date(dynamic value, {bool empty = false}) {
    if (empty && value == '') return true;
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value))
      return false;
    try {
      return dayStr(parseDay(value)) == value;
    } catch (_) {
      return false;
    }
  }

  static bool _chapter(dynamic value, {bool verse = false}) {
    if (value is! String) return false;
    final parts = value.split(':').map(int.tryParse).toList();
    if (parts.length != (verse ? 3 : 2) || parts.any((v) => v == null))
      return false;
    final b = parts[0]!;
    if (b < 0 || b >= kBookCount) return false;
    // Supplemental Psalm 151 and Greek Esther use translation-specific counts.
    final max = b == kPsalms
        ? 151
        : bookChapterCount(b, 'web') > kChapters[b]
            ? bookChapterCount(b, 'web')
            : kChapters[b];
    return parts[1]! >= 1 &&
        parts[1]! <= max &&
        (!verse || (parts[2]! >= 1 && parts[2]! <= 300));
  }

  static void _validate(Map<String, dynamic> j) {
    for (final name in ['done', 'notes', 'hl', 'secs', 'badgeDates']) {
      if (j[name] is! Map) _invalid();
    }
    for (final name in ['hist', 'delays', 'pb', 'fav', 'groups']) {
      if (j[name] is! List) _invalid();
    }
    if (!_integer(j['t'], 0, 9007199254740991) || j['settings'] is! Map)
      _invalid();
    for (final entry in (j['done'] as Map).entries) {
      if (!_chapter(entry.key) || !_date(entry.value)) _invalid();
    }
    for (final name in ['hist', 'delays', 'pb']) {
      final list = j[name] as List;
      if (list.any((v) => !_date(v)) || list.toSet().length != list.length)
        _invalid();
    }
    for (final entry in (j['notes'] as Map).entries) {
      if (!_chapter(entry.key, verse: true) ||
          entry.value is! String ||
          (entry.value as String).length > 100000) _invalid();
    }
    for (final entry in (j['hl'] as Map).entries) {
      if (!_chapter(entry.key, verse: true) || !_integer(entry.value, 0, 3))
        _invalid();
    }
    if ((j['fav'] as List).any((v) => !_chapter(v, verse: true))) _invalid();
    for (final entry in (j['secs'] as Map).entries) {
      if (!_date(entry.key) || !_integer(entry.value, 0, 9007199254740991))
        _invalid();
    }
    for (final entry in (j['badgeDates'] as Map).entries) {
      if (entry.key is! String || !_date(entry.value, empty: true)) _invalid();
    }
    if ((j['groups'] as List).any((v) => v is! String || v.length > 200))
      _invalid();
    final settings = j['settings'] as Map;
    if (!['ar', 'en'].contains(settings['lang']) ||
        !(kTranslationIds.contains(settings['tr']) ||
            settings['tr'] == 'jesuit') ||
        settings['fs'] is! num ||
        !(settings['fs'] as num).isFinite ||
        settings['fs'] < 14 ||
        settings['fs'] > 34 ||
        !_integer(settings['theme'], 0, 2) ||
        !_integer(settings['rh'], 0, 23) ||
        !_integer(settings['rm'], 0, 59) ||
        settings['rem'] is! bool ||
        settings['risk'] is! bool ||
        settings['welcome'] is! bool ||
        settings['name'] is! String) _invalid();

    final setup = j['setup'];
    if (setup == null) {
      if (j['plan'] != null) _invalid();
      return;
    }
    if (setup is! Map ||
        !['ot', 'nt', 'all'].contains(setup['scope']) ||
        !['seq', 'mix'].contains(setup['mode']) ||
        !_integer(setup['days'], 1, 3650) ||
        !_date(setup['start']) ||
        !_date(setup['first']) ||
        (setup['end'] != null &&
            (!_date(setup['end']) ||
                parseDay(setup['end']) - parseDay(setup['start']) < 0 ||
                parseDay(setup['end']) - parseDay(setup['start']) >= 3650)))
      _invalid();
    for (final name in ['skip', 'selectedBooks', 'bookOrder']) {
      final values = setup[name];
      if (values == null && name != 'skip') continue;
      if (values is! List ||
          values.any((v) => !_integer(v, 0, kBookCount - 1)) ||
          values.toSet().length != values.length) _invalid();
    }
    for (final name in ['ot', 'nt']) {
      final pointer = setup[name];
      if (pointer is! Map ||
          !_integer(pointer['b'], -1, kBookCount - 1) ||
          !_integer(pointer['c'], 0, 151)) _invalid();
      if (pointer['b'] != -1 &&
          (pointer['c'] > kChapters[pointer['b']] ||
              (name == 'ot' ? pointer['b'] >= 49 : pointer['b'] < 49)))
        _invalid();
    }
    if (!_integer(setup['ot']['p'], 0, 150) ||
        (setup['reserveWithinDuration'] != null &&
            setup['reserveWithinDuration'] is! bool)) _invalid();
    final p = buildPlan(Setup.fromJson(Map<String, dynamic>.from(setup)));
    final rows = j['plan'];
    if (rows is! List || rows.length != p.nDays) _invalid();
    final keys = <String>[];
    for (final row in rows) {
      if (row is! String) _invalid();
      if (row.isNotEmpty) keys.addAll(row.split(','));
    }
    if (keys.any((k) => !p.inPlan.contains(k)) ||
        keys.toSet().length != keys.length ||
        keys.length != p.total) _invalid();
  }
}
