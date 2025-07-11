import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_officer_barantin/main.dart';
import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:q_officer_barantin/models/lokasi.dart';
import 'package:q_officer_barantin/models/petugas.dart';
import 'st_aktif.dart';
import 'st_masuk.dart';
import '../databases/db_helper.dart';
import '../services/auth_provider.dart';
import 'detail_laporan.dart';
import 'package:q_officer_barantin/models/st_lengkap.dart';
import 'package:q_officer_barantin/models/hasil_pemeriksaan.dart';

class SuratTugasPage extends StatefulWidget {
  const SuratTugasPage({super.key});

  @override
  SuratTugasPageState createState() => SuratTugasPageState();
}

class SuratTugasPageState extends State<SuratTugasPage> with SingleTickerProviderStateMixin {
  bool hasActiveTask = false;
  StLengkap? suratTugasAktif;
  List<StLengkap> suratTugasTertunda = [];
  List<StLengkap> suratTugasSelesai = [];
  bool _isLoading = true;
  bool _isSyncingApi = false;
  bool _isFirstLoad = true;
  String _selectedSelesaiFilter = "7 Hari Terakhir";
  List<StLengkap> _filteredSuratTugasSelesai = [];
  DateTime? _customDateFilter;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isFirstLoad) {
        _loadSuratTugas(syncWithApi: true);
        _isFirstLoad = false;
      } else {
        _loadSuratTugas(syncWithApi: false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSuratTugas({bool syncWithApi = false}) async {
    if (!mounted) return;
    if (!syncWithApi && _isLoading && !_isSyncingApi) {
      if (kDebugMode) print('🔄 _loadSuratTugas: Load biasa sudah berjalan, melewati.');
      return;
    }
    if (syncWithApi && _isSyncingApi) {
      if (kDebugMode) print('🔄 _loadSuratTugas: Sinkronisasi API sudah berjalan, melewati.');
      return;
    }

    if (!mounted) return;
    setState(() {
      if (syncWithApi) _isSyncingApi = true;
      _isLoading = true;
      suratTugasAktif = null;
      hasActiveTask = false;
      suratTugasTertunda.clear();
      suratTugasSelesai.clear();
      _filteredSuratTugasSelesai.clear();
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userNip = authProvider.userNip;

      if (userNip == null) {
        throw Exception('NIP Pengguna tidak ditemukan');
      }

      final db = DatabaseHelper();

      if (syncWithApi) {
        if (kDebugMode) print('🔄 _loadSuratTugas: Menyinkronkan data dari API untuk NIP: $userNip');
        try {
          await db.syncSuratTugasFromApi(userNip);
          if (kDebugMode) print('✅ _loadSuratTugas: Sinkronisasi API selesai.');
        } catch (e) {
          if (kDebugMode) print('⚠️ _loadSuratTugas: Gagal sinkronisasi API, lanjut dengan data lokal. Error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal sinkronisasi dengan server: ${e.toString().substring(0, (e.toString().length > 50 ? 50 : e.toString().length))}... Cek koneksi Anda.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      final data = await db.getData('Surat_Tugas');
      if (kDebugMode) {
        print('📋 Total surat tugas di database (setelah potensi sync): ${data.length}');
      }

      StLengkap? tempPrioritasUtama;
      StLengkap? tempPrioritasKedua;
      List<StLengkap> tempSuratTugasTertunda = [];
      List<StLengkap> tempSuratTugasSelesai = [];
      List<StLengkap> allTasksFromDb = [];

      final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      for (var itemMap in data) {
        try {
          final petugasData = (await db.getPetugasById(itemMap['id_surat_tugas'])).map((p) => Petugas.fromDbMap(p)).toList();
          final lokasiData = (await db.getLokasiById(itemMap['id_surat_tugas'])).map((l) => Lokasi.fromDbMap(l)).toList();
          final komoditasData = (await db.getKomoditasById(itemMap['id_surat_tugas'])).map((k) => Komoditas.fromDbMap(k)).toList();
          allTasksFromDb.add(StLengkap.fromDbMap(itemMap, petugasData, lokasiData, komoditasData));
        } catch (innerError) {
          if (kDebugMode) {
            print('Error building StLengkap for item ${itemMap['id_surat_tugas']}: $innerError');
          }
        }
      }

      for (var tugasItem in allTasksFromDb) {
        String currentDbStatus = tugasItem.status;
        DateTime? tanggalTugasDateOnly;
        StLengkap currentTugasToProcess = tugasItem;

        try {
          if (tugasItem.tanggal.isNotEmpty) {
            DateTime parsedTanggal = DateTime.parse(tugasItem.tanggal);
            tanggalTugasDateOnly = DateTime(parsedTanggal.year, parsedTanggal.month, parsedTanggal.day);
          }
        } catch (e) {
          if (kDebugMode) {
            print("⚠️ Gagal parse tanggal ST ${tugasItem.noSt} ('${tugasItem.tanggal}'). Error: $e");
          }
        }

        if (currentDbStatus == 'selesai') {
          DateTime? tanggalPenyelesaianUntukFilter;
          if (kDebugMode) {
            print("DEBUG _loadSuratTugas: ST [${tugasItem.noSt}] berstatus 'selesai'. Mencari Hasil Pemeriksaan...");
          }
          List<HasilPemeriksaan> hasilPemeriksaanList = await db.getHasilPemeriksaanById(tugasItem.idSuratTugas);

          if (kDebugMode) {
            print("   Jumlah Hasil Pemeriksaan ditemukan untuk ST [${tugasItem.noSt}]: ${hasilPemeriksaanList.length}");
          }

          if (hasilPemeriksaanList.isNotEmpty) {
            hasilPemeriksaanList.sort((a, b) {
              DateTime? dateA = DateTime.tryParse(a.tanggal);
              DateTime? dateB = DateTime.tryParse(b.tanggal);
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA);
            });

            String tanggalPeriksaStringDariDb = hasilPemeriksaanList.first.tanggal;
            tanggalPenyelesaianUntukFilter = DateTime.tryParse(tanggalPeriksaStringDariDb);

            if (tanggalPenyelesaianUntukFilter != null) {
              currentTugasToProcess = tugasItem.copyWith(tanggalSelesai: tanggalPenyelesaianUntukFilter);
              if (kDebugMode) {
                print("   String 'tanggal' (tgl_periksa) dari HasilPemeriksaan TERBARU: '$tanggalPeriksaStringDariDb'");
                print("   ✅ PARSING BERHASIL: tanggalPenyelesaianUntukFilter diisi dengan: $tanggalPenyelesaianUntukFilter for ST ${currentTugasToProcess.noSt}");
                print("   >>> Objek StLengkap [${currentTugasToProcess.noSt}] diupdate. Nilai tugas.tanggalSelesai: ${currentTugasToProcess.tanggalSelesai}");
              }
            } else if (kDebugMode) {
              print("   ❌ PARSING GAGAL untuk string: '$tanggalPeriksaStringDariDb'");
            }
          } else if (kDebugMode) {
            print("   ⚠️ Tidak ada Hasil Pemeriksaan ditemukan untuk ST Selesai [${tugasItem.noSt}].");
          }
        }

        if (currentDbStatus == 'tertunda' || currentDbStatus == 'Proses') {
          bool isExpired = false;
          if (tanggalTugasDateOnly != null) {
            if (today.difference(tanggalTugasDateOnly).inDays > 7) {
              isExpired = true;
            }
          } else {
            if (kDebugMode) {
              print("🤔 ST Masuk ${tugasItem.noSt} tidak memiliki tanggal yang valid untuk cek kedaluwarsa atau tanggal kosong.");
            }
          }

        if (isExpired) {
          if (kDebugMode) {
            print("👻 ST Masuk ${currentTugasToProcess.noSt} (tanggal: ${currentTugasToProcess.tanggal}) kedaluwarsa (>7 hari) dan akan disembunyikan");
          }
          if (currentDbStatus == 'Proses') {
            await db.updateStatusTugas(currentTugasToProcess.idSuratTugas, 'tertunda');
          }
          continue;
        }
          if (isExpired && kDebugMode) {
            if (kDebugMode) {
              print("DEBUG: ST Masuk ${currentTugasToProcess.noSt} (tanggal: ${currentTugasToProcess.tanggal}) kedaluwarsa.");
            }
          }
        }

        if (currentDbStatus == 'dikirim' || currentDbStatus == 'tersimpan_offline') {
          if (tempPrioritasUtama == null) {
            tempPrioritasUtama = currentTugasToProcess;
          } else {
            tempSuratTugasTertunda.add(currentTugasToProcess);
          }
        } else if (currentDbStatus == 'aktif') {
          if (tempPrioritasKedua == null) {
            tempPrioritasKedua = currentTugasToProcess;
          } else {
            tempSuratTugasTertunda.add(currentTugasToProcess.copyWith(status: 'tertunda'));
            if (currentDbStatus != 'tertunda') {
              await db.updateStatusTugas(currentTugasToProcess.idSuratTugas, 'tertunda');
            }
          }
        } else if (currentDbStatus == 'tertunda' || currentDbStatus == 'Proses') {
          tempSuratTugasTertunda.add(currentTugasToProcess.copyWith(status: 'tertunda'));
          if (currentDbStatus == 'Proses') {
            await db.updateStatusTugas(currentTugasToProcess.idSuratTugas, 'tertunda');
          }
        } else if (currentDbStatus == 'selesai') {
          tempSuratTugasSelesai.add(currentTugasToProcess);
        }
      }

      StLengkap? finalSuratTugasAktif;
      if (tempPrioritasUtama != null) {
        finalSuratTugasAktif = tempPrioritasUtama;
        if (tempPrioritasKedua != null) {
          tempSuratTugasTertunda.add(tempPrioritasKedua.copyWith(status: 'tertunda'));
          if (tempPrioritasKedua.status != 'tertunda') {
            await db.updateStatusTugas(tempPrioritasKedua.idSuratTugas, 'tertunda');
          }
        }
      } else if (tempPrioritasKedua != null) {
        finalSuratTugasAktif = tempPrioritasKedua;
      }

      if (finalSuratTugasAktif != null) {
        tempSuratTugasTertunda.removeWhere((st) => st.idSuratTugas == finalSuratTugasAktif!.idSuratTugas);
      }

      if (!mounted) return;

      setState(() {
        suratTugasAktif = finalSuratTugasAktif;
        hasActiveTask = finalSuratTugasAktif != null;
        suratTugasTertunda = tempSuratTugasTertunda..sort((a, b) => (a.noSt).compareTo(b.noSt));
        suratTugasSelesai = tempSuratTugasSelesai..sort((a, b) {
          DateTime? dateA = a.tanggalSelesai ?? DateTime.tryParse(a.tanggal);
          DateTime? dateB = b.tanggalSelesai ?? DateTime.tryParse(b.tanggal);
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

        if (kDebugMode) {
          print('📊 Setelah memuat (logika prioritas & filter kedaluwarsa): hasActiveTask = $hasActiveTask');
          print('📊 Tugas aktif: ${suratTugasAktif?.noSt ?? 'Tidak ada'} (Status: ${suratTugasAktif?.status ?? 'N/A'})');
          print('📊 Jumlah tugas tertunda (setelah filter): ${suratTugasTertunda.length}');
          for (var st in suratTugasTertunda) {
            print('   - Tertunda (UI): ${st.noSt} (Status: ${st.status}, Tanggal: ${st.tanggal})');
          }
          print('📊 Jumlah tugas selesai (setelah filter & sort): ${suratTugasSelesai.length}');
          for (var st in suratTugasSelesai) {
            print("   - ST Selesai: ${st.noSt}, Tanggal Selesai di Model: ${st.tanggalSelesai}, Tanggal ST: ${st.tanggal}");
          }
        }
      });

      if (mounted) {
        _applySelesaiFilter();
      }

    } catch (e) {
      if (kDebugMode) print('❌ Error memuat surat tugas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data surat tugas: ${e.toString().substring(0, (e.toString().length > 30 ? 30 : e.toString().length))}...'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          suratTugasAktif = null;
          hasActiveTask = false;
          suratTugasTertunda = [];
          suratTugasSelesai = [];
          _filteredSuratTugasSelesai = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (syncWithApi) _isSyncingApi = false;
        });
      }
    }
  }

  Future<void> _terimaTugas(StLengkap tugas) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
                const Text("Menerima tugas...", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      Navigator.pop(context);
    } else {
      return;
    }
    await _updateDatabaseForTerimaTugas(tugas.idSuratTugas);
    StLengkap tugasYangDiterima = tugas.copyWith(status: 'aktif');

    setState(() {
      suratTugasAktif = tugasYangDiterima;
      hasActiveTask = true;
      suratTugasTertunda.removeWhere((item) => item.idSuratTugas == tugas.idSuratTugas);
    });
    if (mounted) {
      _loadSuratTugas(syncWithApi: false);
    }
  }

  Future<void> _updateDatabaseForTerimaTugas(String idSuratTugas) async {
    try {
      final db = DatabaseHelper();
      if (kDebugMode) print('✅ Memperbarui database lokal: $idSuratTugas menjadi aktif');
      await db.updateStatusTugas(idSuratTugas, 'aktif');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saat memperbarui status tugas di DB: $e');
      }
    }
  }

  void _selesaikanTugas() async {
    if (suratTugasAktif != null) {
      final db = DatabaseHelper();
      final tugasSelesai = suratTugasAktif!;

      if (kDebugMode) print('✅ Menyelesaikan tugas secara lokal: ${tugasSelesai.idSuratTugas}');

      await db.updateStatusTugas(tugasSelesai.idSuratTugas, 'selesai');

      if (mounted) {
        setState(() {
          suratTugasSelesai.insert(0, tugasSelesai.copyWith(status: 'selesai', tanggalSelesai: DateTime.now()));
          suratTugasAktif = null;
          hasActiveTask = false;
          _applySelesaiFilter();
        });
        _loadSuratTugas(syncWithApi: false);
      }
    }
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customDateFilter ?? DateTime.now().subtract(Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: MyApp.karantinaBrown,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _customDateFilter) {
      setState(() {
        _customDateFilter = picked;
        _selectedSelesaiFilter = "Pilih Tanggal";
      });
      _applySelesaiFilter();
    }
  }

  Future<void> _refreshData() async {
    if (kDebugMode) print('🔄 Memperbarui data pengguna...');
    await _loadSuratTugas(syncWithApi: true);
  }

  void _applySelesaiFilter() {
    if (!mounted) return;
    DateTime now = DateTime.now();
    List<StLengkap> tempFiltered = [];
    if (suratTugasSelesai.isEmpty) {
      if (mounted) {
        setState(() {
          _filteredSuratTugasSelesai = [];
        });
      }
      return;
    }
    Duration? filterDuration;
    DateTime? cutoffDate;
    if (_selectedSelesaiFilter == "7 Hari Terakhir") {
      filterDuration = const Duration(days: 7);
      cutoffDate = now.subtract(filterDuration);
    } else if (_selectedSelesaiFilter == "31 Hari Terakhir") {
      filterDuration = const Duration(days: 31);
      cutoffDate = now.subtract(filterDuration);
    } else if (_selectedSelesaiFilter == "3 Bulan Terakhir") {
      filterDuration = const Duration(days: 90);
      cutoffDate = now.subtract(filterDuration);
    } else if (_selectedSelesaiFilter == "Pilih Tanggal" && _customDateFilter != null) {
      cutoffDate = _customDateFilter;
    }
    if (cutoffDate != null) {
      for (var tugas in suratTugasSelesai) {
        DateTime? taskDate;
        if (kDebugMode) {
          print("DEBUG _applySelesaiFilter: Memproses ST [${tugas.noSt}]");
          print("   - tugas.tanggalSelesai (dari model): ${tugas.tanggalSelesai}");
          print("   - tugas.tanggal (tanggal ST): ${tugas.tanggal}");
        }
        try {
          if (tugas.tanggalSelesai != null) {
            taskDate = tugas.tanggalSelesai;
            if (kDebugMode) print("   -> Digunakan taskDate dari tugas.tanggalSelesai: $taskDate");
          } else {
            taskDate = DateTime.tryParse(tugas.tanggal);
            if (kDebugMode) {
              if (taskDate != null) {
                print("   -> FALLBACK: Digunakan taskDate dari tugas.tanggal: $taskDate");
              } else {
                print("   -> FALLBACK: GAGAL PARSE tugas.tanggal: '${tugas.tanggal}'");
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print("   -> ERROR PARSING TANGGAL untuk ST ${tugas.noSt}: $e");
          }
        }
        if (taskDate != null && taskDate.isAfter(cutoffDate)) {
          tempFiltered.add(tugas);
        }
      }
    }
    if (mounted) {
      setState(() {
        _filteredSuratTugasSelesai = tempFiltered;
      });
    }
    if (kDebugMode) {
      print("Filter selesai diterapkan: $_selectedSelesaiFilter, Jumlah hasil: ${_filteredSuratTugasSelesai.length}");
    }
  }

  Widget _buildRow(String label, String? value) {
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
              textAlign: TextAlign.left,
            ),
          ),
          const Text(":", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value ?? ""),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundText(String text) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animation.value,
                child: child,
              );
            },
            child: Image.asset('images/not_found.png', height: 100, width: 100),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _selectedSelesaiFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : MyApp.karantinaBrown,
        ),
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedSelesaiFilter = value;
            _customDateFilter = null;
          });
          _applySelesaiFilter();
        }
      },
      selectedColor: MyApp.karantinaBrown,
      backgroundColor: Colors.grey[100],
      checkmarkColor: Colors.white,
      elevation: isSelected ? 2 : 0,
      pressElevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? MyApp.karantinaBrown : Colors.grey.shade300,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildCustomDateChip() {
    bool isSelected = _selectedSelesaiFilter == "Pilih Tanggal";
    String displayText = isSelected && _customDateFilter != null
        ? "${_customDateFilter!.day}/${_customDateFilter!.month}/${_customDateFilter!.year}"
        : "Pilih Tanggal";
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: isSelected ? Colors.white : MyApp.karantinaBrown,
          ),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : MyApp.karantinaBrown,
            ),
          ),
        ],
      ),
      onPressed: _showDatePicker,
      backgroundColor: isSelected ? MyApp.karantinaBrown : Colors.grey[100],
      elevation: isSelected ? 2 : 0,
      pressElevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? MyApp.karantinaBrown : Colors.grey.shade300,
          width: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pemeriksaan Lapangan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: MyApp.karantinaBrown,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: (_isLoading || _isSyncingApi) ? null : _refreshData,
            tooltip: 'Perbarui Data',
          ),
        ],
      ),
      body: (_isLoading && suratTugasAktif == null && suratTugasTertunda.isEmpty && suratTugasSelesai.isEmpty) // Tampilkan loader utama hanya jika semua list kosong dan sedang loading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF522E2E)),
            ),
            SizedBox(height: 16),
            Text(_isSyncingApi ? 'Sinkronisasi data dari server...' : 'Memuat data surat tugas...'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          children: [
            // ---- ST MASUK ----
            ExpansionTile(
              initiallyExpanded: true,
              title: const Text("Surat Tugas Masuk", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF522E2E),),),
              leading: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + _animation.value.abs() * 0.2,
                    child: child,
                  );
                },
                child: Icon(
                  Icons.circle,
                  color: suratTugasTertunda.isNotEmpty ? Colors.orange : Colors.grey,
                  size: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (suratTugasTertunda.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${suratTugasTertunda.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down),
                ],
              ),
              children: suratTugasTertunda.isEmpty
                  ? [_buildNotFoundText("Tidak ada surat tugas masuk saat ini")]
                  : suratTugasTertunda.map((tugas) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  tugas.noSt,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(context,
                                    MaterialPageRoute(
                                      builder: (context) => SuratTugasTertunda(
                                        suratTugas: tugas,
                                        onTerimaTugas: () => _terimaTugas(tugas),
                                        hasActiveTask: hasActiveTask,
                                      ),
                                    ),
                                  );
                                  if (result == true || mounted) {
                                    _loadSuratTugas(syncWithApi: false);
                                  }
                                },
                                child: const Text("Lihat Detail", style: TextStyle(color: Colors.orange)),
                              )
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRow("Dasar", tugas.dasar),
                              _buildRow(
                                "Lokasi",
                                tugas.lokasi.isNotEmpty ? tugas.lokasi[0].namaLokasi : "-",
                              ),
                              _buildRow("Tanggal Tugas", tugas.tanggal),
                              _buildRow("Perihal", tugas.hal),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // ---- ST AKTIF ----
            ExpansionTile(
              initiallyExpanded: true,
              title: Text("Surat Tugas Aktif", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: MyApp.karantinaBrown,),),
              leading: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + _animation.value,
                    child: child,
                  );
                },
                child: Icon(
                  Icons.circle,
                  color: hasActiveTask ? Colors.green : Colors.grey,
                  size: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasActiveTask)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down),
                ],
              ),
              children: hasActiveTask && suratTugasAktif != null
                  ? [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  suratTugasAktif?.noSt ?? "-",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: suratTugasAktif?.status == 'dikirim' || suratTugasAktif?.status == 'tersimpan_offline'
                                        ? Colors.white
                                        : Color(0xFFD8F3DC),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                onPressed: () async {
                                  if (suratTugasAktif == null) return;
                                  final result;
                                  if (suratTugasAktif!.status == 'dikirim' || suratTugasAktif!.status == 'tersimpan_offline') {
                                    result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetailLaporan(
                                          idSuratTugas: suratTugasAktif!.idSuratTugas,
                                          suratTugas: suratTugasAktif!,
                                          onSelesaiTugas: _selesaikanTugas,
                                          isViewOnly: false,
                                          showDetailHasil: true,
                                        ),
                                      ),
                                    );
                                  } else {
                                    result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SuratTugasAktifPage(
                                          idSuratTugas: suratTugasAktif!.idSuratTugas,
                                          suratTugas: suratTugasAktif!,
                                          onSelesaiTugas: _selesaikanTugas,
                                        ),
                                      ),
                                    );
                                  }
                                  if (result == true && mounted) {
                                    _loadSuratTugas(syncWithApi: false);
                                  }
                                },
                                child: Text(
                                  (suratTugasAktif?.status == 'dikirim' || suratTugasAktif?.status == 'tersimpan_offline')
                                      ? "Lihat Detail"
                                      : "Buat Laporan",
                                  style: TextStyle(
                                      color: (suratTugasAktif?.status == 'dikirim' || suratTugasAktif?.status == 'tersimpan_offline')
                                          ? Colors.green
                                          : const Color(0xFF1B4332)
                                  ),
                                )),
                            ],
                          ),
                        ),
                        // BODY
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRow("Dasar", suratTugasAktif?.dasar),
                              _buildRow(
                                "Lokasi",
                                suratTugasAktif?.lokasi.isNotEmpty == true
                                    ? suratTugasAktif!.lokasi[0].namaLokasi
                                    : "-",
                              ),
                              _buildRow("Tanggal Tugas", suratTugasAktif?.tanggal),
                              _buildRow("Perihal", suratTugasAktif?.hal),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ]
                  : [_buildNotFoundText("Tidak ada surat tugas aktif saat ini")],
            ),

            // --- SELESAI ---
            ExpansionTile(
              title: const Text(
                "Surat Tugas Selesai",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: MyApp.karantinaBrown),
              ),
              leading: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + _animation.value.abs() * 0.2,
                    child: child,
                  );
                },
                child: Icon(
                  Icons.circle,
                  color: _filteredSuratTugasSelesai.isNotEmpty
                      ? Colors.blue
                      : Colors.grey,
                  size: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_filteredSuratTugasSelesai.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filteredSuratTugasSelesai.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down),
                ],
              ),
              initiallyExpanded: true,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip("7 Hari", "7 Hari Terakhir"),
                            const SizedBox(width: 8),
                            _buildFilterChip("31 Hari", "31 Hari Terakhir"),
                            const SizedBox(width: 8),
                            _buildFilterChip("3 Bulan", "3 Bulan Terakhir"),
                            const SizedBox(width: 8),
                            _buildCustomDateChip(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Menampilkan ${_filteredSuratTugasSelesai.length} dari ${suratTugasSelesai.length} surat tugas",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                _filteredSuratTugasSelesai.isEmpty
                    ? _buildNotFoundText("Tidak ada surat tugas selesai untuk saat ini")
                    : Column(
                  children: _filteredSuratTugasSelesai.map((tugas) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      tugas.noSt,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailLaporan(
                                            idSuratTugas: tugas.idSuratTugas,
                                            suratTugas: tugas,
                                            onSelesaiTugas: () {},
                                            isViewOnly: true,
                                            showDetailHasil: true,
                                            customTitle: "Surat Tugas Selesai",
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text("Lihat Detail",
                                        style: TextStyle(color: Colors.blue)),
                                  )
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildRow("Dasar", tugas.dasar),
                                  _buildRow(
                                    "Lokasi",
                                    tugas.lokasi.isNotEmpty
                                        ? tugas.lokasi[0].namaLokasi
                                        : "-",
                                  ),
                                  _buildRow("Tanggal Tugas", tugas.tanggal),
                                  _buildRow("Perihal", tugas.hal),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            SizedBox(height: 35),

            /*
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _isLoading ? null : () async {
                          try {
                            setState(() {
                              _isLoading = true;
                            });

                            final db = DatabaseHelper();
                            final userNip = authProvider.userId;

                            if (userNip == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gagal sinkronisasi: NIP pengguna tidak ditemukan.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            await db.syncUnsentData(userNip);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Data berhasil disinkronkan'),
                                backgroundColor: Colors.green,
                              ),
                            );

                            await _loadSuratTugas();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal sinkronisasi: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          backgroundColor: Color(0xFF522E2E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
                        ),
                        child: Text(
                            _isLoading ? "Mengirim..." : "Sinkronisasi Data",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)
                        ),
                      ),
                      if (kDebugMode) ...[
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await DatabaseHelper().deleteDatabaseFile();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Database berhasil dihapus (Mode Debug)')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          child: Text("Debug: Hapus Database", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            */
          ],
        ),
      ),
    );
  }
}
