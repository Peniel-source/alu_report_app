import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'models.dart';

//sign in, signup, and read user profile
class AuthRepository {
  final _auth = fb.FirebaseAuth.instance;
  final _users = FirebaseFirestore.instance.collection('users');

  Stream<fb.User?> get authChanges => _auth.authStateChanges();

  Stream<User> watchUser(String uid) =>
      _users.doc(uid).snapshots().map(User.fromDoc);

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signUp(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    final user = User(uid: cred.user!.uid, name: name.trim(), email: email.trim(), role: roleFor(email));
    await _users.doc(user.uid).set(user.toMap());
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateAvatar(String uid, File photo) async {
    final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
    await ref.putFile(photo);
    final link = await ref.getDownloadURL();
    await _users.doc(uid).update({
      'photoUrl': '$link&v=${DateTime.now().millisecondsSinceEpoch}',
    });
  }
}

class IncidentRepository {
  final _db = FirebaseFirestore.instance;
  late final _incidents = _db.collection('incidents');

  Stream<List<Incident>> watchAll() => _incidents
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Incident.fromDoc).toList());

  Stream<List<StatusChange>> watchHistory(String incidentId) => _incidents
      .doc(incidentId)
      .collection('history')
      .orderBy('at')
      .snapshots()
      .map((snap) => snap.docs.map(StatusChange.fromDoc).toList());

  Future<void> submit(Incident incident, File? photo) async {
    final doc = _incidents.doc();

    String? photoUrl;
    if (photo != null) {
      final ref = FirebaseStorage.instance.ref('incidents/${doc.id}.jpg');
      await ref.putFile(photo);
      photoUrl = await ref.getDownloadURL();
    }

    final batch = _db.batch();
    batch.set(doc, incident.toMap()..['photoUrl'] = photoUrl);
    batch.set(
      doc.collection('history').doc(),
      StatusChange(
        status: IncidentStatus.submitted,
        changedBy: incident.reporterName,
        at: DateTime.now(),
      ).toMap(),
    );
    await batch.commit();
  }

  Future<void> advanceStatus(Incident incident, String staffName, {String? note}) async {
    final next = incident.status.next;
    if (next == null) return;

    final doc = _incidents.doc(incident.id);
    final batch = _db.batch();
    batch.update(doc, {'status': next.name});
    batch.set(
      doc.collection('history').doc(),
      StatusChange(status: next, changedBy: staffName, note: note, at: DateTime.now()).toMap(),
    );
    await batch.commit();
  }

  //the Me too button. tap to join or tap again to leave.
  Future<void> toggleSupport(Incident incident, String uid) {
    final already = incident.supporterIds.contains(uid);
    return _incidents.doc(incident.id).update({
      'supporterIds': already
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
  }
}