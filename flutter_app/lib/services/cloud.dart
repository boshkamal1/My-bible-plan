import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/day_util.dart';
import '../state/app_state.dart';

class GroupMember {
  final String uid;
  final String name;
  final int done;
  final int streak;
  final bool readToday;
  final int pct;
  const GroupMember(
      this.uid, this.name, this.done, this.streak, this.readToday, this.pct);
}

class GroupInfo {
  final String code;
  final String name;
  final String owner;
  final Map<String, dynamic>? setup;
  const GroupInfo(this.code, this.name, this.owner, this.setup);
}

class Cloud extends ChangeNotifier {
  bool available = false;
  User? user;
  String? lastError;
  bool busy = false;
  DateTime? lastSync;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      available = true;
      user = FirebaseAuth.instance.currentUser;
      FirebaseAuth.instance.authStateChanges().listen((u) {
        user = u;
        notifyListeners();
      });
    } catch (e) {
      available = false;
      lastError = e.toString();
    }
    notifyListeners();
  }

  bool get signedIn => available && user != null;

  Future<String?> signInGoogle() async {
    if (!available) return 'unavailable';
    try {
      final g = await GoogleSignIn().signIn();
      if (g == null) return 'cancelled';
      final a = await g.authentication;
      final cred = GoogleAuthProvider.credential(
          accessToken: a.accessToken, idToken: a.idToken);
      await FirebaseAuth.instance.signInWithCredential(cred);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signInEmail(String email, String pass,
      {bool create = false}) async {
    if (!available) return 'unavailable';
    try {
      if (create) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email.trim(), password: pass);
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email.trim(), password: pass);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    if (!available) return;
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  Future<String?> deleteAccount(AppState s) async {
    if (!signedIn) return 'unavailable';
    final u = user!;
    try {
      await _db.collection('users').doc(u.uid).delete();
      for (final c in List<String>.from(s.groupCodes)) {
        await _db
            .collection('groups')
            .doc(c)
            .collection('members')
            .doc(u.uid)
            .delete();
      }
      await u.delete();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code == 'requires-recent-login'
          ? 'requires-recent-login'
          : (e.message ?? e.code);
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> sync(AppState s) async {
    if (!signedIn) return;
    busy = true;
    notifyListeners();
    try {
      final ref = _db.collection('users').doc(user!.uid);
      final snap = await ref.get();
      if (snap.exists) {
        s.applyRemote(snap.data()!);
      }
      final data = s.toMap(cloud: true);
      if (!snap.exists || ((snap.data()?['t'] as num?)?.toInt() ?? 0) <= s.t) {
        await ref.set(data);
      }
      lastSync = DateTime.now();
      lastError = null;
      await pushMemberStats(s);
    } catch (e) {
      lastError = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  Future<void> pushMemberStats(AppState s) async {
    if (!signedIn || s.groupCodes.isEmpty) return;
    final st = s.streak;
    final name = s.displayName.isNotEmpty
        ? s.displayName
        : (user!.displayName ?? user!.email?.split('@').first ?? '—');
    for (final c in s.groupCodes) {
      try {
        await _db
            .collection('groups')
            .doc(c)
            .collection('members')
            .doc(user!.uid)
            .set({
          'name': name,
          'done': s.totalDone,
          'pct': (s.percent * 100).round(),
          'streak': st.cur,
          'readDay': st.readToday ? dayStr(s.today) : '',
          'updated': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  String _newCode() {
    const a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => a[r.nextInt(a.length)]).join();
  }

  Future<String?> createGroup(AppState s, String name) async {
    if (!signedIn) return 'signin';
    try {
      final code = _newCode();
      await _db.collection('groups').doc(code).set({
        'name': name.trim(),
        'owner': user!.uid,
        'setup': s.setup?.toJson(),
        'created': FieldValue.serverTimestamp(),
      });
      s.addGroup(code);
      await pushMemberStats(s);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> joinGroup(AppState s, String code) async {
    if (!signedIn) return 'signin';
    try {
      final c = code.trim().toUpperCase();
      final d = await _db.collection('groups').doc(c).get();
      if (!d.exists) return 'notfound';
      s.addGroup(c);
      await pushMemberStats(s);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> leaveGroup(AppState s, String code) async {
    try {
      if (signedIn) {
        await _db
            .collection('groups')
            .doc(code)
            .collection('members')
            .doc(user!.uid)
            .delete();
      }
    } catch (_) {}
    s.removeGroup(code);
  }

  Future<GroupInfo?> groupInfo(String code) async {
    try {
      final d = await _db.collection('groups').doc(code).get();
      if (!d.exists) return null;
      final m = d.data()!;
      return GroupInfo(
          code,
          (m['name'] as String?) ?? code,
          (m['owner'] as String?) ?? '',
          (m['setup'] as Map?)?.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<List<GroupMember>> members(String code) async {
    try {
      final q =
          await _db.collection('groups').doc(code).collection('members').get();
      final l = q.docs.map((d) {
        final m = d.data();
        return GroupMember(
          d.id,
          (m['name'] as String?) ?? '—',
          (m['done'] as num?)?.toInt() ?? 0,
          (m['streak'] as num?)?.toInt() ?? 0,
          (m['readDay'] as String?) == dayStr(todayNum()),
          (m['pct'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      l.sort((a, b) => b.done.compareTo(a.done));
      return l;
    } catch (_) {
      return [];
    }
  }
}
