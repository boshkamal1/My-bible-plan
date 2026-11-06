import 'dart:convert';
import 'package:crypto/crypto.dart';

const readingFields = [
  'done',
  'hist',
  'delays',
  'pb',
  'plan',
  'plannerVersion',
  'setup',
  't',
  'notes',
  'hl',
  'fav',
  'secs',
  'badgeDates',
  'conflicts'
];

bool sameValue(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && sameValue(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => sameValue(a[i], b[i]));
  }
  return a == b;
}

/// Three-way merge against the last acknowledged server snapshot. Clocks do not
/// select winners. Conflicting versions remain available for explicit resolution.
Map<String, dynamic> mergeReading(Map<String, dynamic> base,
    Map<String, dynamic> local, Map<String, dynamic> remote) {
  final conflicts = <String, dynamic>{
    ...?remote['conflicts'] as Map?,
    ...?local['conflicts'] as Map?
  };
  dynamic merge(
      String field, String key, dynamic old, dynamic left, dynamic right) {
    if (sameValue(left, right) || sameValue(right, old)) return left;
    if (sameValue(left, old)) return right;
    final id = '$field|$key';
    final versions = <dynamic>[];
    for (final prior in [remote['conflicts']?[id], local['conflicts']?[id]]) {
      if (prior is String) {
        final decoded = jsonDecode(prior);
        if (decoded is Map && decoded['versions'] is List)
          versions.addAll(decoded['versions']);
      }
    }
    versions.addAll([left, right]);
    final unique = <dynamic>[];
    for (final version in versions) {
      if (!unique.any((v) => sameValue(v, version))) unique.add(version);
    }
    conflicts[id] =
        jsonEncode({'field': field, 'key': key, 'versions': unique});
    return left;
  }

  final out = <String, dynamic>{};
  for (final field in ['done', 'notes', 'hl', 'badgeDates']) {
    final a = (base[field] as Map?) ?? {},
        b = (local[field] as Map?) ?? {},
        c = (remote[field] as Map?) ?? {};
    final result = <String, dynamic>{};
    for (final key in {...a.keys, ...b.keys, ...c.keys}) {
      final value = merge(field, key as String, a[key], b[key], c[key]);
      if (value != null) result[key] = value;
    }
    out[field] = result;
  }
  // Reading time is additive, including independent offline sessions.
  final a = (base['secs'] as Map?) ?? {},
      b = (local['secs'] as Map?) ?? {},
      c = (remote['secs'] as Map?) ?? {};
  out['secs'] = {
    for (final key in {...a.keys, ...b.keys, ...c.keys})
      key: ((b[key] as int? ?? 0) +
              (c[key] as int? ?? 0) -
              (a[key] as int? ?? 0))
          .clamp(0, 9007199254740991)
  };
  for (final field in ['hist', 'fav']) {
    final a = Set<String>.from(base[field] ?? []),
        b = Set<String>.from(local[field] ?? []),
        c = Set<String>.from(remote[field] ?? []);
    out[field] = ((a.difference(a.difference(b)).difference(a.difference(c)))
            .union(b.difference(a))
            .union(c.difference(a)))
        .toList()
      ..sort();
  }
  Map<String, dynamic> journey(Map<String, dynamic> m) => {
        for (final f in ['setup', 'plan', 'delays', 'pb']) f: m[f]
      };
  final oldJourney = journey(base),
      leftJourney = journey(local),
      rightJourney = journey(remote);
  final leftChanged = !sameValue(oldJourney, leftJourney);
  final rightChanged = !sameValue(oldJourney, rightJourney);
  Map selected;
  if ((leftChanged &&
          !rightChanged &&
          !sameValue(base['done'], remote['done'])) ||
      (rightChanged &&
          !leftChanged &&
          !sameValue(base['done'], local['done'])) ||
      (leftChanged && rightChanged && !sameValue(leftJourney, rightJourney))) {
    selected = merge(
        'journey',
        'plan',
        {...oldJourney, 'done': base['done']},
        {...leftJourney, 'done': local['done']},
        {...rightJourney, 'done': remote['done']}) as Map;
  } else {
    selected =
        merge('journey', 'plan', oldJourney, leftJourney, rightJourney) as Map;
    if (leftChanged && !rightChanged) out['done'] = local['done'] ?? {};
    if (rightChanged && !leftChanged) out['done'] = remote['done'] ?? {};
  }
  out.addAll(Map<String, dynamic>.from(selected));
  // Preserve explicit resolution/deletion of conflict records from either side.
  final oldConflicts = (base['conflicts'] as Map?) ?? {};
  for (final id in oldConflicts.keys) {
    if (((local['conflicts'] as Map?)?.containsKey(id) != true &&
            sameValue(remote['conflicts']?[id], oldConflicts[id])) ||
        ((remote['conflicts'] as Map?)?.containsKey(id) != true &&
            sameValue(local['conflicts']?[id], oldConflicts[id])))
      conflicts.remove(id);
  }
  out['conflicts'] = conflicts;
  out['plannerVersion'] = 14;
  out['t'] = DateTime.now().millisecondsSinceEpoch;
  return out;
}

String readingHash(Map<String, dynamic> snapshot) {
  dynamic canonical(dynamic value) => value is Map
      ? {
          for (final key
              in (value.keys.map((k) => k as String).toList()..sort()))
            key: canonical(value[key])
        }
      : value is List
          ? value.map(canonical).toList()
          : value;
  return sha256
      .convert(utf8.encode(jsonEncode(canonical(
          {for (final field in readingFields) field: snapshot[field]}))))
      .toString();
}

String readingDataHash(Map<String, dynamic> snapshot) =>
    readingHash({...snapshot, 't': 0});
