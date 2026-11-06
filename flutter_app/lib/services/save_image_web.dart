import 'dart:js_interop';
import 'dart:typed_data';

@JS('downloadProgressImage')
external void _download(JSUint8Array bytes);

Future<String?> saveProgressImage(Uint8List bytes) async {
  _download(bytes.toJS);
  return null;
}
