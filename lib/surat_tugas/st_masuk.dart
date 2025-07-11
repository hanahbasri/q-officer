import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:q_officer_barantin/services/history_service.dart';
import 'package:q_officer_barantin/surat_tugas/st_aktif.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../main.dart';
import 'periksa_lokasi.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SuratTugasTertunda extends StatefulWidget {
  final StLengkap suratTugas;
  final Function onTerimaTugas;
  final bool hasActiveTask;
  final bool showTutorialImmediately;

  const SuratTugasTertunda({
    super.key,
    required this.suratTugas,
    required this.onTerimaTugas,
    required this.hasActiveTask,
    this.showTutorialImmediately = false,
  });

  @override
  SuratTugasTertundaState createState() => SuratTugasTertundaState();
}

class SuratTugasTertundaState extends State<SuratTugasTertunda> {
  bool _isHeaderExpanded = false;
  bool _hasSeenTutorial = false;
  late TutorialCoachMark tutorialCoachMark;
  final GlobalKey headerCardKey = GlobalKey();
  final GlobalKey petugasCardKey = GlobalKey();
  final GlobalKey lokasiCardKey = GlobalKey();
  final GlobalKey terimaTugasKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    if (widget.showTutorialImmediately) {
      _hasSeenTutorial = false;
    } else {
      _checkTutorialStatus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTutorial();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!_hasSeenTutorial || widget.showTutorialImmediately) {
          _showTutorial();
        }
      });
    });
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasSeenTutorial = prefs.getBool('seen_st_tertunda_tutorial') ?? false;
    });
  }

  Future<void> _saveTutorialStatus() async {
    if (!widget.showTutorialImmediately) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_st_tertunda_tutorial', true);
    }
  }

  void _initTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: const Color(0xFF522E2E),
      textSkip: "LEWATI",
      textStyleSkip: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: false,
      alignSkip: Alignment.bottomLeft,
      focusAnimationDuration: const Duration(milliseconds: 500),
      pulseAnimationDuration: const Duration(milliseconds: 800),
      onFinish: () {
        debugPrint("Tutorial selesai");
        _saveTutorialStatus();
        if (widget.showTutorialImmediately) {
          Navigator.pop(context);
        }
      },
      onSkip: () {
        _saveTutorialStatus();
        if (widget.showTutorialImmediately) {
          Navigator.pop(context);
        }
        return true;
      },
    );
  }

  void _showTutorial() {
    tutorialCoachMark.show(context: context);
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "headerCardKey",
        keyTarget: headerCardKey,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Detail Surat Tugas 📃",
                      style: TextStyle(
                        color: Color(0xFF522E2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tekan untuk melihat detail lengkap surat tugas. Di dalamnya terdapat informasi penting seperti nomor surat, tanggal, dan perihal.",
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

    targets.add(
      TargetFocus(
        identify: "petugasCardKey",
        keyTarget: petugasCardKey,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Daftar Petugas 👥",
                      style: TextStyle(
                        color: Color(0xFF522E2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Di sini Anda dapat melihat semua petugas yang ditugaskan dalam surat tugas ini.",
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

    targets.add(
      TargetFocus(
        identify: "lokasiCardKey",
        keyTarget: lokasiCardKey,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Lokasi Penugasan 📍",
                      style: TextStyle(
                        color: Color(0xFF522E2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Peta lokasi penugasan. Tekan untuk melihat detail dan navigasi ke lokasi.",
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

    targets.add(
      TargetFocus(
        identify: "terimaTugasKey",
        keyTarget: terimaTugasKey,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Terima Tugas ✅",
                      style: TextStyle(
                        color: Color(0xFF522E2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tekan tombol ini untuk menerima surat tugas dan memulai pemeriksaan. Anda tidak dapat menerima tugas baru jika masih memiliki tugas aktif.",
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
    return targets;
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('💡 SuratTugasTertunda: membangun dengan hasActiveTask = ${widget.hasActiveTask}');
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showTutorialImmediately
              ? "Tutorial - Surat Tugas Masuk"
              : "Surat Tugas Masuk",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF522E2E),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: widget.showTutorialImmediately ? [] : [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showTutorial();
            },
            tooltip: "Tampilkan Tutorial",
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                key: headerCardKey,
                margin: const EdgeInsets.only(bottom: 16),
                color: const Color(0xFF522E2E),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isHeaderExpanded = !_isHeaderExpanded;
                    });
                  },
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.assignment,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Surat Tugas",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  widget.suratTugas.noSt,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(
                              _isHeaderExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),

                      if (_isHeaderExpanded) ...[
                        Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailItem("No Surat Tugas", Text(widget.suratTugas.noSt)),
                              _buildDetailItem("Tanggal Penugasan", Text(widget.suratTugas.tanggal)),
                              _buildDetailItem("Perihal", Text(widget.suratTugas.hal)),
                              _buildDetailItem("Komoditas", Text(widget.suratTugas.komoditas.isNotEmpty
                                  ? widget.suratTugas.komoditas[0].namaKomoditas
                                  : "N/A")),
                              _buildDetailItem("Lokasi", Text(widget.suratTugas.lokasi.isNotEmpty
                                  ? widget.suratTugas.lokasi[0].namaLokasi
                                  : "N/A")),
                              _buildDetailItem("Dasar", Text(widget.suratTugas.dasar)),
                              _buildDetailItem("Penandatangan", Text(widget.suratTugas.namaTtd)),
                              _buildDetailItem("NIP Penandatangan", Text(widget.suratTugas.nipTtd)),
                              _buildDetailItem("Dokumen", InkWell(
                                onTap: () async {
                                  final link = widget.suratTugas.link;
                                  if (kDebugMode) {
                                    print("🧾 LINK DITERIMA: $link");
                                  }

                                  if (link.isEmpty) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Link PDF tidak tersedia')),
                                      );
                                    }
                                    return;
                                  }

                                  final url = link;
                                  if (kDebugMode) {
                                    print("🌐 URL: $url");
                                  }

                                  try {
                                    final success = await launchUrlString(url);
                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Gagal membuka link PDF.')),
                                      );
                                    }
                                  } catch (e) {
                                    if (kDebugMode) {
                                      print('❌ ERROR saat buka URL: $e');
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Terjadi kesalahan saat membuka link')),
                                      );
                                    }
                                  }
                                },
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Unduh PDF",
                                      style: TextStyle(
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Card(
                key: petugasCardKey,
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt,
                            color: Color(0xFF522E2E),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Daftar Petugas",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF522E2E),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF522E2E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${widget.suratTugas.petugas.length} petugas",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF522E2E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),

                      SizedBox(
                        height: widget.suratTugas.petugas.length > 2
                            ? 200
                            : null,
                        child: Scrollbar(
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            itemCount: widget.suratTugas.petugas.length,
                            itemBuilder: (context, index) {
                              final petugas = widget.suratTugas.petugas[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Color(0xFFEEEEEE)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF522E2E).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          petugas.namaPetugas.isNotEmpty
                                              ? petugas.namaPetugas[0].toUpperCase()
                                              : "?",
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF522E2E),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            petugas.namaPetugas,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            petugas.nipPetugas,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Kartu untuk Lokasi
              Card(
                key: lokasiCardKey,
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.map,
                                color: Color(0xFF522E2E),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Lokasi Penugasan",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF522E2E),
                                ),
                              ),
                            ],
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF522E2E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.open_in_new,
                                  color: Color(0xFF522E2E),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PeriksaLokasi(
                                          idSuratTugas: widget.suratTugas.idSuratTugas,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Lihat Detail',
                                    style: TextStyle(
                                      color: Color(0xFF522E2E),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 12),

                      // Peta dengan border
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF522E2E).withOpacity(0.8),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              SizedBox(
                                height: 180,
                                width: double.infinity,
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: widget.suratTugas.lokasi.isNotEmpty
                                        ? LatLng(widget.suratTugas.lokasi[0].latitude, widget.suratTugas.lokasi[0].longitude)
                                        : const LatLng(-6.200000, 106.816666),
                                    zoom: 14,
                                  ),
                                  zoomControlsEnabled: false,
                                  scrollGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                  liteModeEnabled: true,
                                  onMapCreated: (GoogleMapController controller) {},
                                ),
                              ),
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => PeriksaLokasi(
                                          idSuratTugas: widget.suratTugas.idSuratTugas,
                                        )),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: SizedBox(
                  width: 250,
                  child: ElevatedButton(
                    key: terimaTugasKey,
                    onPressed: widget.showTutorialImmediately
                        ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ini adalah mode tutorial - tombol tidak aktif'),
                          backgroundColor: Color(0xFF522E2E),
                        ),
                      );
                    }
                    // dari sini
                        : widget.hasActiveTask
                        ? () {
                      if (kDebugMode) print('🚫 Menampilkan dialog tidak tersedia karena hasActiveTask: ${widget.hasActiveTask}');
                      _showUnavailable(context);
                    }
                        : () async {
                      if (kDebugMode) print('✅ Memanggil onTerimaTugas...');

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
                                  const Text("Memproses penerimaan...", style: TextStyle(fontSize: 16)),
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
                          status: "terima",
                          keterangan: "Petugas telah menerima surat tugas.",
                        );
                      } catch (e) {
                        if (kDebugMode) {
                          print('Error saat mengirim status "terima" ke API: $e');
                        }
                      }

                      if (mounted) Navigator.pop(context);

                      if (apiSuccess) {
                        await widget.onTerimaTugas();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SuratTugasAktifPage(
                                idSuratTugas: widget.suratTugas.idSuratTugas,
                                suratTugas: widget.suratTugas.copyWith(status: 'aktif'),
                                onSelesaiTugas: () {},
                              ),
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gagal mengirim status penerimaan tugas ke server. Silakan coba lagi nanti.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF522E2E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Terima Tugas",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(":", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: value),
        ],
      ),
    );
  }
}

