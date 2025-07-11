import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../main.dart';
import '../services/notification_provider.dart';
import 'auth_provider.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
  FlutterLocalNotificationsPlugin();

  // Menyimpan referensi ke provider
  static late NotificationProvider _notificationProvider;

  // Menyimpan referensi ke navigatorKey untuk navigasi global
  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> initialize(BuildContext context) async {
    // Save reference to provider
    _notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    // Ensure Firebase is ready
    await initFirebaseOnce();

    // Request notification permission
    NotificationSettings settings = await _messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print("🔔 Notifikasi diizinkan");

      // Get FCM token for backend
      String? fcmToken = await _messaging.getToken();
      if (kDebugMode && fcmToken != null) print("📲 FCM Token: $fcmToken");


      // Initialize local notifications
      const androidInit = AndroidInitializationSettings('@drawable/logo_barantin');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle local notification tap
          _handleNotificationClick(response.payload);
        },
      );

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleIncomingMessage(message);
      });

      // Listen for notification clicks (app background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) print("📬 Notif diklik: ${message.data}");
        _handleNotificationClick(message.data);
      });

      // Handle initial message (app opened from notification)
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          if (kDebugMode) print("📬 App dibuka dari notifikasi (terminated state)");
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

    // Tambahkan ke provider notification history
    _notificationProvider.addNotification({
      'title': title,
      'body': body,
      'data': message.data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
    });

    // Tampilkan notifikasi lokal
    const androidDetails = AndroidNotificationDetails(
      'barantin_channel', // Channel ID
      'Badan Karantina Indonesia Notifications', // Channel name
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
      // Konversi string payload ke map (jika dari notifikasi lokal)
      notifData = _parseStringPayload(payload);
    } else if (payload is Map) {
      notifData = Map<String, dynamic>.from(payload);
    } else {
      return;
    }

    if (kDebugMode) print("📬 Handling notification click with data: $notifData");

    _addNotificationToHistory(notifData);
    _navigateBasedOnNotificationType(notifData);

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

    if (isSuratTugas) {
      navigatorKey!.currentState!.pushNamed('/surat-tugas');
    } else {
      navigatorKey!.currentState!.pushNamed(
        '/notif-detail',
        arguments: notifData,
      );
    }
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
      // Default to notification detail
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
    _notificationProvider.addNotification({
      'title': 'Surat Tugas Baru 📢',
      'body': 'Anda memiliki surat tugas baru yang perlu ditindaklanjuti',
      'data': {'type': 'surat_tugas'},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
    });

    // Show local notification
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
      'Surat Tugas Baru 📢',
      'Anda memiliki surat tugas baru yang perlu ditindaklanjuti',
      notifDetails,
      payload: json.encode({
        'title': 'Surat Tugas Baru 📢',
        'body': 'Anda memiliki surat tugas baru yang perlu ditindaklanjuti',
        'type': 'surat_tugas'
      }),
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