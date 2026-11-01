import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Speaker extends ChangeNotifier {
  final FlutterTts _t = FlutterTts();
  bool playing = false;
  int current = -1;
  double rate = 0.45;
  List<String> _v = [];
  String _lang = 'ar';
  bool _stop = false;
  void Function()? onFinished;

  Speaker() {
    _t.setCompletionHandler(_next);
    _t.setCancelHandler(() {
      playing = false;
      notifyListeners();
    });
    _t.setErrorHandler((_) {
      playing = false;
      notifyListeners();
    });
  }

  Future<void> play(List<String> verses, String lang, {int from = 0}) async {
    _v = verses;
    _lang = lang;
    _stop = false;
    playing = true;
    current = from;
    await _t.setLanguage(lang == 'en' ? 'en-US' : 'ar');
    await _t.setSpeechRate(rate);
    notifyListeners();
    await _t.speak(_v[current]);
  }

  Future<void> _next() async {
    if (_stop) return;
    if (current + 1 < _v.length) {
      current++;
      notifyListeners();
      await _t.speak(_v[current]);
    } else {
      playing = false;
      current = -1;
      notifyListeners();
      onFinished?.call();
    }
  }

  Future<void> setRate(double r) async {
    rate = r;
    await _t.setSpeechRate(r);
    notifyListeners();
  }

  Future<void> stop() async {
    _stop = true;
    playing = false;
    current = -1;
    await _t.stop();
    notifyListeners();
  }

  String get lang => _lang;

  @override
  void dispose() {
    _t.stop();
    super.dispose();
  }
}
