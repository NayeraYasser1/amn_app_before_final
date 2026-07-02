import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsageLogger {
  UsageLogger._();

  static final _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('usage_events');

  static Future<void> logEvent({
    required String type,
    required String name,
    Map<String, dynamic>? data,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    await _collection.add({
      'userId': user?.uid,
      'type': type,
      'name': name,
      'data': data ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> logScreenView(String screenName) async {
    await logEvent(type: 'screen_view', name: screenName);
  }

  static Future<void> logAction(String actionName,
      {Map<String, dynamic>? data}) async {
    await logEvent(type: 'action', name: actionName, data: data);
  }
}

