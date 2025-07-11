import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:q_officer_barantin/models/role_detail.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:q_officer_barantin/databases/db_helper.dart';
import 'package:html/parser.dart' show parse;
import 'package:q_officer_barantin/services/surat_tugas_service.dart';

class AuthKeys {
  static const authToken = "auth_token";
  static const uid = "uid";
  static const username = "username";
  static const userId = "user_id";
  static const nip = "nip";
  static const fullName = "full_name";
  static const email = "email";
  static const userRoles = "user_roles";
  static const userPhotoPath = "user_photo_path";
  static const nik = "nik";
  static const idPegawai = "id_pegawai";
  static const upt = "upt";
}

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoggedIn = false;
  String? userName;
  String? userId;
  String? nip;
  String? userFullName;
  String? userEmail;
  String? accessToken;
  String? uid;
  List<RoleDetail> userRoles = [];
  String? nik;
  String? idPegawai;
  String? upt;
  String? userUptName;

  String? _userPhotoPath;
  String? get userPhotoPath => _userPhotoPath;

  bool get isLoggedIn => _isLoggedIn;
  static final Map<String, String> _uptDataMap = {};

  Future<void> _loadAndParseUptData() async {
    if (_uptDataMap.isNotEmpty) {
      return;
    }
    try {
      final String htmlString = await rootBundle.loadString('dataUPT/master_upt.htm');
      var document = parse(htmlString);
      var table = document.querySelector('table');
      if (table != null) {
        var rows = table.querySelectorAll('tr');
        for (var i = 1; i < rows.length; i++) {
          var cells = rows[i].querySelectorAll('td');
          if (cells.length >= 4) {
            String uptId = cells[0].text.trim();
            String uptNamaResmi = cells[3].text.trim();
            _uptDataMap[uptId] = uptNamaResmi;
          }
        }
        debugPrint("✅ Data UPT berhasil dimuat dan diparsing. Total: ${_uptDataMap.length} UPT.");
      }
    } catch (e) {
      debugPrint("❌ Error saat memuat atau parsing data UPT: $e");
    }
  }

  Future<void> _resolveUserUptName() async {
    if (upt != null && upt!.isNotEmpty) {
      if (_uptDataMap.isEmpty) {
        await _loadAndParseUptData();
      }
      userUptName = _uptDataMap[upt];
      if (userUptName == null) {
        debugPrint("⚠️ Nama UPT untuk kode '$upt' tidak ditemukan di master_upt.htm.");
      } else {
        debugPrint("ℹ️ Nama UPT untuk kode '$upt' ditemukan: $userUptName");
      }
    } else {
      userUptName = null;
    }
  }

  Future<void> checkLoginStatus() async {
    try {
      final token = await _secureStorage.read(key: AuthKeys.authToken);
      _isLoggedIn = token != null;

      if (_isLoggedIn) {
        accessToken = token;
        uid = await _secureStorage.read(key: AuthKeys.uid);
        userName = await _secureStorage.read(key: AuthKeys.username) ?? "Guest";
        userId = await _secureStorage.read(key: AuthKeys.userId) ?? "";
        nip = await _secureStorage.read(key: AuthKeys.nip) ?? "";
        userFullName = await _secureStorage.read(key: AuthKeys.fullName) ?? "";
        userEmail = await _secureStorage.read(key: AuthKeys.email) ?? "";
        nik = await _secureStorage.read(key: AuthKeys.nik);
        idPegawai = await _secureStorage.read(key: AuthKeys.idPegawai);
        upt = await _secureStorage.read(key: AuthKeys.upt);
        await _resolveUserUptName();
        final detilJson = await _secureStorage.read(key: AuthKeys.userRoles);
        if (detilJson != null) {
          try {
            final decoded = jsonDecode(detilJson);
            if (decoded is List) {
              userRoles = decoded
                  .map((e) => RoleDetail.fromJson(e as Map<String, dynamic>))
                  .toList();
            }
          } catch (e) {
            debugPrint("❌ Gagal decode role: $e");
            userRoles = [];
          }
        }
        _userPhotoPath = await _secureStorage.read(key: AuthKeys.userPhotoPath);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error saat cek login: $e");
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.karantinaindonesia.go.id/ums/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final userData = jsonData["data"];
        if (jsonData["status"] == "200" && userData != null) {
          accessToken = userData["accessToken"];
          uid = userData["uid"];
          userName = userData["uname"];
          userFullName = userData["nama"];
          userId = userData["uid"];
          nip = userData["nip"];
          userEmail = userData["email"];
          nik = userData["nik"];
          idPegawai = userData["idpegawai"];
          upt = userData["upt"]?.toString();
          await _resolveUserUptName();
          final detilList = userData["detil"];
          if (detilList is List) {
            userRoles = detilList
                .map((e) => RoleDetail.fromJson(e as Map<String, dynamic>))
                .toList();
          }
          debugPrint("🔍 FIXED Login parsing:");
          debugPrint("   - userId (uid): $userId");
          debugPrint("   - nip: $nip");
          debugPrint("   - userName: $userName");
          debugPrint("   - userFullName: $userFullName");
          await _secureStorage.write(key: AuthKeys.authToken, value: accessToken);
          await _secureStorage.write(key: AuthKeys.uid, value: uid);
          await _secureStorage.write(key: AuthKeys.username, value: userName);
          await _secureStorage.write(key: AuthKeys.userId, value: userId);
          await _secureStorage.write(key: AuthKeys.nip, value: nip);
          await _secureStorage.write(key: AuthKeys.fullName, value: userFullName);
          await _secureStorage.write(key: AuthKeys.email, value: userEmail);
          await _secureStorage.write(key: AuthKeys.nik, value: nik);
          await _secureStorage.write(key: AuthKeys.idPegawai, value: idPegawai);
          await _secureStorage.write(key: AuthKeys.upt, value: upt);
          await _secureStorage.write(key: AuthKeys.userRoles, value: jsonEncode(detilList));
          _userPhotoPath = await _secureStorage.read(key: AuthKeys.userPhotoPath);
          _isLoggedIn = true;
          if (nip != null && nip!.isNotEmpty) {
            try {
              final dbHelper = DatabaseHelper();
              await dbHelper.syncSuratTugasFromApi(nip!);
              debugPrint("✅ Surat tugas berhasil disync setelah login dengan NIP: $nip");
              _precacheMasterData();
            } catch (e) {
              debugPrint("❌ Error sync surat tugas setelah login: $e");
            }
          }
          await sendFcmTokenToServer();
          notifyListeners();
          return true;
        }
      }
      return false;
    } on SocketException {
      debugPrint("⚠️ Tidak ada koneksi internet saat login.");
      return false;
    } catch (e) {
      debugPrint("❌ Login error: $e");
      return false;
    }
  }

  Future<void> sendFcmTokenToServer() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint("❌ FCM token tidak tersedia atau kosong");
        return;
      }
      debugPrint("📲 Mengirim FCM token ke server: $fcmToken");
      debugPrint("🔍 FCM Token length: ${fcmToken.length}");
      if (nip == null || nip!.isEmpty) {
        debugPrint("❌ NIP tidak tersedia");
        return;
      }
      final requestBody = <String, dynamic>{
        "uid": uid!.trim(),
        "uname": (userName ?? "").trim(),
        "nama": (userFullName ?? "").trim(),
        "nip": nip!.trim(),
        "nik": (nik ?? "").trim(),
        "email": (userEmail ?? "").trim(),
        "idpegawai": int.tryParse(idPegawai?.toString() ?? "0") ?? 0,
        "upt": int.tryParse(upt?.toString() ?? "1000") ?? 1000,
        "token": fcmToken.trim(),
      };
      debugPrint("📤 FCM request body: ${json.encode(requestBody)}");
      debugPrint("🔍 Data validation:");
      debugPrint("   - uid: '${requestBody['uid']}'");
      debugPrint("   - nip: '${requestBody['nip']}'");
      debugPrint("   - token length: ${fcmToken.trim().length}");
      final response = await http.post(
        Uri.parse('https://esps.karantinaindonesia.go.id/api-officer/tokenFCM'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic bXJpZHdhbjpaPnV5JCx+NjR7KF42WDQm',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );
      debugPrint("🌐 FCM Response Status: ${response.statusCode}");
      debugPrint("🌐 FCM Response Body: ${response.body}");
      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body) as Map<String, dynamic>;
          if (responseData['status'] == true) {
            debugPrint("✅ FCM token berhasil dikirim ke server");
          } else {
            debugPrint("❌ FCM token gagal: ${responseData['message']}");
          }
        } catch (e) {
          debugPrint("❌ Error parsing response: $e");
          debugPrint("🔍 Raw response: ${response.body}");
        }
      } else {
        debugPrint("❌ FCM request failed with status: ${response.statusCode}");
        debugPrint("🔍 Response: ${response.body}");
      }
    } on SocketException {
      debugPrint("❌ Tidak ada koneksi internet saat mengirim FCM token");
    } catch (e) {
      debugPrint("❌ Error saat mengirim FCM token ke server: $e");
      debugPrint("🔍 Error type: ${e.runtimeType}");
    }
  }

  Future<void> _precacheMasterData() async {
    final dbHelper = DatabaseHelper();
    final List<String> quarantineTypes = ['H', 'T', 'I'];

    debugPrint("🔥 Memulai precaching data master Target/Temuan...");

    for (String type in quarantineTypes) {
      try {
        final apiData = await SuratTugasService.getTargetUjiData(type, 'uraian');
        if (apiData.isNotEmpty) {
          await dbHelper.insertOrUpdateMasterTargetTemuan(type, apiData);
          debugPrint("✅ Precache berhasil untuk jenis karantina: $type");
        } else {
          debugPrint("⚠️ Tidak ada data dari API untuk jenis karantina: $type (saat precache)");
        }
      } catch (e) {
        debugPrint("❌ Gagal precache untuk jenis karantina '$type'. Error: $e");
      }
    }
    debugPrint("✅ Selesai precaching data master.");
  }

  Future<void> logout() async {
    try {
      final lastPhoto = _userPhotoPath;
      await _secureStorage.deleteAll();
      _isLoggedIn = false;
      userName = null;
      userId = null;
      nip = null;
      userFullName = null;
      userEmail = null;
      accessToken = null;
      uid = null;
      userRoles = [];
      nik = null;
      idPegawai = null;
      upt = null;
      userUptName = null;
      if (lastPhoto != null) {
        await _secureStorage.write(key: AuthKeys.userPhotoPath, value: lastPhoto);
        _userPhotoPath = lastPhoto;
      } else {
        _userPhotoPath = null;
      }
      debugPrint("✅ Logout berhasil untuk user yang keluar");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Logout error: $e");
    }
  }

  Future<void> loadPhotoFromDB() async {
    try {
      _userPhotoPath = await _secureStorage.read(key: AuthKeys.userPhotoPath);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Gagal load foto: $e");
    }
  }

  Future<void> savePhotoToDB(String path) async {
    if (path.isNotEmpty && File(path).existsSync()) {
      await _secureStorage.write(key: AuthKeys.userPhotoPath, value: path);
      _userPhotoPath = path;
    } else {
      await _secureStorage.delete(key: AuthKeys.userPhotoPath);
      _userPhotoPath = null;
    }
    notifyListeners();
  }
  List<String> getRoleNames() => userRoles.map((e) => e.roleName).toList();
  String? get userNip => nip;
}