import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class GetUserInfo {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // One-shot read of a single field value.
  Future<dynamic> getFieldValue(String fieldname) async {
    final snap = await _db.ref().child("users").child(_uid).once();
    return (snap.snapshot.value as Map?)?[fieldname];
  }

  // One-shot read of the coin balance.
  Future<int> getCoin() async {
    final snap = await _db.ref().child("users").child(_uid).child("coin").once();
    return (snap.snapshot.value as int?) ?? 0;
  }

  Future<dynamic> getProfilePic() async {
    final snap = await _db.ref().child("users").child(_uid).once();
    return (snap.snapshot.value as Map?)?["profilePic"];
  }

  Future<void> setProfilePic(dynamic value) async {
    await _db.ref().child("users").child(_uid).update({"profilePic": value});
  }

  Future<void> setUsername(dynamic value) async {
    await _db.ref().child("users").child(_uid).update({"username": value});
  }

  // Returns a StreamSubscription the caller MUST cancel (e.g. in dispose()).
  // Listens directly on the specific field path so only changes to that field
  // trigger the callback — no cross-field noise, no listener leaks.
  //
  // onValue fires immediately with the current value AND on every future change,
  // so you don't need a separate getCoin() call when using this.
  StreamSubscription<DatabaseEvent> detectChange(
    String field,
    void Function(dynamic value) callback,
  ) {
    return _db
        .ref()
        .child("users")
        .child(_uid)
        .child(field)
        .onValue
        .listen((ev) => callback(ev.snapshot.value));
  }
}
