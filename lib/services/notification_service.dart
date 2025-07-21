import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../main.dart';
import '../services/notification_provider.dart';
import 'auth_provider.dart';

class NotificationUtils {
  static bool isSuratTugasNotification(Map<String, dynamic>? notifData) {
    if (notifData == null) return false;

    if (notifData.containsKey('type') && notifData['type'] == 'surat_tugas') {
      return true;
    }

    if (notifData.containsKey('title')) {
      String title = notifData['title'].toString().toLowerCase();
      if (title.contains('surat tugas') || title.contains('pemeriksaan')) {
        return true;
      }
    }

    if (notifData.containsKey('notification') &&
        notifData['notification'] is Map &&
        notifData['notification'].containsKey('title')) {
      String title = notifData['notification']['title'].toString().toLowerCase();
      if (title.contains('surat tugas') || title.contains('pemeriksaan')) {
        return true;
      }
    }

    return false;
  }
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
  FlutterLocalNotificationsPlugin();

  static late NotificationProvider _notificationProvider;

  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> initialize(BuildContext context) async {
    _notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    await initFirebaseOnce();

    NotificationSettings settings = await _messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print("🔔 Notifikasi diizinkan");

      String? fcmToken = await _messaging.getToken();
      if (kDebugMode && fcmToken != null) print("📲 FCM Token: $fcmToken");

      const androidInit = AndroidInitializationSettings('@drawable/logo_barantin');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationClick(response.payload);
        },
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleIncomingMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message.data);
      });

      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          _handleNotificationClick(message.data);
        }
      });

      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) print("📲 FCM Token refreshed: $newToken");
        try {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.isLoggedIn) {
            authProvider.sendFcmTokenToServer();
          }
        } catch (e) {
          if (kDebugMode) print("❌ Error accessing AuthProvider after token refresh: $e");
        }
      });
    } else {
      if (kDebugMode) print("❌ Notifikasi tidak diizinkan oleh pengguna");
    }
  }

  static void _handleIncomingMessage(RemoteMessage message) {
    final notif = message.notification;
    final title = notif?.title ?? message.data['title'] ?? 'Q-Officer';
    final body = notif?.body ?? message.data['body'] ?? '';

    _notificationProvider.addNotification({
      'title': title,
      'body': body,
      'data': message.data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
    });

    const androidDetails = AndroidNotificationDetails(
      'barantin_channel',
      'Badan Karantina Indonesia Notifications',
      channelDescription: 'Notifikasi Pemeriksaan Lapangan',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/logo_barantin',
    );
    const notifDetails = NotificationDetails(android: androidDetails);

    _localNotif.show(
      notif.hashCode,
      title,
      body,
      notifDetails,
      payload: message.data.toString(),
    );
  }

  static void _handleNotificationClick(dynamic payload) {
    if (payload == null || navigatorKey?.currentState == null) return;

    Map<String, dynamic> notifData;
    if (payload is String) {
      notifData = _parseStringPayload(payload);
    } else if (payload is Map) {
      notifData = Map<String, dynamic>.from(payload);
    } else {
      return;
    }
    _addNotificationToHistory(notifData);
    _navigateBasedOnNotificationType(notifData);
  }

  static void _addNotificationToHistory(Map<String, dynamic> notifData) {
    String title = notifData['title'] ?? notifData['notification']?['title'] ?? 'Q-Officer';
    String body = notifData['body'] ?? notifData['notification']?['body'] ?? '';

    int timestamp = notifData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

    bool alreadyExists = _notificationProvider.notifications.any(
            (notification) => notification['timestamp'] == timestamp
    );

    if (!alreadyExists) {
      _notificationProvider.addNotification({
        'title': title,
        'body': body,
        'data': notifData,
        'timestamp': timestamp,
        'isRead': false,
      });
    }
  }

  static void _navigateBasedOnNotificationType(Map<String, dynamic> notifData) {
    bool isSuratTugas = false;

    if (notifData.containsKey('type') && notifData['type'] == 'surat_tugas') {
      isSuratTugas = true;
    }
    else if (notifData.containsKey('title')) {
      String title = notifData['title'].toString().toLowerCase();
      if (title.contains('surat tugas') || title.contains('pemeriksaan')) {
        isSuratTugas = true;
      }
    }

    else if (notifData.containsKey('notification') &&
        notifData['notification'] is Map &&
        notifData['notification'].containsKey('title')) {
      String title = notifData['notification']['title'].toString().toLowerCase();
      if (title.contains('surat tugas') || title.contains('pemeriksaan')) {
        isSuratTugas = true;
      }
    }

    if (isSuratTugas) {
      navigatorKey!.currentState!.pushNamed('/surat-tugas');
    } else {
      navigatorKey!.currentState!.pushNamed(
        '/notif-detail',
        arguments: notifData,
      );
    }
  }

  static Map<String, dynamic> _parseStringPayload(String payload) {
    try {
      if (payload.startsWith('{') && payload.endsWith('}')) {
        return Map<String, dynamic>.from(
            jsonDecode(payload) as Map<dynamic, dynamic>
        );
      } else {
        Map<String, dynamic> result = {};
        payload = payload.replaceAll('{', '').replaceAll('}', '');
        List<String> pairs = payload.split(',');

        for (String pair in pairs) {
          List<String> keyValue = pair.split(':');
          if (keyValue.length == 2) {
            String key = keyValue[0].trim();
            String value = keyValue[1].trim();
            key = key.replaceAll('"', '').replaceAll("'", '');
            value = value.replaceAll('"', '').replaceAll("'", '');
            result[key] = value;
          }
        }
        return result;
      }
    } catch (e) {
      if (kDebugMode) print("❌ Error parsing payload: $e");
      return {};
    }
  }

  static Future<void> testNotification({String title = 'Test Notification', String body = 'This is a test notification'}) async {
    _notificationProvider.addNotification({
      'title': title,
      'body': body,
      'data': {'type': 'test'},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
    });

    const androidDetails = AndroidNotificationDetails(
      'barantin_channel',
      'Badan Karantina Indonesia Notifications',
      channelDescription: 'Notifikasi Pemeriksaan Lapangan',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/logo_barantin',
    );
    const notifDetails = NotificationDetails(android: androidDetails);

    await _localNotif.show(
      DateTime.now().millisecond,
      title,
      body,
      notifDetails,
      payload: json.encode({'title': title, 'body': body, 'type': 'test'}),
    );
  }

  static Future<void> testSuratTugasNotification() async {
    final Map<String, dynamic> suratTugasNotifData = {
      'title': 'Surat Tugas Baru 📢',
      'body': 'Anda memiliki surat tugas baru yang perlu ditindaklanjuti',
      'data': {'type': 'surat_tugas'},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
    };

    _notificationProvider.addNotification(suratTugasNotifData);

    const androidDetails = AndroidNotificationDetails(
      'barantin_channel',
      'Badan Karantina Indonesia Notifications',
      channelDescription: 'Notifikasi Pemeriksaan Lapangan',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/logo_barantin',
    );
    const notifDetails = NotificationDetails(android: androidDetails);

    await _localNotif.show(
      DateTime.now().millisecond,
      suratTugasNotifData['title'],
      suratTugasNotifData['body'],
      notifDetails,
      payload: json.encode(suratTugasNotifData['data']..addAll({ // Pastikan payload mencakup title dan body untuk parsing
        'title': suratTugasNotifData['title'],
        'body': suratTugasNotifData['body']
      })),
    );
  }

  static dynamic jsonDecode(String source) {
    try {
      return json.decode(source);
    } catch (e) {
      if (kDebugMode) print("❌ Error decoding JSON: $e");
      return {};
    }
  }
}