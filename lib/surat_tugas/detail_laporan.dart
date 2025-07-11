import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:q_officer_barantin/main.dart';

import 'st_selesai.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../databases/db_helper.dart';
import 'form_periksa.dart';
import 'package:uuid/uuid.dart';

import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:q_officer_barantin/widgets/card_hasil_periksa.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../dialog/selesai_tugas_dialog.dart';
import '../dialog/unsynced_dialog.dart';
import '../services/history_service.dart';

class DetailLaporan extends StatefulWidget {
  final StLengkap suratTugas;
  final String? idSuratTugas;
  final String? customTitle;
  final VoidCallback onSelesaiTugas;
  final bool isViewOnly;
  final bool showDetailHasil;
  final bool showTutorialImmediately;

  final GlobalKey? buatLaporanButtonKeyForTutorial;
  final GlobalKey? selesaiTugasButtonKeyForTutorial;

  const DetailLaporan({
    super.key,
    this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
    this.isViewOnly = false,
    this.showDetailHasil = false,
    this.customTitle,
    this.showTutorialImmediately = false,
    this.buatLaporanButtonKeyForTutorial,
    this.selesaiTugasButtonKeyForTutorial,
  });

  @override
  DetailLaporanState createState() => DetailLaporanState();
}


class DetailLaporanState extends State<DetailLaporan> with SingleTickerProviderStateMixin {
  late StreamSubscription<ConnectivityResult> _subscription;
  bool _isOffline = false;
  bool _showConnectionMessage = false;
  List<Map<String, dynamic>> _hasilList = [];
  var uuid = Uuid();
  bool _hasSeenTutorial = false;
  late TutorialCoachMark tutorialCoachMark;
  final GlobalKey suratTugasKey = GlobalKey();
  final GlobalKey cardHasilPeriksaKey = GlobalKey();
  final GlobalKey tombolSinkronKey = GlobalKey();
  late GlobalKey buatLaporanButtonKey;
  late GlobalKey selesaiTugasButtonKey;

  @override
  void initState() {
    super.initState();
    buatLaporanButtonKey = widget.buatLaporanButtonKeyForTutorial ?? GlobalKey();
    selesaiTugasButtonKey = widget.selesaiTugasButtonKeyForTutorial ?? GlobalKey();
    _monitorConnection();
    _initializePageAndTutorial();
  }

