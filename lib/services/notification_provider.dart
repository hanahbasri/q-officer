import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _notifications = [];
  bool _initialized = false;

  NotificationProvider() {
    _loadNotifications();
  }

  List<Map<String, dynamic>> get notifications => List.from(_notifications);

  // Mendapatkan jumlah notifikasi yang belum dibaca
  int get unreadCount => _notifications.where((n) => n['isRead'] == false).length;

  // Mendapatkan notifikasi yang diurutkan berdasarkan waktu (terbaru dulu)
  List<Map<String, dynamic>> get sortedNotifications {
    final sorted = List<Map<String, dynamic>>.from(_notifications);
    sorted.sort((a, b) =>
        (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0)
    );
    return sorted;
  }

  // Menambahkan notifikasi baru dan menyimpannya secara persisten
  void addNotification(Map<String, dynamic> data) {
    // Pastikan flag isRead diatur
    if (!data.containsKey('isRead')) {
      data['isRead'] = false;
    }

    if (!data.containsKey('timestamp')) {
      data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    }

    _notifications.insert(0, Map<String, dynamic>.from(data)); // Menambahkan ke bagian atas daftar
    _saveNotifications(); // Menyimpan notifikasi secara persisten
    notifyListeners();
  }

  // Menandai notifikasi sebagai sudah dibaca
  void markAsRead(int index) {
    if (index >= 0 && index < _notifications.length) {
      _notifications[index]['isRead'] = true;
      _saveNotifications();
      notifyListeners();
    }
  }

  // Menandai semua notifikasi sebagai sudah dibaca
  void markAllAsRead() {
    for (var notification in _notifications) {
      notification['isRead'] = true;
    }
    _saveNotifications();
    notifyListeners();
  }

  // Menghapus notifikasi
  void removeNotification(int index) {
    if (index >= 0 && index < _notifications.length) {
      _notifications.removeAt(index);
      _saveNotifications();
      notifyListeners();
    }
  }

  // Menghapus semua notifikasi
  void clear() {
    _notifications.clear();
    _saveNotifications();
    notifyListeners();
  }

  // Memuat notifikasi dari shared preferences
  Future<void> _loadNotifications() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString('notifications');

      if (notificationsJson != null) {
        final List<dynamic> decoded = json.decode(notificationsJson);
        _notifications.clear();
        _notifications.addAll(decoded.map((item) => Map<String, dynamic>.from(item)).toList());
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
    }
  }

  // Menyimpan notifikasi ke shared preferences
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notifications', json.encode(_notifications));
    } catch (e) {
      debugPrint('❌ Error saving notifications: $e');
    }
  }
}