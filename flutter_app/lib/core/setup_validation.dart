import 'books.dart';
import 'day_util.dart';

Never _invalid() => throw const FormatException('Invalid reading setup');
bool _integer(dynamic value, int min, int max) =>
    value is int && value >= min && value <= max;
final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
bool _date(dynamic value) {
  if (value is! String ||
      !_datePattern.hasMatch(value) ||
      int.parse(value.substring(0, 4)) < 1) return false;
  try {
    return dayStr(parseDay(value)) == value;
  } catch (_) {
    return false;
  }
}

void validateSetupMap(dynamic setup) {
  if (setup is! Map ||
      !setup.keys.every((k) => const [
            'scope',
            'mode',
            'days',
            'start',
            'first',
            'end',
            'ot',
            'nt',
            'skip',
            'selectedBooks',
            'bookOrder',
            'reserveWithinDuration'
          ].contains(k)) ||
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
        values.length > 76 ||
        values.any((v) => !_integer(v, 0, kBookCount - 1)) ||
        values.toSet().length != values.length) _invalid();
  }
  for (final name in ['ot', 'nt']) {
    final pointer = setup[name];
    if (pointer is! Map ||
        !_integer(pointer['b'], -1, kBookCount - 1) ||
        !_integer(pointer['c'], 0, 151)) _invalid();
    if (pointer['b'] == -1 && pointer['c'] != 0) _invalid();
    if (pointer['b'] != -1 &&
        (pointer['c'] > kChapters[pointer['b']] ||
            (name == 'ot' ? pointer['b'] >= 49 : pointer['b'] < 49)))
      _invalid();
  }
  if (!_integer(setup['ot']['p'], 0, 151) ||
      (setup['reserveWithinDuration'] != null &&
          setup['reserveWithinDuration'] is! bool)) _invalid();
}
