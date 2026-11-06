import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import '../core/app_check_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/day_util.dart';
import '../core/planner.dart';
import '../core/data_backup.dart';
import '../core/sync_merge.dart';
import '../firebase_options.dart';
import '../state/app_state.dart';
import 'startup_auth_stub.dart'
    if (dart.library.js_interop) 'startup_auth_web.dart';
import 'web_push_stub.dart' if (dart.library.js_interop) 'web_push_web.dart'
    as web_push;

class GroupMember {
  final String uid;
  final String name;
  final int done;
  final int streak;
  final bool readToday;
  final int pct;
  final String status;
  final String role;
  const GroupMember(this.uid, this.name, this.done, this.streak, this.readToday,
      this.pct, this.status, this.role);
}

class GroupInfo {
  final String code;
  final String name;
  final String owner;
  final Map<String, dynamic>? setup;
  const GroupInfo(this.code, this.name, this.owner, this.setup);
}

class Cloud extends ChangeNotifier {
  Cloud({AppState? state}) : _state = state;
  AppState? _state;
  bool available = true;
  bool _initialized = false;
  bool _profileReady = false;
  bool _deleting = false;
  bool _syncing = false;
  bool _syncAgain = false;
  int _authEpoch = 0;
  Future<void>? _initializing;
  Future<void> _profileTask = Future.value();
  StreamSubscription<User?>? _authSub;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  User? user;
  String? lastError;
  bool busy = false;
  DateTime? lastSync;
  String? _lastPushedHash;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> init([AppState? state]) {
    _state ??= state;
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await prepareFirebaseWeb();
      await Firebase.initializeApp(
          options: kIsWeb ? DefaultFirebaseOptions.web : null);
      if (kIsWeb &&
          const ['mybibleplan.web.app', 'bible-plan-boshkamal-20261101.web.app']
              .contains(Uri.base.host)) {
        try {
          await FirebaseAppCheck.instance.activate(
              webProvider: ReCaptchaEnterpriseProvider(kAppCheckSiteKey));
        } catch (_) {
          // Monitoring only: a blocked challenge must not block local reading.
        }
      }
      _initialized = true;
      available = true;
      await _setUser(_auth.currentUser);
      _authSub = _auth.authStateChanges().listen((u) => unawaited(_setUser(u)));
    } catch (_) {
      _initializing = null;
      available = false;
      lastError = 'تعذر الاتصال بالحساب. بياناتك المحلية محفوظة.';
    }
    notifyListeners();
  }

  Future<void> _setUser(User? next) {
    if (user?.uid == next?.uid && _profileReady) return _profileTask;
    final oldUid = user?.uid;
    user = next;
    _lastPushedHash = null;
    _profileReady = false;
    final epoch = ++_authEpoch;
    _profileTask = _profileTask.then((_) async {
      if (epoch != _authEpoch) return;
      final state = _state;
      if (state != null) {
        if (next == null &&
            oldUid != null &&
            state.prefs.getBool('jb-delete-pending:$oldUid') == true) {
          await state.forgetDeletedAccount(oldUid);
        }
        await state.switchAccount(next?.uid);
      }
      if (epoch != _authEpoch) return;
      await state?.prefs.setBool('cloud-used', next != null);
      if (epoch != _authEpoch) return;
      _profileReady = true;
      _deleting = false;
      notifyListeners();
      if (next != null && state != null) unawaited(sync(state));
    }).catchError((Object _) {
      lastError = 'تعذر فتح بيانات الحساب بأمان. حاول مرة تانية.';
      notifyListeners();
    });
    return _profileTask;
  }

  bool get signedIn =>
      _initialized && available && user != null && _profileReady;

  @override
  void dispose() {
    _authEpoch++;
    _authSub?.cancel();
    super.dispose();
  }

  String get webNotificationPermission => web_push.webPushPermission();

  Future<String?> saveWebReminder(AppState state) async {
    if (!signedIn) return 'signin';
    final uid = user!.uid, epoch = _authEpoch;
    try {
      final subscription = await web_push.subscribeWebPush();
      if (epoch != _authEpoch || state.activeUid != uid)
        return 'account-changed';
      final now = DateTime.now();
      var next =
          DateTime(now.year, now.month, now.day, state.remindH, state.remindM);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      if (!signedIn || state.activeUid != user!.uid) return 'account-changed';
      final deviceId = subscription['id'] as String;
      await _db.runTransaction((tx) async {
        final limits = _db.doc('users/$uid/security/deviceLimits');
        final existing = await tx.get(limits);
        if (epoch != _authEpoch || _auth.currentUser?.uid != uid)
          throw StateError('account-changed');
        final ids = Map<String, dynamic>.from(existing.data()?['ids'] ?? {});
        if (!ids.containsKey(deviceId) && ids.length >= 5)
          throw StateError('device-limit');
        ids[deviceId] = true;
        tx.set(limits, {'ids': ids, 'last': deviceId});
        tx.set(_db.doc('pushSubscriptions/$uid/devices/$deviceId'), {
          'subscription': subscription['subscription'],
          'zone': subscription['zone'],
          'hour': state.remindH,
          'minute': state.remindM,
          'enabled': true,
          'nextAt': Timestamp.fromDate(next.toUtc()),
        });
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> disableWebReminder() async {
    if (!signedIn) return;
    final id = web_push.webPushDeviceId();
    if (id != null) {
      await _db
          .collection('pushSubscriptions')
          .doc(user!.uid)
          .collection('devices')
          .doc(id)
          .delete();
    }
    await web_push.unsubscribeWebPush();
  }

  Future<String?> signInGoogle() async {
    await init();
    if (!available) return 'unavailable';
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
        await _setUser(_auth.currentUser);
        return null;
      }
      final g = await GoogleSignIn().signIn();
      if (g == null) return 'cancelled';
      final a = await g.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: a.accessToken,
        idToken: a.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      await _setUser(_auth.currentUser);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signInEmail(
    String email,
    String pass, {
    bool create = false,
  }) async {
    await init();
    if (!available) return 'unavailable';
    try {
      if (create) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: pass,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(),
          password: pass,
        );
      }
      await _setUser(_auth.currentUser);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    await _state?.flush();
    _authEpoch++;
    _profileReady = false;
    try {
      if (!kIsWeb) await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
    await _setUser(null);
  }

  Future<String?> deleteAccount(AppState s, {String? password}) async {
    if (!signedIn) return 'unavailable';
    final u = user!;
    // Reauthentication completes before a deletion marker or data write exists.
    try {
      if (u.providerData.any((p) => p.providerId == 'password')) {
        if (password == null || password.isEmpty || u.email == null)
          return 'password-required';
        await u.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: u.email!, password: password));
      } else if (kIsWeb) {
        await u.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        await u.reauthenticateWithProvider(GoogleAuthProvider());
      }
      await u.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      return e.code;
    }
    if (_auth.currentUser?.uid != u.uid || s.activeUid != u.uid)
      return 'account-changed';
    _deleting = true;
    final deletionEpoch = ++_authEpoch, profileSession = s.sessionRevision;
    final uid = u.uid;
    void checkActor() {
      if (deletionEpoch != _authEpoch ||
          profileSession != s.sessionRevision ||
          _auth.currentUser?.uid != uid ||
          s.activeUid != uid) throw StateError('account-changed');
    }

    try {
      final marker = _db.doc('users/$uid/security/lifecycle');
      final previous = await marker.get();
      checkActor();
      if (!previous.exists)
        await marker.set(
            {'state': 'deleting', 'requestedAt': FieldValue.serverTimestamp()});
      await s.prefs.setBool('jb-delete-pending:$uid', true);
      // Owned groups become permanently closed tombstones; no reusable orphan ACL.
      DocumentSnapshot<Map<String, dynamic>>? after;
      while (true) {
        Query<Map<String, dynamic>> query =
            _db.collection('groups').where('owner', isEqualTo: uid).limit(100);
        if (after != null) query = query.startAfterDocument(after);
        final groups = await query.get();
        checkActor();
        if (groups.docs.isEmpty) break;
        for (final group in groups.docs) {
          checkActor();
          await group.reference.update({'closed': true});
          while (true) {
            final members =
                await group.reference.collection('members').limit(5).get();
            checkActor();
            if (members.docs.isEmpty) break;
            final batch = _db.batch();
            for (final member in members.docs) {
              batch.delete(member.reference);
              batch
                  .delete(_db.doc('users/${member.id}/groupLinks/${group.id}'));
            }
            await batch.commit();
          }
          await group.reference.collection('private').doc('plan').delete();
          await group.reference.set({
            'name': 'مجموعة محذوفة',
            'owner': uid,
            'created': group.data()['created'],
            'closed': true,
            'schemaVersion': 2
          });
        }
        after = groups.docs.last;
      }
      while (true) {
        final links =
            await _db.collection('users/$uid/groupLinks').limit(5).get();
        checkActor();
        if (links.docs.isEmpty) break;
        final batch = _db.batch();
        for (final link in links.docs) {
          batch.delete(_db.doc('groups/${link.id}/members/$uid'));
          batch.delete(link.reference);
        }
        await batch.commit();
      }
      while (true) {
        final devices = await _db
            .collection('pushSubscriptions')
            .doc(uid)
            .collection('devices')
            .limit(100)
            .get();
        checkActor();
        if (devices.docs.isEmpty) break;
        final batch = _db.batch();
        for (final device in devices.docs) {
          batch.delete(device.reference);
        }
        await batch.commit();
      }
      checkActor();
      await _db.doc('users/$uid/security/groupLimits').delete();
      await _db.doc('users/$uid/security/deviceLimits').delete();
      await _db.doc('users/$uid').delete();
      await marker.update({'state': 'data-deleted'});
      checkActor();
      await u.delete();
      await s.forgetDeletedAccount(uid);
      await s.prefs.remove('jb-delete-pending:$uid');
      await _setUser(null);
      return null;
    } on FirebaseAuthException catch (e) {
      lastError =
          'حذف البيانات بدأ. سجّل الدخول من جديد وكرّر حذف الحساب لاستكمال العملية.';
      return e.code;
    } catch (_) {
      lastError =
          'حذف الحساب لم يكتمل. المزامنة متوقفة للحماية؛ كرّر العملية لاستكمالها.';
      return 'deletion-incomplete';
    } finally {
      notifyListeners();
    }
  }

  Future<void> sync(AppState s, {bool force = false}) async {
    if (!signedIn || _deleting || s.activeUid != user?.uid) return;
    final hash = '${readingDataHash(s.toMap(cloud: true))}|${s.displayName}';
    if (!force && hash == _lastPushedHash) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    busy = true;
    final uid = user!.uid, epoch = _authEpoch, revision = s.sessionRevision;
    bool current() =>
        epoch == _authEpoch &&
        revision == s.sessionRevision &&
        s.activeUid == uid &&
        _auth.currentUser?.uid == uid &&
        !_deleting;
    notifyListeners();
    try {
      final settings = Map<String, dynamic>.from(s.toMap()['settings']);
      final local =
          DataBackup.normalizeState(s.toMap(cloud: true), settings: settings);
      final base = DataBackup.normalizeState(s.syncBase, settings: settings);
      final result = await _db.runTransaction<Map<String, dynamic>>((tx) async {
        final marker = await tx.get(_db.doc('users/$uid/security/lifecycle'));
        if (!current()) throw StateError('account-changed');
        if (marker.exists) throw StateError('account-deleting');
        final ref = _db.doc('users/$uid');
        final snap = await tx.get(ref);
        if (!current()) throw StateError('account-changed');
        final raw = snap.data() ?? <String, dynamic>{};
        final remote = DataBackup.normalizeState(raw, settings: settings);
        final merged = mergeReading(base, local, remote);
        DataBackup.normalizeState(merged, settings: settings);
        if (raw['syncVersion'] != 2 ||
            readingDataHash(remote) != readingDataHash(merged))
          tx.set(ref, {
            ...merged,
            'contentHash': readingHash(merged),
            'syncVersion': 2,
            'revision': ((raw['revision'] as int?) ?? 0) + 1,
            't': merged['t'],
            'updatedAt': FieldValue.serverTimestamp()
          });
        return merged;
      });
      if (!current()) return;
      await s.acceptSynced(local, result,
          expectedUid: uid, expectedSession: revision);
      if (!current()) return;
      _lastPushedHash = '${readingDataHash(result)}|${s.displayName}';
      lastSync = DateTime.now();
      lastError = null;
      final links =
          await _db.collection('users/$uid/groupLinks').limit(100).get();
      if (!current()) return;
      final codes = links.docs.map((d) => d.id).toList();
      if (!sameValue(codes.toSet(), s.groupCodes.toSet()) &&
          (codes.toSet().difference(s.groupCodes.toSet()).isNotEmpty ||
              s.groupCodes.toSet().difference(codes.toSet()).isNotEmpty)) {
        s.groupCodes = codes;
        await s.flush();
        s.notifyListeners();
      }
      await pushMemberStats(s);
    } catch (e) {
      if (current()) {
        final marker = e.toString().contains('account-deleting');
        if (marker) _deleting = true;
        lastError = marker
            ? 'الحساب في انتظار استكمال الحذف؛ المزامنة متوقفة.'
            : 'تعذرت المزامنة الآمنة. بياناتك المحلية محفوظة؛ جرّب تاني أو صدّر Backup.';
      }
    } finally {
      _syncing = false;
      busy = false;
      notifyListeners();
      if (_syncAgain) {
        _syncAgain = false;
        if (signedIn && !_deleting) unawaited(sync(s));
      }
    }
  }

  Future<void> pushMemberStats(AppState s) async {
    if (!signedIn || _deleting || s.groupCodes.isEmpty) return;
    final uid = user!.uid, epoch = _authEpoch;
    final st = s.streak;
    final name = s.displayName.isNotEmpty
        ? s.displayName
        : (user!.displayName ?? 'قارئ');
    for (final c in List<String>.from(s.groupCodes)) {
      if (epoch != _authEpoch ||
          _auth.currentUser?.uid != uid ||
          s.activeUid != uid) return;
      try {
        await _db
            .collection('groups')
            .doc(c)
            .collection('members')
            .doc(uid)
            .set({
          'name': name,
          'done': s.totalDone,
          'pct': (s.percent * 100).round(),
          'streak': st.cur,
          'readDay': st.readToday ? dayStr(s.today) : '',
          'updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  String _newCode() {
    const a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => a[r.nextInt(a.length)]).join();
  }

  Future<String?> createGroup(AppState s, String name, Setup groupSetup) async {
    if (!signedIn) return 'signin';
    final uid = user!.uid, epoch = _authEpoch;
    bool current() =>
        uid == _auth.currentUser?.uid &&
        epoch == _authEpoch &&
        s.activeUid == uid &&
        !_deleting;
    try {
      DataBackup.validateSetup(groupSetup.toJson());
      if (name.trim().isEmpty || name.trim().length > 60)
        return 'اسم المجموعة لازم يكون من حرف إلى 60 حرف.';
      final code = _newCode();
      final group = _db.doc('groups/$code');
      final limits = _db.doc('users/$uid/security/groupLimits');
      await _db.runTransaction((tx) async {
        final old = await tx.get(limits);
        if (!current()) throw StateError('account-changed');
        final codes = Map<String, dynamic>.from(old.data()?['codes'] ?? {});
        if (codes.length >= 20) throw StateError('group-limit');
        codes[code] = true;
        tx.set(limits, {'codes': codes, 'last': code});
        tx.set(group, {
          'name': name.trim(),
          'owner': uid,
          'schemaVersion': 2,
          'closed': false,
          'created': FieldValue.serverTimestamp()
        });
      });
      if (!current()) return 'account-changed';
      final batch = _db.batch();
      batch.set(group.collection('private').doc('plan'),
          {'setup': groupSetup.toJson()});
      batch.set(_db.doc('users/$uid/groupLinks/$code'),
          {'code': code, 'created': FieldValue.serverTimestamp()});
      batch.set(group.collection('members').doc(uid), {
        'uid': uid,
        'name': s.displayName.isNotEmpty
            ? s.displayName
            : (user!.displayName ?? 'قارئ'),
        'status': 'approved',
        'role': 'admin',
        'done': 0,
        'streak': 0,
        'pct': 0,
        'readDay': ''
      });
      await batch.commit();
      if (!current()) return 'account-changed';
      s.addGroup(code);
      await pushMemberStats(s);
      return null;
    } catch (e) {
      return e.toString().contains('group-limit')
          ? 'وصلت للحد المتاح: 20 مجموعة.'
          : 'تعذر إنشاء المجموعة. بياناتك الحالية محفوظة.';
    }
  }

  Future<String?> joinGroup(AppState s, String code) async {
    if (!signedIn) return 'signin';
    final uid = user!.uid, epoch = _authEpoch;
    bool current() =>
        _auth.currentUser?.uid == uid &&
        epoch == _authEpoch &&
        s.activeUid == uid;
    try {
      final c = code.trim().toUpperCase();
      final d = await _db.collection('groups').doc(c).get();
      if (!current()) return 'account-changed';
      if (!d.exists || d.data()?['closed'] == true) return 'notfound';
      final ref =
          _db.collection('groups').doc(c).collection('members').doc(uid);
      final existing = await ref.get();
      if (!current()) return 'account-changed';
      final batch = _db.batch();
      if (!existing.exists) {
        batch.set(ref, {
          'uid': uid,
          'name': user!.displayName ?? 'قارئ',
          'status': 'pending',
          'role': 'member',
          'done': 0,
          'streak': 0,
          'pct': 0,
          'readDay': '',
        });
      }
      final link = _db.doc('users/$uid/groupLinks/$c');
      final existingLink = await link.get();
      if (!existingLink.exists)
        batch.set(link, {'code': c, 'created': FieldValue.serverTimestamp()});
      if (!current()) return 'account-changed';
      await batch.commit();
      if (!current()) return 'account-changed';
      s.addGroup(c);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> leaveGroup(AppState s, String code) async {
    if (!signedIn || s.activeUid != user!.uid) return;
    final uid = user!.uid, epoch = _authEpoch;
    try {
      final batch = _db.batch();
      batch.delete(_db.doc('groups/$code/members/$uid'));
      batch.delete(_db.doc('users/$uid/groupLinks/$code'));
      await batch.commit();
      if (epoch == _authEpoch && s.activeUid == uid) s.removeGroup(code);
    } catch (_) {
      lastError = 'تعذر مغادرة المجموعة؛ حاول تاني.';
      notifyListeners();
    }
  }

  Future<GroupInfo?> groupInfo(String code) async {
    final epoch = _authEpoch;
    try {
      final d = await _db.collection('groups').doc(code).get();
      if (!d.exists) return null;
      final m = d.data()!;
      if (m['closed'] == true) return null;
      Map<String, dynamic>? setup;
      try {
        final plan = await _db
            .collection('groups')
            .doc(code)
            .collection('private')
            .doc('plan')
            .get();
        final raw = plan.data()?['setup'];
        if (raw != null) {
          DataBackup.validateSetup(raw);
          setup = Map<String, dynamic>.from(raw);
        }
      } catch (_) {/* Pending members see only the safe join preview. */}
      if (epoch != _authEpoch) return null;
      return GroupInfo(
        code,
        (m['name'] as String?) ?? code,
        (m['owner'] as String?) ?? '',
        setup,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<GroupMember>> members(String code) async {
    final epoch = _authEpoch;
    try {
      final q =
          await _db.collection('groups').doc(code).collection('members').get();
      if (epoch != _authEpoch) return [];
      final l = q.docs.map((d) {
        final m = d.data();
        return GroupMember(
          d.id,
          (m['name'] as String?) ?? '—',
          (m['done'] as num?)?.toInt() ?? 0,
          (m['streak'] as num?)?.toInt() ?? 0,
          (m['readDay'] as String?) == dayStr(todayNum()),
          (m['pct'] as num?)?.toInt() ?? 0,
          (m['status'] as String?) ?? 'approved',
          (m['role'] as String?) ?? 'member',
        );
      }).toList();
      l.sort((a, b) => b.done.compareTo(a.done));
      return l;
    } catch (_) {
      return [];
    }
  }

  Future<String?> myGroupStatus(String code) async {
    if (!signedIn) return null;
    try {
      final doc = await _db
          .collection('groups')
          .doc(code)
          .collection('members')
          .doc(user!.uid)
          .get();
      return doc.data()?['status'] as String? ??
          (doc.exists ? 'approved' : null);
    } catch (_) {
      return null;
    }
  }

  Future<String?> reviewMember(String code, String uid, String status) async {
    if (!signedIn) return 'signin';
    try {
      await _db
          .collection('groups')
          .doc(code)
          .collection('members')
          .doc(uid)
          .update({'status': status});
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setAdmin(String code, String uid, bool admin) async {
    if (!signedIn) return 'signin';
    try {
      await _db
          .collection('groups')
          .doc(code)
          .collection('members')
          .doc(uid)
          .update({'role': admin ? 'admin' : 'member'});
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
