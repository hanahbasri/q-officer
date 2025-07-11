import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotifDetailScreen extends StatelessWidget {
  const NotifDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    String title = 'Detail Notifikasi';
    String body = '';
    Map<String, dynamic>? data;
    int? timestamp;

    if (arguments is Map<String, dynamic>) {
      title = arguments['title'] ?? title;
      body = arguments['body'] ?? '';
      data = arguments['data'] as Map<String, dynamic>?;
      timestamp = arguments['timestamp'] as int?;
    } else if (arguments is String) {
      body = arguments;
    }

    final dateString = timestamp != null
        ? DateFormat('dd MMMM yyyy, HH:mm:ss').format(
        DateTime.fromMillisecondsSinceEpoch(timestamp)
    )
        : '';

    // Cek apakah ini adalah notifikasi surat tugas
    bool isSuratTugas = false;
    if (data != null && data.containsKey('type') && data['type'] == 'surat_tugas') {
      isSuratTugas = true;
    } else if (title.toLowerCase().contains('surat tugas')) {
      isSuratTugas = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timestamp != null) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Waktu Diterima',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              dateString,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const Text(
              'Isi Notifikasi:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF522E2E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                body,
                style: const TextStyle(fontSize: 16),
              ),
            ),

            if (isSuratTugas) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEFF1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.assignment,
                      size: 48,
                      color: Color(0xFF522E2E),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Notifikasi Surat Tugas 📢',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF522E2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Anda menerima surat tugas baru yang perlu ditindaklanjuti.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/surat-tugas');
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('Lihat Surat Tugas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF522E2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}