class _BounceCancelDialog extends StatefulWidget {
  const _BounceCancelDialog();

  @override
  State<_BounceCancelDialog> createState() => _BounceCancelDialogState();
}

class _BounceCancelDialogState extends State<_BounceCancelDialog>
    with TickerProviderStateMixin {
  late AnimationController _initialBounceController;
  late Animation<double> _initialBounceAnimation;

  late AnimationController _continuousBounceController;
  late Animation<double> _continuousBounceAnimation;

  @override
  void initState() {
    super.initState();

    _initialBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initialBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 100,
      ),
    ]).animate(_initialBounceController);

    _continuousBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _continuousBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_continuousBounceController);

    _initialBounceController.forward();

    _initialBounceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _continuousBounceController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _initialBounceController.dispose();
    _continuousBounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_initialBounceAnimation, _continuousBounceAnimation]),
            builder: (context, child) {
              double scale = _initialBounceController.isCompleted
                  ? _continuousBounceAnimation.value
                  : _initialBounceAnimation.value;

              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: const Icon(
                Icons.cancel_outlined,
                size: 48,
                color: Color(0xFF522E2E)
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Gagal Terima Tugas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF522E2E)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mohon maaf, Anda tidak dapat menerima surat tugas sebelum menyelesaikan surat tugas aktif.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF522E2E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

void _showUnavailable(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const _BounceCancelDialog(),
  );
}
