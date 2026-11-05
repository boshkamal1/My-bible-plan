import 'dart:js_interop';

@JS('downloadBibleBackup')
external void _download(JSString text, JSString filename);

Future<String?> downloadBackup(String text, String filename) async {
  _download(text.toJS, filename.toJS);
  return null;
}
