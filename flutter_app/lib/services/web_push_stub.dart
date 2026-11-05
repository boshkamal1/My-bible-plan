Future<Map<String, dynamic>> subscribeWebPush() async =>
    throw UnsupportedError('Web only');
String webPushPermission() => 'unsupported';
String? webPushDeviceId() => null;
Future<void> unsubscribeWebPush() async {}
