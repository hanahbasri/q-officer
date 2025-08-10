import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HistoryApiService {
  static final String _baseUrl = dotenv.env['API_RIWAYAT']!;
  static const String _apiToken = 'Basic bXJpZHdhbjpaPnV5JCx+NjR7KF42WDQm';

  static Future<bool> sendTaskStatusUpdate({
    required BuildContext context,
    required String idSuratTugas,
    required String status, // "terima" atau "selesai"
    required String keterangan,
  }) async {
    // Dummy response
    if (kDebugMode) {
      print('✅ (DUMMY) sendTaskStatusUpdate dipanggil untuk ST: $idSuratTugas dengan status: $status dan mengembalikan true.');
      print('🔑 Using API token: $_apiToken');
    }
    return true;
  }
}