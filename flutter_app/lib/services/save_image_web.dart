import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('downloadProgressImage')
external void _download(JSString data);

Future<String?> saveProgressImage(Uint8List bytes) async {
  _download('data:image/png;base64,${base64Encode(bytes)}'.toJS);
  return null;
}
