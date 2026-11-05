import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> saveProgressImage(Uint8List bytes) async {
  Directory? directory;
  try {
    directory = await getDownloadsDirectory();
  } catch (_) {
    // Android uses the app's external storage directory instead.
  }
  if (directory == null && Platform.isAndroid) {
    directory = await getExternalStorageDirectory();
  }
  directory ??= await getApplicationDocumentsDirectory();
  final file = File(
      '${directory.path}${Platform.pathSeparator}bible-plan-progress-${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