  Future<void> _initializePageAndTutorial() async {
    if (widget.showTutorialImmediately) {
      if (mounted) {
        _hasSeenTutorial = false;
      }
    } else {
      await _checkTutorialStatus();
    }
    await _loadHasilPemeriksaan();

    if (mounted) {
      _initTutorial();
      if (!_hasSeenTutorial || widget.showTutorialImmediately) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showTutorial();
          }
        });
      }
    }
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String tutorialKey;
    if (widget.customTitle == "Surat Tugas Selesai") {
      tutorialKey = 'seen_detail_laporan_selesai_tutorial';
    } else
    if (widget.isViewOnly) {
      tutorialKey = 'seen_detail_laporan_riwayat_tutorial';
    } else { // Untuk ST Aktif
      tutorialKey = 'seen_detail_laporan_aktif_tutorial_v2';
    }
    if (mounted) {
      setState(() {
        _hasSeenTutorial = prefs.getBool(tutorialKey) ?? false;
      });
    }
  }

  Future<void> _saveTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String tutorialKey;
    if (widget.customTitle == "Surat Tugas Selesai") {
      tutorialKey = 'seen_detail_laporan_selesai_tutorial';
    } else if (widget.isViewOnly) {
      tutorialKey = 'seen_detail_laporan_riwayat_tutorial';
    } else {
      tutorialKey = 'seen_detail_laporan_aktif_tutorial_v2';
    }
    if (!widget.showTutorialImmediately || (widget.showTutorialImmediately && ModalRoute.of(context)?.settings.name != '/home')) {
      await prefs.setBool(tutorialKey, true);
    }
  }

  void _initTutorial() {
    List<TargetFocus> currentTargets = _createTargets(hasHasilPeriksa: _hasilList.isNotEmpty);
    tutorialCoachMark = TutorialCoachMark(
      targets: currentTargets,
      colorShadow: const Color(0xFF522E2E),
      textSkip: "LEWATI",
      textStyleSkip: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        debugPrint("Tutorial selesai dari _initTutorial");
        _saveTutorialStatus();
        if (widget.showTutorialImmediately && mounted) {
          Navigator.pop(context);
        }
      },
      onSkip: () {
        _saveTutorialStatus();
        if (widget.showTutorialImmediately && mounted) {
          Navigator.pop(context);
        }
        return true;
      },
      alignSkip: Alignment.bottomRight,
      hideSkip: false,
      focusAnimationDuration: const Duration(milliseconds: 500),
      pulseAnimationDuration: const Duration(milliseconds: 800),
    );
  }

  void _showTutorial() {
    _initTutorial();
    if (tutorialCoachMark.targets.isEmpty) {
      debugPrint("[DetailLaporan Tutorial] No targets to display. Saving tutorial status.");
      _saveTutorialStatus();
      if (widget.showTutorialImmediately && mounted) {
        Navigator.pop(context);
      }
      return;
    }
    if (mounted) {
      tutorialCoachMark.show(context: context);
    }
  }

  List<TargetFocus> _createTargets({bool hasHasilPeriksa = true}) {
    List<TargetFocus> targets = [];
    bool isSelesaiTutorial = widget.customTitle == "Surat Tugas Selesai";
    bool isActiveTaskTutorial = widget.showTutorialImmediately && !isSelesaiTutorial && !widget.isViewOnly;
    if (suratTugasKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "suratTugasKey",
          keyTarget: suratTugasKey,
          alignSkip: Alignment.bottomRight,
          paddingFocus: 20.0,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Detail Surat Tugas 📃",
                        style: TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Tekan untuk melihat detail lengkap surat tugas. Di dalamnya terdapat informasi yang ada di dalam surat tugas.",
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
    if (hasHasilPeriksa && (widget.showDetailHasil || isActiveTaskTutorial) && cardHasilPeriksaKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "cardHasilPeriksaKey",
          keyTarget: cardHasilPeriksaKey,
          alignSkip: Alignment.bottomRight,
          paddingFocus: 10.0,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isSelesaiTutorial ? "Rincian Hasil Pemeriksaan 📄" : "Hasil Pemeriksaan 📄",
                        style: const TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isSelesaiTutorial
                            ? "Ini adalah hasil pemeriksaan yang telah dibuat untuk Surat Tugas yang telah selesai. Anda dapat melihat detail foto, komoditas, dan temuan di sini."
                            : "Ini adalah card hasil pemeriksaan. Tekan untuk melihat detail lebih lanjut. Hasil Pemeriksaan Detail hanya bisa dilihat jika status surat tugas sudah diselesaikan.",
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
    if (hasHasilPeriksa && !widget.isViewOnly && !isSelesaiTutorial && tombolSinkronKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "tombolSinkronKey",
          keyTarget: tombolSinkronKey,
          alignSkip: Alignment.bottomRight,
          paddingFocus: 5.0,
          shape: ShapeLightFocus.RRect,
          radius: 5,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sinkronisasi Data 🔄",
                        style: TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Tombol ini menunjukkan status sinkronisasi laporan. Jika 'Sinkron Sekarang', tekan untuk mengirim data ke server. Jika 'Telah Sinkron', data sudah aman di server.",
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
    if (!widget.isViewOnly && !isSelesaiTutorial && buatLaporanButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "buatLaporanButtonKey",
          keyTarget: buatLaporanButtonKey,
          alignSkip: Alignment.bottomRight,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Tambah Laporan Pemeriksaan 📝",
                        style: TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Tekan tombol ini untuk menambahkan laporan pemeriksaan baru ke surat tugas aktif ini.",
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
    if (!widget.isViewOnly && !isSelesaiTutorial && selesaiTugasButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "selesaiTugasButtonKey",
          keyTarget: selesaiTugasButtonKey,
          alignSkip: Alignment.bottomRight,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Selesaikan Tugas ✅",
                        style: TextStyle(
                          color: Color(0xFF522E2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Jika semua laporan pemeriksaan telah dibuat dan disinkronkan, tekan tombol ini untuk menandai surat tugas sebagai selesai.",
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
    debugPrint("[DetailLaporan Tutorial] Created ${targets.length} targets. HasHasilPeriksa: $hasHasilPeriksa, isViewOnly: ${widget.isViewOnly}, isSelesaiTutorial: $isSelesaiTutorial, buatLaporanKey: ${buatLaporanButtonKey.currentContext != null}, selesaiTugasKey: ${selesaiTugasButtonKey.currentContext != null}");
    return targets;
  }


  Future<void> _monitorConnection() async {
    _subscription = Connectivity().onConnectivityChanged.listen((
        ConnectivityResult result) async {
      bool nowOffline = result == ConnectivityResult.none;
      if (_isOffline && !nowOffline) {
        if (mounted) {
          setState(() {
            _isOffline = false;
            _showConnectionMessage = true;
          });
        }
        final ping = await getPingLatency();
        if (ping < 1000) {
          final db = DatabaseHelper();
          if (mounted) {
            final authProvider = Provider.of<AuthProvider>(
                context, listen: false);
            final userNip = authProvider.userNip;
            if (userNip != null) {
              await db.syncUnsentData(userNip);
              if (mounted) {
                await _loadHasilPemeriksaan();
              }
            }
          }
        }
        _hideNotificationAfterDelay();
      } else if (!_isOffline && nowOffline) {
        if (mounted) {
          setState(() {
            _isOffline = true;
            _showConnectionMessage = true;
          });
        }
        _hideNotificationAfterDelay();
      }
    });
  }

  Future<void> _loadHasilPemeriksaan() async {
    if (widget.idSuratTugas == null) return;
    final db = DatabaseHelper();
    final periksaListAsModel = await db.getHasilPemeriksaanById(widget.idSuratTugas!);
    final periksaList = periksaListAsModel.map((e) => e.toMap()).toList();
    if (mounted) {
      setState(() {
        _hasilList =
            periksaList.where((e) => e['id_surat_tugas'] == widget.idSuratTugas)
                .toList();
      });
      _initTutorial();
    }
  }

  Future<int> getPingLatency() async {
    try {
      final stopwatch = Stopwatch()
        ..start();
      final _ = await InternetAddress.lookup('google.com');
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return 9999;
    }
  }

  void _hideNotificationAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showConnectionMessage = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    if (tutorialCoachMark.isShowing) {
      tutorialCoachMark.finish();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suratTugasData = widget.suratTugas;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool canNavigateOnCardTap = widget.customTitle == "Surat Tugas Selesai";
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showTutorialImmediately && widget.customTitle == "Surat Tugas Selesai"
              ? "Tutorial - Surat Tugas Selesai"
              : widget.showTutorialImmediately && !widget.isViewOnly
              ? "Tutorial - Detail Laporan Aktif"
              : widget.customTitle ?? "Riwayat Pemeriksaan",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: widget
            .showTutorialImmediately
            ? []
            : [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String tutorialKey;
              if (widget.customTitle == "Surat Tugas Selesai") {
                tutorialKey = 'seen_detail_laporan_selesai_tutorial';
              } else if (widget.isViewOnly) {
                tutorialKey = 'seen_detail_laporan_riwayat_tutorial';
              } else {
                tutorialKey = 'seen_detail_laporan_aktif_tutorial_v2';
              }
              await prefs.remove(tutorialKey);
              if (mounted) {
                setState(() => _hasSeenTutorial = false);
                _showTutorial();
              }
            },
            tooltip: "Tampilkan Tutorial",
          ),
        ],
      ),
      body: widget.idSuratTugas == null
          ? const Center(child: Text('ID Surat Tugas tidak tersedia'))
          : Column(
        children: [
          if (_showConnectionMessage && !widget.showTutorialImmediately)
            buildConnectionStatus(isConnected: !_isOffline),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18.0, vertical: 6.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          key: suratTugasKey,
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          // Increased vertical padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: const Color(0xFF522E2E).withOpacity(0.2),
                                width: 1),
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: const Color(0xFF522E2E).withOpacity(0.2),
                                width: 1),
                          ),
                          backgroundColor: Colors.white,
                          collapsedBackgroundColor: const Color(0xFFF8F8F8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF522E2E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.assignment_outlined,
                              color: Color(0xFF522E2E),
                            ),
                          ),
                          title: Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: Text(
                              suratTugasData.noSt,
                              style: const TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF522E2E)),
                            ),
                          ),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 1.0),
                            child: Text(
                              "Tekan untuk melihat detail",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ),
                          children: [
                            Card(
                              margin: const EdgeInsets.all(12),
                              color: const Color(0xFFFEC559),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow(
                                        "Dasar", suratTugasData.dasar),
                                    _buildInfoRow("Nama",
                                        suratTugasData.petugas.first
                                            .namaPetugas),
                                    _buildInfoRow("NIP",
                                        suratTugasData.petugas.first
                                            .nipPetugas),
                                    _buildInfoRow("Gol / Pangkat",
                                        "${suratTugasData.petugas.first
                                            .gol} / ${suratTugasData.petugas
                                            .first.pangkat}"),
                                    _buildInfoRow("Komoditas",
                                        suratTugasData.komoditas.first
                                            .namaKomoditas),
                                    _buildInfoRow("Lokasi",
                                        suratTugasData.lokasi.first.namaLokasi),
                                    _buildInfoRow("Tgl Penugasan",
                                        suratTugasData.tanggal),
                                    _buildInfoRow("Penandatangan",
                                        suratTugasData.namaTtd),
                                    _buildInfoRow(
                                        "Perihal", suratTugasData.hal),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),

                    Column(
                      children: List.generate(_hasilList.length, (i) {
                        final item = _hasilList[i];
                        return HasilPeriksaCard(
                          key: (i == 0 && (widget.showDetailHasil || (widget.showTutorialImmediately && !widget.isViewOnly && ! (widget.customTitle == "Surat Tugas Selesai")) )) ? cardHasilPeriksaKey : null,
                          item: item,
                          canTap: canNavigateOnCardTap && widget.showDetailHasil, //
                          showSync: !widget.isViewOnly,
                          enableAutoSlide: true,
                          syncButtonKey: (i == 0 && !widget.isViewOnly && !(widget.customTitle == "Surat Tugas Selesai")) ? tombolSinkronKey : null,
                          onTap: (canNavigateOnCardTap && widget.showDetailHasil) //
                              ? () async {
                            if (widget.showTutorialImmediately) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ini adalah mode tutorial - aksi tidak aktif'),
                                  backgroundColor: Color(0xFF522E2E),
                                ),
                              );
                              return;
                            }
                            final fotoList = await DatabaseHelper().getImageBase64List(item['id_pemeriksaan']);
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SuratTugasSelesai(
                                    hasilPemeriksaan: {
                                      ...item,
                                      'fotoBase64List': fotoList,
                                    },
                                  ),
                                ),
                              );
                            }
                          } : null,
                          onSyncPressed: widget.isViewOnly || authProvider.userNip == null || widget.showTutorialImmediately
                              ? null
                              : () async {
                            final db = DatabaseHelper();
                            await db.syncSingleData(item['id_pemeriksaan'], authProvider.userNip!);
                            await _loadHasilPemeriksaan();
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    if (!widget.isViewOnly)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Center(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              key: buatLaporanButtonKey,
                              width: 250, // Lebar penuh
                              child: ElevatedButton.icon(
                                label: const Text(
                                  "Buat Laporan Pemeriksaan",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: MyApp.karantinaBrown,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEC559),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  if (widget.showTutorialImmediately) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Ini adalah mode tutorial - tombol tidak aktif'),
                                        backgroundColor: Color(0xFF522E2E),
                                      ),
                                    );
                                    return;
                                  }
                                  final userNip = authProvider.userNip;
                                  if (userNip == null || userNip.isEmpty) {
                                    if(context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('NIP pengguna tidak ditemukan. Silakan login ulang.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  if (widget.idSuratTugas == null) return;
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FormPeriksa(
                                        idSuratTugas: widget.idSuratTugas!,
                                        suratTugas: widget.suratTugas,
                                        onSelesaiTugas: widget.onSelesaiTugas,
                                        userNip: userNip,
                                      ),
                                    ),
                                  );
                                  if (result == true && mounted) {
                                    await _loadHasilPemeriksaan();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 12),

                            SizedBox(
                              key: selesaiTugasButtonKey,
                              width: 250,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (widget.showTutorialImmediately) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Ini adalah mode tutorial - tombol tidak aktif'),
                                        backgroundColor: Color(0xFF522E2E),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  final bool hasUnsyncedData = _hasilList.any((item) => item['syncdata'] == 0);

                                  if (hasUnsyncedData) {
                                    showAnimatedUnsyncedDataDialog(context: context);
                                  } else {
                                    showAnimatedSelesaikanTugasDialog(
                                      context: context,
                                      onConfirmed: () async {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (BuildContext dialogContext) {
                                            return Dialog(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              child: Padding(
                                                padding: const EdgeInsets.all(20.0),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CircularProgressIndicator(
                                                      valueColor: AlwaysStoppedAnimation<Color>(MyApp.karantinaBrown),
                                                    ),
                                                    const SizedBox(width: 20),
                                                    const Text("Menyelesaikan tugas...", style: TextStyle(fontSize: 16)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                        bool apiSuccess = false;
                                        try {
                                          apiSuccess = await HistoryApiService.sendTaskStatusUpdate(
                                            context: context,
                                            idSuratTugas: widget.suratTugas.idSuratTugas,
                                            status: "selesai",
                                            keterangan: "Petugas telah menyelesaikan surat tugas.",
                                          );
                                        } catch (e) {
                                          if (kDebugMode) print('Error saat mengirim status "selesai" ke API: $e');
                                        }

                                        if (Navigator.canPop(context)) Navigator.pop(context);

                                        if (apiSuccess) {
                                          widget.onSelesaiTugas();
                                          if (Navigator.canPop(context)) Navigator.pop(context, true);
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Gagal mengirim status penyelesaian tugas ke server. Silakan coba lagi nanti.'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                          widget.onSelesaiTugas();
                                          if (Navigator.canPop(context)) Navigator.pop(context, true);
                                        }
                                      },
                                    );
                                  }
                                },
                                child: const Text(
                                  "Selesai Tugas",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: MyApp.karantinaBrown,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Text(
            ":",
            style: TextStyle(
              color: MyApp.karantinaBrown,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(
                color: MyApp.karantinaBrown,
                fontSize: 13,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedConfirmationDialog extends StatefulWidget {
  final VoidCallback onConfirmed;

  const _AnimatedConfirmationDialog({required this.onConfirmed});

  @override
  State<_AnimatedConfirmationDialog> createState() => _AnimatedConfirmationDialogState();
}

class _AnimatedConfirmationDialogState extends State<_AnimatedConfirmationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconAnimation;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _iconAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_iconController);

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeOut,
    ));

    _iconController.forward();

    _iconController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _iconController.reset();
            _iconController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MyApp.karantinaBrown.withOpacity(0.1),
                ),
                child: AnimatedBuilder(
                  animation: _iconAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _iconAnimation.value,
                      child: child,
                    );
                  },
                  child: const Icon(
                      Icons.question_mark_rounded,
                      size: 52,
                      color: MyApp.karantinaBrown
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Konfirmasi Selesai Tugas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: MyApp.karantinaBrown,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Apakah Anda yakin ingin menyelesaikan Surat Tugas ini?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MyApp.karantinaBrown,
                          side: const BorderSide(color: MyApp.karantinaBrown),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Tidak',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyApp.karantinaBrown,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onConfirmed();
                        },
                        child: const Text(
                          'Ya',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

Widget buildConnectionStatus({required bool isConnected}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    color: isConnected ? Colors.green : Colors.red,
    child: Row(
      children: [
        Icon(
          isConnected ? Icons.wifi : Icons.wifi_off,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isConnected
                ? "Koneksi internet terhubung. Data akan disinkronkan."
                : "Koneksi internet terputus. Data akan disimpan sementara.",
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

void showConfirmation({
  required BuildContext context,
  required VoidCallback onConfirmed,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        elevation: 4,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: _AnimatedConfirmationDialog(onConfirmed: onConfirmed),
      );
    },
  );
}

Widget buildLaporanFooter({
  required BuildContext context,
  required String? idSuratTugas,
  required StLengkap suratTugas,
  required VoidCallback onSelesaiTugas,
  required GlobalKey buatLaporanKey,
  required GlobalKey selesaiTugasKey,
  required List<Map<String, dynamic>> hasilList,
  bool isInTutorialMode = false,
}) {
  return Consumer<AuthProvider>(
    builder: (context, authProvider, child) {

      return Center(
        child: Column(
          children: [
            SizedBox(
              width: 270,child: ElevatedButton(
              key: buatLaporanKey,
              onPressed: () async {
                if (isInTutorialMode) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Ini adalah mode tutorial - tombol tidak aktif'),
                      backgroundColor: Color(0xFF522E2E),
                    ),
                  );
                  return;
                }
                if (!context.mounted) return;
                final bool hasUnsyncedData = hasilList.any((item) => item['syncdata'] == 0);

                if (hasUnsyncedData) {
                  showAnimatedUnsyncedDataDialog(context: context);
                } else {
                  showAnimatedSelesaikanTugasDialog(
                    context: context,
                    onConfirmed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext dialogContext) {
                          return Dialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(MyApp.karantinaBrown),
                                  ),
                                  const SizedBox(width: 20),
                                  const Text("Menyelesaikan tugas...", style: TextStyle(fontSize: 16)),
                                ],
                              ),
                            ),
                          );
                        },
                      );

                      bool apiSuccess = false;
                      try {
                        apiSuccess = await HistoryApiService.sendTaskStatusUpdate(
                          context: context,
                          idSuratTugas: suratTugas.idSuratTugas,
                          status: "selesai", // Status untuk API
                          keterangan: "Petugas telah menyelesaikan surat tugas.",
                        );
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error saat mengirim status "selesai" ke API: $e');
                        }
                      }

                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      if (apiSuccess) {
                        onSelesaiTugas();
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context, true);
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gagal mengirim status penyelesaian tugas ke server. Silakan coba lagi nanti.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          onSelesaiTugas();
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context, true);
                          }
                        }
                      }
                    },
                  );
                }
              },
              child: const Text(
                "Selesai Tugas",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    },
  );
}
