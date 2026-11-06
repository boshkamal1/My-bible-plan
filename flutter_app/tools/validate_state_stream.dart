import 'dart:convert';
import 'dart:io';
import '../lib/core/data_backup.dart';
const defaults={'lang':'ar','tr':'svd','fs':20,'theme':0,'rem':true,'risk':true,'rh':8,'rm':0,'welcome':false,'name':''};
Future<void> main() async {
  var users=0,invalid=0;
  final groups=<dynamic>[],issues=<dynamic>[];
  await for(final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if(line.isEmpty)continue;
    final record=jsonDecode(line);
    try {
      if(record['kind']=='user') {
        DataBackup.normalizeState(Map<String,dynamic>.from(record['data']),settings:defaults);
        users++;
      } else if(record['kind']=='group') {
        final normalized=DataBackup.normalizeState({'setup':record['setup']},settings:defaults);
        groups.add({'index':record['index'],'setup':normalized['setup']});
      }
    } catch (e) { invalid++; issues.add({'kind':record['kind'],'type':e.runtimeType.toString(),
      'category':e is FormatException ? e.message : 'decode-failed'}); }
  }
  // Stdout is captured by the parent migration tool, never echoed with user data.
  stdout.writeln(jsonEncode({'validatedUsers':users,'invalidRecords':invalid,'issues':issues,'groups':groups}));
  if(invalid>0)exitCode=1;
}
