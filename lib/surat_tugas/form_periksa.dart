import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../databases/db_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:q_officer_barantin/models/hasil_pemeriksaan.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:q_officer_barantin/services/surat_tugas_service.dart';
import 'package:q_officer_barantin/models/lokasi.dart';
import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';


class FormPeriksa extends StatefulWidget {
  final StLengkap suratTugas;
  final String idSuratTugas;
  final VoidCallback onSelesaiTugas;
  final String userNip;

  const FormPeriksa({
    super.key,
    required this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
    required this.userNip,
  });

  @override
  FormPeriksaState createState() => FormPeriksaState();
}

enum PhotoSource { camera, gallery }

class FormPeriksaState extends State<FormPeriksa> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final uuid = const Uuid();
  late String idPemeriksaan;
  List<Lokasi> lokasiList = [];
  List<Komoditas> komoditasList = [];
  final List<XFile> _originalPickedXFiles = [];
  final List<Uint8List> _uploadedPhotos = [];
  final List<Uint8List> _compressedPhotosForServer = [];
  bool _formSubmitted = false;
  bool _isSubmitting = false;
  bool _isPickingImage = false;
  late AnimationController _searchController;
  static bool _isGlobalPickerLocked = false;

  final Map<String, PhotoSource> _photoSources = {};

  String? selectedTarget;
  String? selectedTemuan;
  String? selectedLokasiId;
  String? selectedLokasiName;
  String? selectedKomoditasId;
  String? selectedKomoditasName;
  double? latitude;
  double? longitude;
  Position? devicePosition;
  String? waktuAmbilPosisi;

  static final ImagePicker _picker = ImagePicker();
  final TextEditingController _metodeController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();

  final Map<String, bool> _fieldErrors = {
    'lokasi': false,
    'target': false,
    'metode': false,
    'temuan': false,
    'komoditas': false,
    'foto': false,
  };

  List<String> targetAndTemuanList = [];
  bool _isLoadingDropdownData = true;
  static const int _maxPhotos = 4;
  late DatabaseHelper _dbHelper;
  static const int _maxTotalServerPayloadKb = 100;
  static const double MAX_ALLOWED_DISTANCE_METERS = 20000000.0;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    idPemeriksaan = uuid.v4();
    lokasiList = widget.suratTugas.lokasi;
    komoditasList = widget.suratTugas.komoditas;

    if (lokasiList.isNotEmpty && selectedLokasiName == null) {
      selectedLokasiName = lokasiList.first.namaLokasi;
      selectedLokasiId = lokasiList.first.idLokasi;
      _lokasiController.text = selectedLokasiName ?? "Lokasi tidak ditentukan";
    } else {
      _lokasiController.text = "Lokasi tidak tersedia";
    }
    if (komoditasList.isNotEmpty && selectedKomoditasName == null) {
      selectedKomoditasName = komoditasList.first.namaKomoditas;
      selectedKomoditasId = komoditasList.first.idKomoditas;
    }

    if (kDebugMode) {
      print('DEBUG: jenisKarantina in FormPeriksa initState: ${widget.suratTugas.jenisKarantina}');
    }

    _loadTargetAndTemuanList();
    ambilPosisiAwal();

    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  Future<void> _loadTargetAndTemuanList() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDropdownData = true;
    });

    String jenisKarantina = widget.suratTugas.jenisKarantina ?? "";
    if (jenisKarantina.isEmpty) {
      if (kDebugMode) {
        print("⚠️ Jenis karantina kosong, tidak dapat memuat data target/temuan.");
      }
      if (mounted) {
        setState(() {
          targetAndTemuanList = [];
          _isLoadingDropdownData = false;
        });
      }
      return;
    }

    try {
      List<String> localData = await _dbHelper.getLocalMasterTargetTemuan(jenisKarantina);

      if (localData.isNotEmpty) {
        if (kDebugMode) {
          print("📦 Data target/temuan dimuat dari DB Lokal untuk jenis: $jenisKarantina");
        }
        if (mounted) {
          setState(() {
            targetAndTemuanList = localData;
            if (targetAndTemuanList.isNotEmpty) {
              selectedTarget ??= targetAndTemuanList.first;
              selectedTemuan ??= targetAndTemuanList.first;
            }
          });
        }
      } else {
        if (kDebugMode) {
          print("🌐 Data target/temuan tidak ditemukan lokal, mengambil dari API untuk jenis: $jenisKarantina");
        }
        final connectivityResult = await Connectivity().checkConnectivity();
        bool isOnline = connectivityResult == ConnectivityResult.mobile ||
            connectivityResult == ConnectivityResult.wifi ||
            connectivityResult == ConnectivityResult.ethernet;

        if (isOnline) {
          final apiData = await SuratTugasService.getTargetUjiData(jenisKarantina, 'uraian');
          if (mounted) {
            setState(() {
              targetAndTemuanList = apiData;
              if (targetAndTemuanList.isNotEmpty) {
                selectedTarget ??= targetAndTemuanList.first;
                selectedTemuan ??= targetAndTemuanList.first;
                _dbHelper.insertOrUpdateMasterTargetTemuan(jenisKarantina, apiData);
                if (kDebugMode) {
                  print("💾 Data target/temuan dari API disimpan ke DB Lokal untuk jenis: $jenisKarantina");
                }
              } else {
                if (kDebugMode) {
                  print("⚠️ Data target/temuan dari API kosong untuk jenis: $jenisKarantina");
                }
              }
            });
          }
        } else {
          if (kDebugMode) {
            print("📴 Tidak ada koneksi internet dan data lokal tidak tersedia untuk target/temuan jenis: $jenisKarantina.");
          }
          if (mounted) {
            setState(() {
              targetAndTemuanList = [];
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error loading target and temuan list: $e");
      }
      if (mounted) {
        setState(() {
          targetAndTemuanList = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDropdownData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _metodeController.dispose();
    _catatanController.dispose();
    _lokasiController.dispose();
    _uploadedPhotos.clear();
    _originalPickedXFiles.clear();
    _compressedPhotosForServer.clear();
    _photoSources.clear();
    super.dispose();
  }

  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<void> ambilPosisiAwal() async {
    final granted = await requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Izin lokasi diperlukan untuk mengambil posisi")),
      );
      return;
    }

    try {
      final posisi = await _dbHelper.getLocation();
      if (posisi != null) {
        if (!mounted) return;
        setState(() {
          devicePosition = posisi;
          latitude = posisi.latitude;
          longitude = posisi.longitude;
          waktuAmbilPosisi = DateTime.now().toIso8601String();
        });

        if (kDebugMode) {
          print("Lokasi berhasil: lat=$latitude, long=$longitude");
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❗ Gagal mengambil lokasi")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  String _getIndonesianTimezone() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset.inHours;

    if (offset == 7) {
      return 'WIB';
    } else if (offset == 8) {
      return 'WITA';
    } else if (offset == 9) {
      return 'WIT';
    } else {
      if (longitude != null) {
        if (longitude! <= 120) {
          return 'WIB';
        } else if (longitude! <= 135) {
          return 'WITA';
        } else {
          return 'WIT';
        }
      }
      return 'WIB';
    }
  }

  Future<Uint8List?> _compressForDisplay(XFile imageFile, {PhotoSource source = PhotoSource.gallery}) async {
    try {
      if (kDebugMode) {
        print("🔧 Memproses ${imageFile.name} untuk display...");
      }
      final Uint8List imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty) {
        if (kDebugMode) print("❌ Gagal membaca byte dari ${imageFile.name}.");
        return null;
      }
      final Uint8List jpegBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 1280,
        minHeight: 960,
        quality: 88,
        format: CompressFormat.jpeg,
      );
      if (jpegBytes.isEmpty) {
        if (kDebugMode) print("❌ Gagal melakukan kompresi/konversi untuk ${imageFile.name}.");
        return null;
      }
      if (kDebugMode) {
        print("✅ Konversi ke JPEG berhasil. Ukuran: ${(jpegBytes.length / 1024).toStringAsFixed(2)}KB.");
      }
      Uint8List? finalBytes = await _addTimestampToPhoto(
        imageBytes: jpegBytes,
        customText: selectedLokasiName ?? 'Pemeriksaan Karantina',
        photoSource: source,
        context: context,
      );
      finalBytes ??= jpegBytes;
      _photoSources[imageFile.path] = source;
      if (kDebugMode) {
        print("✅ Stempel waktu berhasil ditambahkan. Ukuran final: ${(finalBytes.length / 1024).toStringAsFixed(2)}KB");
      }
      return finalBytes;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error fatal di _compressForDisplay untuk ${imageFile.name}: $e");
      }
      return null;
    }
  }

  Future<Uint8List> _compressForServer(XFile imageFile, double targetKbPerPhoto, {PhotoSource source = PhotoSource.gallery}) async {
    try {
      final targetBytes = targetKbPerPhoto * 1024;
      if (kDebugMode) {
        print("🔧 SERVER COMPRESSION untuk ${imageFile.name} - Target: ${targetKbPerPhoto.toStringAsFixed(2)}KB");
      }
      final Uint8List imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty) {
        if (kDebugMode) print("❌ Gagal membaca byte dari ${imageFile.name} untuk server.");
        return Uint8List(0);
      }
      final Uint8List jpegBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 1280,
        minHeight: 960,
        quality: 90,
        format: CompressFormat.jpeg,
      );
      if (jpegBytes.isEmpty) {
        if (kDebugMode) print("❌ Gagal melakukan konversi awal untuk server pada ${imageFile.name}.");
        return Uint8List(0);
      }
      Uint8List? timestampedBytes = await _addTimestampToPhoto(
        imageBytes: jpegBytes,
        customText: selectedLokasiName ?? 'Pemeriksaan Karantina',
        photoSource: source,
        context: context,
      );
      timestampedBytes ??= jpegBytes;
      Uint8List compressedBytes = timestampedBytes;
      int quality = 85;
      int minWidth = 1024;
      int minHeight = 768;
      int maxIterations = 8;
      int iteration = 0;
      while (compressedBytes.length > targetBytes && iteration < maxIterations) {
        iteration++;
        quality = (quality * 0.85).round().clamp(10, 85);
        if (quality < 50 && minWidth > 640) {
          minWidth = (minWidth * 0.9).round();
          minHeight = (minHeight * 0.9).round();
        }
        try {
          final tempBytes = await FlutterImageCompress.compressWithList(
            compressedBytes,
            minWidth: minWidth,
            minHeight: minHeight,
            quality: quality,
            format: CompressFormat.jpeg,
          );
          if (tempBytes.isEmpty) {
            if (kDebugMode) print("    -> Kompresi menghasilkan byte kosong.");
            break;
          }
          compressedBytes = tempBytes;
        } catch (e) {
          if (kDebugMode) print("    -> Error pada iterasi kompresi: $e.");
          break;
        }
      }
      if (kDebugMode) {
        print("✅ SERVER COMPRESSION - Ukuran final: ${(compressedBytes.length / 1024).toStringAsFixed(2)}KB.");
      }
      return compressedBytes;
    } catch (e) {
      if (kDebugMode) print("❌ Error fatal di _compressForServer: $e");
      return Uint8List(0);
    }
  }

  String _getErrorMessage(dynamic error) {
    String errorMessage = 'Terjadi kesalahan tidak diketahui.';
    if (error is TimeoutException) {
      errorMessage = error.message ?? 'Waktu habis saat memilih/mengambil foto.';
    } else if (error is PlatformException) {
      if (error.code == 'already_active') {
        errorMessage = 'Image picker sedang aktif. Tunggu sebentar dan coba lagi.';
      } else if (error.code == 'camera_access_denied') {
        errorMessage = 'Akses kamera ditolak. Periksa pengaturan aplikasi.';
      } else if (error.code == 'photo_access_denied') {
        errorMessage = 'Akses galeri ditolak. Periksa pengaturan aplikasi.';
      } else {
        errorMessage = error.message ?? 'Platform error: ${error.code}';
      }
    } else if (error.toString().toLowerCase().contains("permission")) {
      errorMessage = 'Izin akses galeri/kamera ditolak.';
    } else {
      var parts = error.toString().split(':');
      errorMessage = parts.isNotEmpty ? parts.last.trim() : error.toString();
      if (errorMessage.length > 100) {
        errorMessage = "${errorMessage.substring(0, 97)}...";
      }
    }
    return errorMessage;
  }

  Future<void> pickImages(BuildContext context, ImageSource source, {bool isMulti = false}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (_isGlobalPickerLocked || _isPickingImage) {
      if (kDebugMode) {
        print("⚠️ Image picker sedang aktif (global: $_isGlobalPickerLocked, local: $_isPickingImage), mengabaikan request baru");
      }
      return;
    }
    int remainingSlots = _maxPhotos - _originalPickedXFiles.length;
    if (remainingSlots <= 0) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Batas maksimal $_maxPhotos foto sudah tercapai.')),
        );
      }
      return;
    }
    PhotoSource photoSource = source == ImageSource.camera ? PhotoSource.camera : PhotoSource.gallery;
    try {
      _isGlobalPickerLocked = true;
      if (mounted) {
        setState(() {
          _isPickingImage = true;
        });
      }
      scaffoldMessenger.clearSnackBars();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 16),
                Text('Mengambil foto...'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      List<XFile> tempXFiles = [];
      await Future.delayed(const Duration(milliseconds: 300));
      if (isMulti && source == ImageSource.gallery) {
        try {
          final List<XFile> selectedImages = await _picker.pickMultiImage().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException("Waktu memilih foto dari galeri habis."));
          if (selectedImages.length > remainingSlots) {
            tempXFiles = selectedImages.sublist(0, remainingSlots);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hanya ${tempXFiles.length} foto pertama yang diambil karena batas maksimal.')));
            }
          } else {
            tempXFiles = selectedImages;
          }
        } catch (e) {
          if (kDebugMode) print("❌ Error multi pick dari galeri: $e");
          rethrow;
        }
      } else {
        try {
          final XFile? singleImage = await _picker
              .pickImage(
            source: source,
            preferredCameraDevice: CameraDevice.rear,
          )
              .timeout(const Duration(seconds: 30), onTimeout: () => throw TimeoutException("Waktu mengambil foto habis."));
          if (singleImage != null) {
            tempXFiles = [singleImage];
          }
        } catch (e) {
          if (kDebugMode) print("❌ Error single pick: $e");
          rethrow;
        }
      }
      if (mounted) scaffoldMessenger.clearSnackBars();
      if (tempXFiles.isEmpty) {
        if (kDebugMode) print("ℹ️ Tidak ada foto yang dipilih");
        _resetPickerState();
        return;
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 16),
                Text('Memproses foto...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }
      await _processSelectedImages(tempXFiles, scaffoldMessenger, photoSource);
    } catch (e) {
      if (kDebugMode) print("❌ Error utama di pickImages: $e");
      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        String errorMessage = _getErrorMessage(e);
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('❌ Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4)));
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 1000));
      _resetPickerState();
    }
  }

  Future<void> _processSelectedImages(List<XFile> tempXFiles, ScaffoldMessengerState scaffoldMessenger, PhotoSource photoSource) async {
    List<Uint8List> newDisplayPhotos = [];
    List<XFile> successfullyProcessedOriginals = [];
    int successCount = 0;
    for (int i = 0; i < tempXFiles.length; i++) {
      if ((_originalPickedXFiles.length + successfullyProcessedOriginals.length) >= _maxPhotos) break;
      final imageXFile = tempXFiles[i];
      if (kDebugMode) print("⏳ Memproses foto untuk DISPLAY: ${imageXFile.name}");
      try {
        final fileExists = await File(imageXFile.path).exists();
        if (!fileExists) {
          if (kDebugMode) print("⚠️ File tidak ditemukan: ${imageXFile.path}");
          continue;
        }
        final displayBytes = await _compressForDisplay(imageXFile, source: photoSource);
        if (displayBytes != null && displayBytes.isNotEmpty) {
          newDisplayPhotos.add(displayBytes);
          successfullyProcessedOriginals.add(imageXFile);
          successCount++;
          if (kDebugMode) print("✅ Foto DISPLAY ${imageXFile.name} berhasil diproses: ${displayBytes.length} bytes");
        } else {
          if (kDebugMode) print("❌ Gagal memproses foto DISPLAY ${imageXFile.name}");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Gagal memproses foto: ${imageXFile.name}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2)));
          }
        }
      } catch (e) {
        if (kDebugMode) print("❌ Error memproses foto DISPLAY ${imageXFile.name}: $e");
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) {
      setState(() {
        _uploadedPhotos.addAll(newDisplayPhotos);
        _originalPickedXFiles.addAll(successfullyProcessedOriginals);
        if (_formSubmitted) {
          _updateFieldError('foto', _originalPickedXFiles.isEmpty);
        }
      });
    }
    if (mounted) {
      scaffoldMessenger.clearSnackBars();
      if (successCount > 0) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('✅ $successCount foto berhasil ditambahkan.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2)));
      } else if (tempXFiles.isNotEmpty) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('❌ Tidak ada foto yang berhasil diproses. Coba lagi dengan foto lain.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3)));
      }
    }
  }

  Future<Uint8List?> _addTimestampToPhoto({
    required Uint8List imageBytes,
    String? customText,
    PhotoSource photoSource = PhotoSource.gallery,
    required BuildContext context,
  }) async {
    try {
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Gagal decode gambar');
      }

      final int imageWidth = originalImage.width;
      final int imageHeight = originalImage.height;

      final int bgWidth = (imageWidth * 0.95).round();

      final int desiredFontSize = (imageWidth * 0.035).round().clamp(16, 48);
      final font = _getBestFitFont(desiredFontSize);

      final now = DateTime.now();
      final timezone = _getIndonesianTimezone();
      final dateFormatter = DateFormat('dd MMM yyyy, HH:mm:ss');
      final timestampText = '🗓️ ${dateFormatter.format(now)} $timezone';
      final locationText = (latitude != null && longitude != null)
          ? '📍 ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
          : '📍 Koordinat tidak tersedia';
      final customTextLine = '🏢 ${customText ?? selectedLokasiName ?? 'Pemeriksaan Karantina'}';
      final sourceText = photoSource == PhotoSource.camera
          ? '📸 Captured by Q-Officer'
          : '📂 Selected from Gallery';

      final List<String> textLines = [customTextLine, timestampText, locationText, sourceText];

      final int padding = (font.lineHeight * 0.6).round();
      final int textSpacing = (font.lineHeight * 0.2).round();
      final int totalTextHeight = (font.lineHeight * textLines.length) + (textSpacing * (textLines.length - 1));
      final int bgHeight = totalTextHeight + (padding * 2);
      final int bgPosX = (imageWidth - bgWidth) ~/ 2;
      final int bgPosY = imageHeight - bgHeight - (imageHeight * 0.02).round();

      img.fillRect(
        originalImage,
        x1: bgPosX,
        y1: bgPosY,
        x2: bgPosX + bgWidth,
        y2: bgPosY + bgHeight,
        color: img.ColorRgba8(0, 0, 0, 150),
        radius: 8,
      );

      img.drawRect(
        originalImage,
        x1: bgPosX,
        y1: bgPosY,
        x2: bgPosX + bgWidth,
        y2: bgPosY + bgHeight,
        color: img.ColorRgba8(255, 255, 255, 80),
        thickness: 2,
        radius: 8,
      );

      int currentY = bgPosY + padding;
      final int textStartX = bgPosX + padding;
      final int availableTextWidth = bgWidth - (padding * 2);

      for (var line in textLines) {
        String displayText = line;
        while (_getTextWidth(displayText, font) > availableTextWidth && displayText.length > 10) {
          displayText = '${displayText.substring(0, displayText.length - 4)}...';
        }

        img.drawString(
          originalImage,
          displayText,
          font: font,
          x: textStartX + 2,
          y: currentY + 2,
          color: img.ColorRgba8(0, 0, 0, 180),
        );

        // Teks utama (putih)
        img.drawString(
          originalImage,
          displayText,
          font: font,
          x: textStartX,
          y: currentY,
          color: img.ColorRgba8(255, 255, 255, 255),
        );

        currentY += font.lineHeight + textSpacing;
      }

      return Uint8List.fromList(img.encodeJpg(originalImage, quality: 92));
    } catch (e) {
      if (kDebugMode) print('❌ Error adding timestamp: $e');
      return imageBytes; // Kembalikan gambar asli jika ada error
    }
  }

  img.BitmapFont _getBestFitFont(int desiredSize) {
    if (desiredSize >= 40) return img.arial48;
    if (desiredSize >= 20) return img.arial24;
    return img.arial14;
  }

  int _getTextWidth(String text, img.BitmapFont font) {
    double width = 0;
    for (var char in text.codeUnits) {
      if (font.characters.containsKey(char)) {
        final ch = font.characters[char]!;
        width += ch.xAdvance;
      }
    }
    return width.round();
  }

  void deleteImage(int index) {
    if (index >= 0 && index < _uploadedPhotos.length && index < _originalPickedXFiles.length) {
      if (!mounted) return;
      setState(() {
        final xFile = _originalPickedXFiles[index];
        _photoSources.remove(xFile.path);
        _uploadedPhotos.removeAt(index);
        _originalPickedXFiles.removeAt(index);
        if (_formSubmitted) {
          _updateFieldError('foto', _originalPickedXFiles.isEmpty);
        }
      });
    }
  }

  void _updateFieldError(String field, bool hasError) {
    if (!mounted) return;
    setState(() {
      _fieldErrors[field] = hasError;
    });
  }

  void _resetForm() {
    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }
    _metodeController.clear();
    _catatanController.clear();
    if (!mounted) return;
    setState(() {
      selectedTarget = targetAndTemuanList.isNotEmpty ? targetAndTemuanList.first : null;
      selectedTemuan = targetAndTemuanList.isNotEmpty ? targetAndTemuanList.first : null;
      selectedLokasiName = lokasiList.isNotEmpty ? lokasiList.first.namaLokasi : null;
      selectedLokasiId = lokasiList.isNotEmpty ? lokasiList.first.idLokasi : null;
      selectedKomoditasName = komoditasList.isNotEmpty ? komoditasList.first.namaKomoditas : null;
      selectedKomoditasId = komoditasList.isNotEmpty ? komoditasList.first.idKomoditas : null;
      if (lokasiList.isNotEmpty) {
        selectedLokasiName = lokasiList.first.namaLokasi;
        selectedLokasiId = lokasiList.first.idLokasi;
        _lokasiController.text = selectedLokasiName ?? "Lokasi tidak ditentukan";
      } else {
        _lokasiController.text = "Lokasi tidak tersedia";
        selectedLokasiName = null;
        selectedLokasiId = null;
      }
      _uploadedPhotos.clear();
      _originalPickedXFiles.clear();
      _compressedPhotosForServer.clear();
      _photoSources.clear();
      _formSubmitted = false;
      idPemeriksaan = uuid.v4();
    });
    ambilPosisiAwal();
  }

  Future<void> _showCustomDialog(BuildContext context, String title, String message, IconData icon, Color iconColor) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 600),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (contextDialog, value, child) {
              return Transform.scale(
                scale: value,
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    width: MediaQuery.of(ctx).size.width * 0.85,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder(
                            duration: const Duration(milliseconds: 1000),
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            curve: Curves.bounceOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Icon(icon, size: 70, color: iconColor),
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF522E2E),
                              decorationThickness: 0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF333333),
                              decorationThickness: 0,
                              decoration: TextDecoration.none,
                            ),
                            overflow: TextOverflow.visible,
                            softWrap: true,
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: 150,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF522E2E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text(
                                "OK",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> showLocationRangeValidationDialog({required BuildContext context, required String title, required String message, required IconData iconData, required Color iconColor}) async {
    return _showCustomDialog(context, title, message, iconData, iconColor);
  }

  void _resetPickerState() {
    if (mounted) {
      setState(() {
        _isPickingImage = false;
      });
    }
    _isGlobalPickerLocked = false;
  }

  void _handleSubmit(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (!mounted) return;
    setState(() {
      _formSubmitted = true;
      _updateFieldError('lokasi', selectedLokasiId == null);
      _updateFieldError('target', selectedTarget == null);
      _updateFieldError('metode', _metodeController.text.isEmpty);
      _updateFieldError('temuan', selectedTemuan == null);
      _updateFieldError('komoditas', selectedKomoditasId == null);
      _updateFieldError('foto', _originalPickedXFiles.isEmpty);
    });
    if (_formKey.currentState == null ||
        !_formKey.currentState!.validate() ||
        selectedLokasiId == null ||
        selectedTarget == null ||
        selectedTemuan == null ||
        selectedKomoditasId == null ||
        _originalPickedXFiles.isEmpty) {
      if (mounted) {
        if (_originalPickedXFiles.isEmpty) _updateFieldError('foto', true);
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text("Harap lengkapi seluruh isian pada form pemeriksaan dan upload minimal 1 foto!")),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });
    _compressedPhotosForServer.clear();
    double overheadBytes = 3000;
    double maxApiPayloadBytes = _maxTotalServerPayloadKb * 1024;
    double availableBytesForBase64 = maxApiPayloadBytes - overheadBytes;
    double maxTotalBinarySizeBytes = availableBytesForBase64 * 0.75;
    double targetKbPerPhoto = _originalPickedXFiles.isNotEmpty ? (maxTotalBinarySizeBytes / _originalPickedXFiles.length) / 1024 : 5.0;
    if (targetKbPerPhoto < 5) targetKbPerPhoto = 5.0;
    if (kDebugMode) {
      print("📸 Kompresi agresif dengan target per foto: ${targetKbPerPhoto.toStringAsFixed(2)}KB");
    }
    for (int i = 0; i < _originalPickedXFiles.length; i++) {
      final xFile = _originalPickedXFiles[i];
      final source = _photoSources[xFile.path] ?? PhotoSource.gallery;
      final serverBytes = await _compressForServer(xFile, targetKbPerPhoto, source: source);
      if (serverBytes.isNotEmpty) {
        _compressedPhotosForServer.add(serverBytes);
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (_originalPickedXFiles.isNotEmpty && _compressedPhotosForServer.isEmpty) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _updateFieldError('foto', true);
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text("Gagal memproses foto untuk pengiriman. Silakan coba lagi.")),
        );
      }
      return;
    }
    if (kDebugMode) {
      if (devicePosition != null) {
        print("📍 Posisi Pengguna (Tracked): Lat=${devicePosition!.latitude}, Long=${devicePosition!.longitude}");
      } else {
        print("⚠️ Posisi Pengguna (Tracked): Belum ada data / Gagal mendapatkan lokasi.");
      }
    }
    Lokasi? selectedLokasiData;
    if (widget.suratTugas.lokasi.isNotEmpty) {
      try {
        selectedLokasiData = widget.suratTugas.lokasi.firstWhere((loc) => loc.idLokasi == selectedLokasiId);
      } catch (e) {
        if (widget.suratTugas.lokasi.isNotEmpty) {
          selectedLokasiData = widget.suratTugas.lokasi.first;
        }
      }
      if (kDebugMode && selectedLokasiData != null) {
        if (kDebugMode) {
          print("🎯 Lokasi Penempatan ST (Fixed): Nama='${selectedLokasiData.namaLokasi}', Lat=${selectedLokasiData.latitude}, Long=${selectedLokasiData.longitude}");
        }
      } else if (selectedLokasiData == null) {
        if (kDebugMode) {
          print("🎯 Lokasi Penempatan ST (Fixed): Tidak dapat menentukan lokasi ST terpilih.");
        }
      }
    } else {
      if (kDebugMode) {
        print("🎯 Lokasi Penempatan ST (Fixed): Tidak ada data lokasi pada surat tugas.");
      }
    }
    if (selectedLokasiData == null || devicePosition == null) {
      if (mounted) {
        await _showCustomDialog(context, "Validasi Lokasi Gagal",
            "Tidak dapat memvalidasi lokasi Anda terhadap lokasi surat tugas. Pastikan GPS aktif dan data lokasi ST tersedia.",
            Icons.location_disabled_rounded, Colors.red.shade700);
        setState(() => _isSubmitting = false);
      }
      return;
    }
    final double stLatitude = selectedLokasiData.latitude;
    final double stLongitude = selectedLokasiData.longitude;
    final double userLatitude = devicePosition!.latitude;
    final double userLongitude = devicePosition!.longitude;
    double distanceInMeters = Geolocator.distanceBetween(
      stLatitude,
      stLongitude,
      userLatitude,
      userLongitude,
    );
    if (kDebugMode) {
      print("📏 Jarak Pengguna ke Lokasi Penempatan ST: ${distanceInMeters.toStringAsFixed(2)} meter");
    }
    if (distanceInMeters > MAX_ALLOWED_DISTANCE_METERS) {
      await showLocationRangeValidationDialog(
        context: context,
        title: "Posisi Tidak Sesuai",
        message: "PERINGATAN: Anda berada di luar jangkauan lokasi penempatan (${distanceInMeters.toStringAsFixed(0)} meter dari ${selectedLokasiData.namaLokasi})",
        iconData: Icons.warning_amber_rounded,
        iconColor: Colors.orange.shade700,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      return;
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userNip = authProvider.userNip ?? widget.userNip;
    if (kDebugMode) {
      print('🔍 DEBUG - userNip yang akan digunakan untuk submit: "$userNip"');
    }
    if (userNip.isEmpty) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        await _showCustomDialog(this.context, "Error Autentikasi", "NIP pengguna tidak ditemukan. Silakan login ulang.",
            Icons.error_outline_rounded, Colors.red.shade700);
      }
      return;
    }
    final hasil = HasilPemeriksaan(
      idPemeriksaan: idPemeriksaan,
      idSuratTugas: widget.idSuratTugas,
      idKomoditas: selectedKomoditasId!,
      namaKomoditas: selectedKomoditasName!,
      idLokasi: selectedLokasiData.idLokasi,
      namaLokasi: selectedLokasiData.namaLokasi,
      lat: latitude?.toString() ?? '0.0',
      long: longitude?.toString() ?? '0.0',
      target: selectedTarget!,
      metode: _metodeController.text,
      temuan: selectedTemuan!,
      catatan: _catatanController.text,
      tanggal: waktuAmbilPosisi ?? DateTime.now().toIso8601String(),
      syncData: 0,
    );
    bool isOnline = false;
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      isOnline = connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi ||
          connectivityResult == ConnectivityResult.ethernet;
    } catch (e) {
      if (kDebugMode) print("Error checking connectivity: $e");
    }
    if (isOnline) {
      if (kDebugMode) {
        print("🚀 Mengirim dengan foto yang sudah dikompresi ke server (${_compressedPhotosForServer.length} foto)");
      }
      final bool success = await SuratTugasService.submitHasilPemeriksaan(hasil, _compressedPhotosForServer, userNip);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      if (success) {
        final syncedHasil = hasil.toMap();
        syncedHasil['syncdata'] = 1;
        await _dbHelper.insert('Hasil_Pemeriksaan', syncedHasil);
        if (_uploadedPhotos.length == _compressedPhotosForServer.length) {
          for (int i = 0; i < _uploadedPhotos.length; i++) {
            await _dbHelper.savePemeriksaanFoto(
                idPemeriksaan: idPemeriksaan,
                fotoDisplayBytes: _uploadedPhotos[i],
                fotoServerBytes: _compressedPhotosForServer[i]);
          }
        } else {
          if (kDebugMode) {
            print("❌ Error di FormPeriksa (if success): Jumlah foto display dan server tidak cocok.");
          }
        }
        await _dbHelper.updateStatusTugas(widget.idSuratTugas, 'dikirim');
        _resetForm();
        if (mounted) {
          await _showCustomDialog(
            context,
            "Berhasil Dikirim",
            "Hasil pemeriksaan telah berhasil dikirim! Anda dapat melanjutkan pemeriksaan kembali atau menyelesaikan tugas.",
            Icons.check_circle_outline_rounded,
            const Color(0xFF522E2E),
          );
          if (context.mounted) Navigator.of(context).pop(true);
        }
      } else {
        final unsyncedHasil = hasil.toMap();
        await _dbHelper.insert('Hasil_Pemeriksaan', unsyncedHasil);
        if (_uploadedPhotos.length == _compressedPhotosForServer.length) {
          for (int i = 0; i < _uploadedPhotos.length; i++) {
            await _dbHelper.savePemeriksaanFoto(
                idPemeriksaan: idPemeriksaan,
                fotoDisplayBytes: _uploadedPhotos[i],
                fotoServerBytes: _compressedPhotosForServer[i]);
          }
        } else {
          if (kDebugMode) {
            print("❌ Error di FormPeriksa (else gagal kirim online): Jumlah foto display dan server tidak cocok.");
          }
        }
        _resetForm();
        if (mounted) {
          await _showCustomDialog(
            context,
            "Gagal Mengirim",
            "Gagal mengirim hasil pemeriksaan ke server. Data disimpan lokal dan akan disinkronkan nanti.",
            Icons.cloud_upload_outlined,
            Colors.blueGrey.shade600,
          );
        }
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      try {
        final unsyncedHasil = hasil.toMap();
        await _dbHelper.insert('Hasil_Pemeriksaan', unsyncedHasil);
        if (_uploadedPhotos.length == _compressedPhotosForServer.length) {
          if (kDebugMode) {
            print("💾 OFFLINE SAVE: Menyiapkan untuk menyimpan ${_uploadedPhotos.length} foto.");
          }
          for (int i = 0; i < _uploadedPhotos.length; i++) {
            final displayBytes = _uploadedPhotos[i];
            final serverBytes = _compressedPhotosForServer[i];
            if (kDebugMode) {
              print(
                  "  -> Foto ${i + 1}: Ukuran Display = ${(displayBytes.length / 1024).toStringAsFixed(2)}KB, Ukuran Server = ${(serverBytes.length / 1024).toStringAsFixed(2)}KB");
            }
            await _dbHelper.savePemeriksaanFoto(
              idPemeriksaan: idPemeriksaan,
              fotoDisplayBytes: displayBytes,
              fotoServerBytes: serverBytes,
            );
          }
        } else {
          if (kDebugMode) {
            print(
                "❌ Error Kritis di FormPeriksa (offline): Jumlah foto display (${_uploadedPhotos.length}) dan server (${_compressedPhotosForServer.length}) tidak cocok. Foto tidak disimpan.");
          }
        }
        await _dbHelper.updateStatusTugas(widget.idSuratTugas, 'tersimpan_offline');
        _resetForm();
        if (mounted) {
          await _showCustomDialog(
            context,
            "Tersimpan Lokal",
            "Tidak ada koneksi internet. Hasil pemeriksaan disimpan lokal dan akan disinkronkan nanti.",
            Icons.save_alt_rounded,
            Colors.blue.shade700,
          );
          if (context.mounted) Navigator.of(context).pop(true);
        }
      } catch (dbError) {
        if (kDebugMode) {
          print("❌ Error saat menyimpan data lokal (offline): $dbError");
        }
        if (mounted) {
          await _showCustomDialog(
            context,
            "Gagal Menyimpan Lokal",
            "Terjadi kesalahan saat menyimpan hasil pemeriksaan secara lokal: ${dbError.toString()}",
            Icons.error_outline_rounded,
            Colors.red.shade700,
          );
          if (context.mounted) Navigator.of(context).pop(true);
        }
      }
    }
  }

  void _showImagePicker(BuildContext context) {
    if (!mounted) return;
    if (_uploadedPhotos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Anda sudah mengupload maksimal $_maxPhotos foto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => Wrap(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pilih Sumber Foto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: "Kamera",
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        if (_uploadedPhotos.length < _maxPhotos) {
                          pickImages(context, ImageSource.camera);
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Batas maksimal foto tercapai.')));
                        }
                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      label: "Galeri",
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        if (_uploadedPhotos.length < _maxPhotos) {
                          int currentRemainingSlots = _maxPhotos - _uploadedPhotos.length;
                          pickImages(context, ImageSource.gallery, isMulti: currentRemainingSlots > 1);
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Batas maksimal foto tercapai.')));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _getInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF522E2E), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF522E2E), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF522E2E), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  String? _customValidator(String? value, String fieldName) {
    bool hasError = _formSubmitted && (value == null || value.isEmpty);
    if (!mounted) return null;
    _updateFieldError(fieldName, hasError);
    return hasError ? "Wajib diisi" : null;
  }

  Widget _buildSearchableDropdown<T>({
    required String title,
    required List<T> items,
    required String Function(T) itemAsString,
    required T? selectedItem,
    required String hint,
    required Function(T?) onChanged,
    required bool isRequired,
    required String fieldName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownSearch<T>(
          asyncItems: (filter) => Future.value(items),
          itemAsString: itemAsString,
          selectedItem: selectedItem,
          onChanged: (value) {
            onChanged(value);
            if (_formSubmitted) {
              if (!mounted) return;
              setState(() {
                _fieldErrors[fieldName] = value == null;
              });
            }
          },
          dropdownButtonProps: const DropdownButtonProps(
            icon: Icon(Icons.arrow_drop_down, color: Color(0xFF522E2E)),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            baseStyle: const TextStyle(fontSize: 14),
            dropdownSearchDecoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF522E2E), width: 1),
                borderRadius: BorderRadius.circular(5),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: _fieldErrors[fieldName] == true ? Colors.red : const Color(0xFF522E2E), width: 1),
                borderRadius: BorderRadius.circular(5),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: _fieldErrors[fieldName] == true ? Colors.red : const Color(0xFF522E2E), width: 1),
                borderRadius: BorderRadius.circular(5),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 1),
                borderRadius: BorderRadius.circular(5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
              errorText: _fieldErrors[fieldName] == true ? "Wajib diisi" : null,
            ),
          ),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Cari $title...',
                prefixIcon: AnimatedBuilder(
                  animation: _searchController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_searchController.value * 2, 0),
                      child: const Icon(Icons.search, color: Color(0xFF522E2E)),
                    );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            menuProps: MenuProps(
                backgroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey[400]!, width: 1),
                  borderRadius: BorderRadius.circular(8),
                )),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canUploadMore = _uploadedPhotos.length < _maxPhotos;
    return Scaffold(
      appBar: AppBar(title: const Text("Form Pemeriksaan")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Lokasi", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lokasiController,
                        readOnly: true,
                        decoration: _getInputDecoration("Lokasi Penempatan").copyWith(
                          filled: true,
                          fillColor: Colors.grey[100],
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                  _isLoadingDropdownData
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Target / Sasaran", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Center(child: CircularProgressIndicator()),
                      SizedBox(height: 16),
                    ],
                  )
                      : (targetAndTemuanList.isEmpty && !_isLoadingDropdownData
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Target / Sasaran", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        "Tidak ada data target/sasaran yang tersedia untuk jenis karantina ini atau sedang offline.",
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                      SizedBox(height: 16),
                    ],
                  )
                      : _buildSearchableDropdown<String>(
                    title: "Target / Sasaran",
                    items: targetAndTemuanList,
                    itemAsString: (target) => target,
                    selectedItem: selectedTarget,
                    hint: "Pilih Target / Sasaran",
                    fieldName: 'target',
                    onChanged: (value) {
                      if (!mounted) return;
                      setState(() {
                        selectedTarget = value;
                        if (_formSubmitted) {
                          _updateFieldError('target', value == null);
                        }
                      });
                    },
                    isRequired: true,
                  )),
                  const Text("Metode", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _metodeController,
                    validator: (value) => _customValidator(value, 'metode'),
                    onChanged: (value) {
                      if (_formSubmitted) {
                        if (!mounted) return;
                        _updateFieldError('metode', value.isEmpty);
                        if (_formKey.currentState != null) _formKey.currentState?.validate();
                      }
                    },
                    decoration: _getInputDecoration("Masukkan metode").copyWith(
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoadingDropdownData
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Temuan", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Center(child: CircularProgressIndicator()),
                      SizedBox(height: 16),
                    ],
                  )
                      : (targetAndTemuanList.isEmpty && !_isLoadingDropdownData
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Temuan", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        "Tidak ada data temuan yang tersedia untuk jenis karantina ini atau sedang offline.",
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                      SizedBox(height: 16),
                    ],
                  )
                      : _buildSearchableDropdown<String>(
                    title: "Temuan",
                    items: targetAndTemuanList,
                    itemAsString: (temuan) => temuan,
                    selectedItem: selectedTemuan,
                    hint: "Pilih Temuan",
                    fieldName: 'temuan',
                    onChanged: (value) {
                      if (!mounted) return;
                      setState(() {
                        selectedTemuan = value;
                        if (_formSubmitted) {
                          _updateFieldError('temuan', value == null);
                        }
                      });
                    },
                    isRequired: true,
                  )),
                  _buildSearchableDropdown<Komoditas>(
                    title: "Komoditas",
                    items: komoditasList,
                    itemAsString: (kom) => kom.namaKomoditas,
                    selectedItem: komoditasList.any((element) => element.idKomoditas == selectedKomoditasId)
                        ? komoditasList.firstWhere((element) => element.idKomoditas == selectedKomoditasId)
                        : (komoditasList.isNotEmpty ? komoditasList.first : null),
                    hint: "Pilih Komoditas",
                    fieldName: 'komoditas',
                    onChanged: (value) {
                      if (value == null && komoditasList.isNotEmpty) {
                        if (!mounted) return;
                        setState(() {
                          selectedKomoditasName = komoditasList.first.namaKomoditas;
                          selectedKomoditasId = komoditasList.first.idKomoditas;
                          if (_formSubmitted) {
                            _updateFieldError('komoditas', false);
                          }
                        });
                        return;
                      }
                      if (value == null && komoditasList.isEmpty) {
                        if (!mounted) return;
                        setState(() {
                          selectedKomoditasName = null;
                          selectedKomoditasId = null;
                          if (_formSubmitted) {
                            _updateFieldError('komoditas', true);
                          }
                        });
                        return;
                      }
                      if (!mounted) return;
                      setState(() {
                        selectedKomoditasName = value!.namaKomoditas;
                        selectedKomoditasId = value.idKomoditas;
                        if (_formSubmitted) {
                          _updateFieldError('komoditas', false);
                        }
                      });
                    },
                    isRequired: true,
                  ),
                  const Text("Catatan", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _catatanController,
                    decoration: _getInputDecoration("Masukkan catatan (opsional)").copyWith(
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Dokumentasi", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("(${_uploadedPhotos.length}/$_maxPhotos foto)",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 180,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: (_isPickingImage || !canUploadMore) ? null : () => _showImagePicker(context),
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(canUploadMore ? "Upload Foto" : "Maks. $_maxPhotos Foto",
                              textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canUploadMore ? const Color(0xFF522E2E) : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                            textStyle: const TextStyle(overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                      if (_formSubmitted && _fieldErrors['foto'] == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Text(
                            "Wajib upload minimal 1 foto",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_uploadedPhotos.isNotEmpty)
                    SizedBox(
                      height: 220,
                      child: PageView.builder(
                        itemCount: _uploadedPhotos.length,
                        controller: PageController(viewportFraction: 0.9),
                        itemBuilder: (context, index) {
                          final bytes = _uploadedPhotos[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (!mounted) return;
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.memory(bytes),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Tutup'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[400]!, width: 1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        bytes,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.white),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        if (!mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text("Hapus Foto"),
                                            content: const Text("Apakah Anda yakin ingin menghapus foto ini?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(),
                                                child: const Text("Batal"),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(ctx).pop();
                                                  deleteImage(index);
                                                },
                                                child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      "${index + 1}/${_uploadedPhotos.length}",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 5),
                  const Text("Format .JPG, .PNG, .JPEG. Maks. $_maxPhotos foto.",
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                  const SizedBox(height: 20),
                  Center(
                    child: SizedBox(
                      width: 250,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _handleSubmit(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF522E2E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                            side: const BorderSide(color: Color(0xFF522E2E), width: 1),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text(
                          "Kirim",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isSubmitting || _isPickingImage)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      _isSubmitting ? "Mengirim data..." : "Memproses foto...",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.normal),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} // <-- Kurung kurawal penutup untuk class FormPeriksaState

Widget _buildImageSourceOption({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.brown.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF522E2E), size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

void showImagePreview(BuildContext context, Uint8List imageBytes) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: InteractiveViewer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(imageBytes),
        ),
      ),
    ),
  );
}