import 'dart:convert';
import 'dart:js_interop';

@JS('biblePushSubscribe')
external JSPromise<JSString> _subscribe();
@JS('biblePushPermission')
external JSString _permission();
@JS('biblePushDeviceId')
external JSString? _deviceId();
@JS('biblePushUnsubscribe')
external JSPromise<JSAny?> _unsubscribe();

Future<Map<String, dynamic>> subscribeWebPush() async {
  final result = (await _subscribe().toDart).toDart;
  return Map<String, dynamic>.from(jsonDecode(result) as Map);
}

String webPushPermission() => _permission().toDart;
String? webPushDeviceId() => _deviceId()?.toDart;
Future<void> unsubscribeWebPush() async {
  await _unsubscribe().toDart;
}
