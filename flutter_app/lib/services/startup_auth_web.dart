import 'dart:js_interop';

@JS('bibleHasSavedSignIn')
external JSPromise<JSBoolean> _savedSession();
Future<bool> hasSavedCloudSession() async {
  try {
    return (await _savedSession().toDart).toDart;
  } catch (_) {
    return true;
  }
}

@JS('biblePrepareFirebase')
external JSPromise<JSBoolean> _prepareFirebase();
Future<void> prepareFirebaseWeb() async {
  await _prepareFirebase().toDart;
}
