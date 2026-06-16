import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'web_notification.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
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

    _messaging.onTokenRefresh.listen((token) async {
      await _updateToken(token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      print('Foreground notification: $title');

      if (kIsWeb) {
        showWebNotification(title, body);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped: ${message.notification?.title}');
    });
  }

  static Future<void> _saveToken() async {
    final token = await _messaging.getToken(
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('User').doc(user.uid).update({
      'fcm_token': FieldValue.delete(),
    });
  }
}
