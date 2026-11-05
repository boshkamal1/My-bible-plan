import 'dart:io';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> downloadBackup(String text, String filename) async {
  if (Platform.isAndroid || Platform.isIOS) {
    await Share.shareXFiles([
      XFile.fromData(utf8.encode(text),
          mimeType: 'application/json', name: filename)
    ], fileNameOverrides: [
      filename
    ]);
    return null;
  }
  final target = await getSaveLocation(suggestedName: filename);
  if (target == null) return '';
  await File(target.path).writeAsString(text, flush: true);
  return target.path;
}
