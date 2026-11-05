import 'package:firebase_core/firebase_core.dart';

/// Web Firebase settings are supplied at build time so the public config can
/// be generated from the Firebase console without committing account data.
class DefaultFirebaseOptions {
  static FirebaseOptions get web {
    return const FirebaseOptions(
      apiKey: 'AIzaSyANy9P2Kw26eAx74NUSaiW1iWlndJv_ZDk',
      appId: '1:765669491597:web:af8d38bce20479fabe73c4',
      messagingSenderId: '765669491597',
      projectId: 'bible-plan-boshkamal-20261101',
      authDomain: 'bible-plan-boshkamal-20261101.firebaseapp.com',
      storageBucket: 'bible-plan-boshkamal-20261101.firebasestorage.app',
    );
  }
}
