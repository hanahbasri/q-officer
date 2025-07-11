import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:q_officer_barantin/services/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'surat_tugas_service.dart';

class HistoryApiService {
  static const String _baseUrl = 'https://esps.karantinaindonesia.go.id/api-officer/riwayat';
  static const String _apiToken = 'Basic bXJpZHdhbjpaPnV5JCx+NjR7KF42WDQm'; // Token otorisasi Anda

  static Future<bool> sendTaskStatusUpdate({
    required BuildContext context,
    required String idSuratTugas,
    required String status, // "terima" atau "selesai"
    required String keterangan,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false); //
    final String? userNip = authProvider.userNip; //

    if (userNip == null || userNip.isEmpty) {
      if (kDebugMode) {
        print('Error: NIP pengguna tidak ditemukan untuk mengirim status riwayat.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim status: NIP pengguna tidak valid.'), backgroundColor: Colors.red),
      );
      return false;
    }
    final String? idPetugas = await SuratTugasService.getIdPetugasByNip(userNip, idSuratTugas); //
    if (idPetugas == null || idPetugas.isEmpty) {
      if (kDebugMode) {
        print('Error: id_petugas tidak ditemukan untuk NIP $userNip dan ST $idSuratTugas.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim status: ID Petugas tidak ditemukan.'), backgroundColor: Colors.red),
      );
      return false;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': _apiToken,
    };

    final String currentTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final body = json.encode({
      "id_surat_tugas": idSuratTugas,
      "id_petugas": idPetugas,
      "status": status,
      "keterangan": keterangan,
      "time": currentTime,
    });

    if (kDebugMode) {
      print('Mengirim status tugas:');
      print('URL: $_baseUrl');
      print('Headers: $headers');
      print('Body: $body');
    }

    try {
      final request = http.Request('POST', Uri.parse(_baseUrl));
      request.headers.addAll(headers);
      request.body = body;

      final http.StreamedResponse response = await request.send().timeout(const Duration(seconds: 30));

      final responseString = await response.stream.bytesToString();
      if (kDebugMode) {
        print('API Response Status Code: ${response.statusCode}');
        print('API Response Body: $responseString');
      }

      if (response.statusCode == 200) {
        try {
          final decodedResponse = json.decode(responseString);
          if (decodedResponse is Map && decodedResponse['status'] == true) {
            if (kDebugMode) {
              print('Status tugas berhasil dikirim ke API.');
            }
            return true;
          } else {
            if (kDebugMode) {
              print('Gagal mengirim status tugas ke API: ${decodedResponse['message'] ?? 'Status false dari server'}');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Server merespons gagal: ${decodedResponse['message'] ?? 'Operasi gagal'}'), backgroundColor: Colors.orange),
            );
            return false;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Status tugas berhasil dikirim ke API (respons bukan JSON valid, tapi status 200).');
          }
          return true;
        }
      } else {
        if (kDebugMode) {
          print('Gagal mengirim status tugas ke API. Status: ${response.statusCode}, Alasan: ${response.reasonPhrase}, Body: $responseString');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim status: ${response.reasonPhrase ?? "Error tidak diketahui"} (${response.statusCode})'), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saat mengirim status tugas: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan jaringan: ${e.toString().substring(0, (e.toString().length > 50) ? 50 : e.toString().length)}...'), backgroundColor: Colors.red),
      );
      return false;
    }
  }
}