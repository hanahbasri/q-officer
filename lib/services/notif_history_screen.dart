import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:q_officer_barantin/main.dart';
import '../services/notification_provider.dart';

class NotifHistoryScreen extends StatelessWidget {
  const NotifHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final notifs = notifProvider.sortedNotifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Notifikasi'),
        actions: [
          if (notifProvider.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              tooltip: 'Tandai semua sudah dibaca',
              onPressed: () {
                notifProvider.markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua notifikasi ditandai sudah dibaca')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Hapus semua notifikasi',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Semua Notifikasi'),
                  content: const Text('Apakah Anda yakin ingin menghapus semua notifikasi?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        notifProvider.clear();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Semua notifikasi dihapus')),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: notifs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('images/not_found.png', height: 100, width: 100),
            const SizedBox(height: 16),
            const Text(
              'Belum ada notifikasi',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: notifs.length,
        itemBuilder: (context, index) {
          final notif = notifs[index];
          final bool isRead = notif['isRead'] ?? false;
          final timestamp = notif['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(notif['timestamp'])
              : DateTime.now();

          final String timeString = DateFormat('dd MMM yyyy, HH:mm').format(timestamp);

          final Map<String, dynamic>? data = notif['data'] as Map<String, dynamic>?;

          // Deteksi apakah ini notifikasi surat tugas
          bool isSuratTugas = false;
          if (data != null && data.containsKey('type') && data['type'] == 'surat_tugas') {
            isSuratTugas = true;
          } else if (notif['title'] != null &&
              notif['title'].toString().toLowerCase().contains('surat tugas')) {
            isSuratTugas = true;
          }

          return Dismissible(
            key: Key('notif-${notif['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}-$index'),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              notifProvider.removeNotification(index);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifikasi dihapus')),
              );
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: isRead ? Colors.white : Color(0xFFFFF8E1),
              elevation: isRead ? 1 : 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isRead ? Colors.transparent : MyApp.karantinaBrown.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  notif['title'] ?? 'Tanpa Judul',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      notif['body'] ?? 'Tanpa Isi',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (isSuratTugas)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF522E2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Surat Tugas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          timeString,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                leading: CircleAvatar(
                  backgroundColor: isSuratTugas ? MyApp.karantinaBrown : MyApp.karantinaBrown,
                  child: Icon(
                    isSuratTugas ? Icons.assignment : Icons.notifications,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onTap: () {
                  if (!isRead) {
                    notifProvider.markAsRead(index);
                  }

                  // Navigasi berdasarkan tipe notifikasi
                  if (isSuratTugas) {
                    Navigator.pushNamed(context, '/surat-tugas');
                  } else {
                    Navigator.pushNamed(
                      context,
                      '/notif-detail',
                      arguments: notif,
                    );
                  }
                },
                trailing: !isRead
                    ? Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}