import 'package:flutter/material.dart';
import 'package:q_officer_barantin/main.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:provider/provider.dart';
import 'form_periksa.dart';
import 'periksa_lokasi.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:flutter/foundation.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:q_officer_barantin/services/auth_provider.dart';

class SuratTugasAktifPage extends StatefulWidget {
  final String idSuratTugas;
  final StLengkap suratTugas;
  final VoidCallback onSelesaiTugas;

  const SuratTugasAktifPage({
    super.key,
    required this.idSuratTugas,
    required this.suratTugas,
    required this.onSelesaiTugas,
  });

  @override
  State<SuratTugasAktifPage> createState() => _SuratTugasAktifPageState();
}

class _SuratTugasAktifPageState extends State<SuratTugasAktifPage> {
  bool _isHeaderExpanded = false;
  bool _hasSeenTutorial = false;

  // Tutorial coach mark
  late TutorialCoachMark tutorialCoachMark;
  final GlobalKey headerCardKey = GlobalKey();
  final GlobalKey petugasCardKey = GlobalKey();
  final GlobalKey lokasiCardKey = GlobalKey();
  final GlobalKey buatLaporanKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkTutorialStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTutorial();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!_hasSeenTutorial) {
          _showTutorial();
        }
      });
    });
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasSeenTutorial = prefs.getBool('seen_st_aktif_tutorial') ?? false;
    });
  }

  Future<void> _saveTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_st_aktif_tutorial', true);
  }

  void _initTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: MyApp.karantinaBrown,
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
      },
      onSkip: () {
        _saveTutorialStatus();
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
                      "Detail Surat Tugas 📋",
                      style: TextStyle(
                        color: MyApp.karantinaBrown,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tekan untuk melihat detail lengkap surat tugas aktif Anda. Di dalamnya terdapat informasi penting seperti nomor surat, tanggal, dan perihal.",
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
                        color: MyApp.karantinaBrown,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Di sini Anda dapat melihat semua petugas yang ditugaskan dalam surat tugas aktif ini.",
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
                        color: MyApp.karantinaBrown,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Peta lokasi penugasan Anda. Tekan untuk melihat detail dan navigasi ke lokasi.",
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
        identify: "buatLaporanKey",
        keyTarget: buatLaporanKey,
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
                      "Buat Laporan Pemeriksaan 📝",
                      style: TextStyle(
                        color: MyApp.karantinaBrown,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tekan tombol ini untuk membuat laporan pemeriksaan dari surat tugas aktif Anda. Pastikan Anda sudah melakukan pemeriksaan di lokasi yang ditugaskan.",
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

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Surat Tugas Aktif",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: MyApp.karantinaBrown,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // Tombol tutorial di AppBar
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
                                    print("🔗 LINK DITERIMA: $link");
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
                                        decoration: TextDecoration.underline,
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
                            color: MyApp.karantinaBrown,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Daftar Petugas",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: MyApp.karantinaBrown,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: MyApp.karantinaBrown.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${widget.suratTugas.petugas.length} petugas",
                              style: const TextStyle(
                                fontSize: 12,
                                color: MyApp.karantinaBrown,
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
                                        color: MyApp.karantinaBrown.withOpacity(0.1),
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
                                            color: MyApp.karantinaBrown,
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
                                color: MyApp.karantinaBrown,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Lokasi Penugasan",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: MyApp.karantinaBrown,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MyApp.karantinaBrown.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.open_in_new,
                                  color: MyApp.karantinaBrown,
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
                                      color: MyApp.karantinaBrown,
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

                      // Map dengan border
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MyApp.karantinaBrown.withOpacity(0.8),
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
                                  initialCameraPosition: const CameraPosition(
                                    target: LatLng(-6.200000, 106.816666),
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
                                          idSuratTugas: widget.idSuratTugas,
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
                    key: buatLaporanKey,
                    onPressed: () async {
                      final userNip = authProvider.userNip;

                      if (userNip == null || userNip.isEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ NIP user tidak ditemukan. Silakan login ulang.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                      debugPrint("✅ Navigasi ke FormPeriksa dengan NIP: $userNip");
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FormPeriksa(
                            idSuratTugas: widget.idSuratTugas,
                            suratTugas: widget.suratTugas,
                            onSelesaiTugas: widget.onSelesaiTugas,
                            userNip: userNip,
                          ),
                        ),
                      );
                      if (result == true) {
                        if (mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFFFEC559),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
                    child: const Text(
                      "Buat Laporan Pemeriksaan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: MyApp.karantinaBrown,
                      ),
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