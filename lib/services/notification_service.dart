import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

  // Replace with your actual VAPID key from Firebase Console
  // Project Settings → Cloud Messaging → Web Push certificates
  static const _vapidKey =
      'BA-4i1MBt_y1zVmZIdtWvPCRt_B7qGMGouoTthcjxAJpgT4GkK6XGwtlYqfbpH6Y54A3Ho_7wLPq-KDethZPyuk';

  static Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _saveToken();
    }

    // onTokenRefresh works on web too
    _messaging.onTokenRefresh.listen((token) async {
      await _updateToken(token);
    });

    // onMessage works on web when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground notification: ${message.notification?.title}');
    });
  }

  static Future<void> _saveToken() async {
    final token = await _messaging.getToken(
      // VAPID key is required on web, ignored on mobile
      vapidKey: kIsWeb ? _vapidKey : null,
    );
    if (token == null) return;
    await _updateToken(token);
  }

  static Future<void> _updateToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('User').doc(user.uid).update({
      'fcm_token': token,
    });
  }

  static Future<void> clearToken() async {
    // Removed kIsWeb guard — web needs cleanup too
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('User').doc(user.uid).update({
      'fcm_token': FieldValue.delete(),
    });
  }
}
