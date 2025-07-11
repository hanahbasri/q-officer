import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_officer_barantin/beranda/akun_saya.dart';
import 'package:q_officer_barantin/models/komoditas.dart';
import 'package:q_officer_barantin/models/petugas.dart';
import 'package:q_officer_barantin/services/auth_provider.dart';
import 'dart:io';
import 'package:q_officer_barantin/dialog/logout_dialog.dart';
import '../surat_tugas/detail_laporan.dart';

import '../databases/db_helper.dart';
import '../models/lokasi.dart';
import '../models/st_lengkap.dart';
import '../surat_tugas/st_masuk.dart';

const Color darkBrown = Color(0xFF522E2E);
const Color lightBackground = Color(0xFFF7F4EF);
const Color darkerText = Color(0xFF2E1C1C);

class SideBar extends StatelessWidget {
  const SideBar({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final namaLengkap = authProvider.userFullName ?? "Pengguna";
    final nipPengguna = authProvider.userNip ?? "NIP tidak tersedia";

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      backgroundColor: lightBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarHeader(
            nama: namaLengkap,
            nip: nipPengguna,
            authProvider: authProvider,
          ),
          const SizedBox(height: 12),
          _SidebarTile(
            icon: Icons.person_outline,
            title: "Akun Saya",
            iconColor: darkerText,
            textColor: darkerText,
            onTap: () {
              if (Scaffold.of(context).isDrawerOpen) {
                Navigator.pop(context); // Close drawer
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AkunSayaPage()),
              );
            },
          ),
          _SidebarTile(
            icon: Icons.help_outline,
            title: "Tutorial Aplikasi",
            iconColor: darkerText,
            textColor: darkerText,
            onTap: () {
              // context here is from SideBar's build method
              _showTutorialOptions(context);
            },
          ),
          AnimatedLogoutButton(
            onTap: () => showAnimatedLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showTutorialOptions(BuildContext outerContext) { // outerContext is from SideBar
    showModalBottomSheet(
      context: outerContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext bottomSheetContext) { // bottomSheetContext is for the sheet's content
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Pilih Tutorial",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
              const SizedBox(height: 20),

              _TutorialOptionItem(
                title: "Surat Tugas Masuk",
                description: "Tutorial tentang halaman detail surat tugas masuk yang belum diterima",
                icon: Icons.assignment_outlined,
                onTap: () async {
                  Navigator.pop(bottomSheetContext); // Pop the bottom sheet first

                  // Then, close the drawer if it's open
                  if (outerContext.mounted && Scaffold.of(outerContext).isDrawerOpen) {
                    Navigator.pop(outerContext);
                  }
                  // Ensure a small delay for the drawer to close before showing SnackBar or navigating
                  await Future.delayed(const Duration(milliseconds: 100));


                  try {
                    final db = DatabaseHelper();
                    final data = await db.getData('Surat_Tugas');
                    StLengkap? suratTugasTertunda;

                    for (var item in data) {
                      final status = item['status'] ?? '';
                      if (status == 'tertunda' || status == 'Proses') {
                        final futures = await Future.wait([
                          db.getPetugasById(item['id_surat_tugas']),
                          db.getLokasiById(item['id_surat_tugas']),
                          db.getKomoditasById(item['id_surat_tugas']),
                        ]);
                        final petugasList = (futures[0] as List).map((p) => Petugas.fromDbMap(p)).toList();
                        final lokasiList = (futures[1] as List).map((l) => Lokasi.fromDbMap(l)).toList();
                        final komoditasList = (futures[2] as List).map((k) => Komoditas.fromDbMap(k)).toList();
                        suratTugasTertunda = StLengkap.fromDbMap(item, petugasList, lokasiList, komoditasList);
                        break;
                      }
                    }

                    if (suratTugasTertunda != null && outerContext.mounted) {
                      Navigator.push(
                        outerContext,
                        MaterialPageRoute(
                          builder: (context) => SuratTugasTertunda(
                            suratTugas: suratTugasTertunda!,
                            onTerimaTugas: () async {
                              ScaffoldMessenger.of(outerContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Ini adalah mode tutorial - tombol tidak aktif'),
                                  backgroundColor: Color(0xFF522E2E),
                                ),
                              );
                            },
                            hasActiveTask: false,
                            showTutorialImmediately: true,
                          ),
                        ),
                      );
                    } else if (outerContext.mounted) {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(
                          content: Text('Tidak ada surat tugas masuk untuk tutorial'),
                          backgroundColor: Color(0xFF522E2E),
                        ),
                      );
                    }
                  } catch (e) {
                    if (outerContext.mounted){
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        SnackBar(
                          content: Text('Gagal memuat data untuk tutorial: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 10),

              _TutorialOptionItem(
                title: "Detail Laporan (Surat Tugas Aktif)",
                description: "Tutorial halaman detail laporan untuk surat tugas yang sudah memiliki hasil pemeriksaan.",
                icon: Icons.assignment_turned_in_outlined,
                onTap: () async {
                  Navigator.pop(bottomSheetContext); // Pop the bottom sheet

                  if (outerContext.mounted && Scaffold.of(outerContext).isDrawerOpen) {
                    Navigator.pop(outerContext); // Close the drawer
                  }
                  await Future.delayed(const Duration(milliseconds: 100));


                  try {
                    final db = DatabaseHelper();
                    final data = await db.getData('Surat_Tugas');
                    StLengkap? suratTugasUntukTutorial;

                    for (var item in data) {
                      final status = item['status'] ?? '';
                      if (status == 'dikirim' || status == 'tersimpan_offline') {
                        final hasilPemeriksaan = await db.getPeriksaById(item['id_surat_tugas']);
                        if (hasilPemeriksaan.isNotEmpty) {
                          final futures = await Future.wait([
                            db.getPetugasById(item['id_surat_tugas']),
                            db.getLokasiById(item['id_surat_tugas']),
                            db.getKomoditasById(item['id_surat_tugas']),
                          ]);
                          suratTugasUntukTutorial = StLengkap.fromDbMap(
                            item,
                            (futures[0] as List).map((p) => Petugas.fromDbMap(p)).toList(),
                            (futures[1] as List).map((l) => Lokasi.fromDbMap(l)).toList(),
                            (futures[2] as List).map((k) => Komoditas.fromDbMap(k)).toList(),
                          );
                          break;
                        }
                      }
                    }

                    if (suratTugasUntukTutorial != null && outerContext.mounted) {
                      Navigator.push(
                        outerContext,
                        MaterialPageRoute(
                          builder: (context) => DetailLaporan(
                            suratTugas: suratTugasUntukTutorial!,
                            idSuratTugas: suratTugasUntukTutorial.idSuratTugas,
                            onSelesaiTugas: () { /* Kosongkan untuk mode tutorial */ },
                            isViewOnly: false,
                            showDetailHasil: true,
                            showTutorialImmediately: true,
                          ),
                        ),
                      );
                    } else if(outerContext.mounted) {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(
                          content: Text('Tidak ada surat tugas dengan laporan untuk tutorial ST Aktif.'),
                          backgroundColor: Color(0xFF522E2E),
                        ),
                      );
                    }
                  } catch (e) {
                    if (outerContext.mounted){
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        SnackBar(
                          content: Text('Gagal memuat data untuk tutorial ST Aktif: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              _TutorialOptionItem(
                title: "Detail Surat Tugas Selesai",
                description: "Tutorial halaman detail untuk surat tugas yang telah selesai.",
                icon: Icons.task_alt_outlined,
                onTap: () async {
                  Navigator.pop(bottomSheetContext); // Pop the bottom sheet

                  if (outerContext.mounted && Scaffold.of(outerContext).isDrawerOpen) {
                    Navigator.pop(outerContext); // Close the drawer
                  }
                  await Future.delayed(const Duration(milliseconds: 100));


                  try {
                    final db = DatabaseHelper();
                    final data = await db.getData('Surat_Tugas');
                    StLengkap? suratTugasSelesaiUntukTutorial;

                    for (var item in data) {
                      final status = item['status'] ?? '';
                      if (status == 'selesai') {
                        final hasilPemeriksaan = await db.getPeriksaById(item['id_surat_tugas']);
                        if (hasilPemeriksaan.isNotEmpty) {
                          final futures = await Future.wait([
                            db.getPetugasById(item['id_surat_tugas']),
                            db.getLokasiById(item['id_surat_tugas']),
                            db.getKomoditasById(item['id_surat_tugas']),
                          ]);
                          suratTugasSelesaiUntukTutorial = StLengkap.fromDbMap(
                            item,
                            (futures[0] as List).map((p) => Petugas.fromDbMap(p)).toList(),
                            (futures[1] as List).map((l) => Lokasi.fromDbMap(l)).toList(),
                            (futures[2] as List).map((k) => Komoditas.fromDbMap(k)).toList(),
                          );
                          break;
                        }
                      }
                    }

                    if (suratTugasSelesaiUntukTutorial != null && outerContext.mounted) {
                      Navigator.push(
                        outerContext,
                        MaterialPageRoute(
                          builder: (context) => DetailLaporan(
                            suratTugas: suratTugasSelesaiUntukTutorial!,
                            idSuratTugas: suratTugasSelesaiUntukTutorial.idSuratTugas,
                            onSelesaiTugas: () { /* Kosongkan untuk mode tutorial */ },
                            isViewOnly: true,
                            showDetailHasil: true,
                            customTitle: "Surat Tugas Selesai",
                            showTutorialImmediately: true,
                          ),
                        ),
                      );
                    } else if (outerContext.mounted) {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(
                          content: Text('Tidak ada Surat Tugas Selesai dengan hasil pemeriksaan untuk tutorial.'),
                          backgroundColor: Color(0xFF522E2E),
                        ),
                      );
                    }
                  } catch (e) {
                    if (outerContext.mounted){
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        SnackBar(
                          content: Text('Gagal memuat data untuk tutorial Surat Tugas Selesai: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TutorialOptionItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _TutorialOptionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: darkBrown.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: darkBrown.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: darkBrown,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: darkBrown,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: darkBrown,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final String nama;
  final String nip;
  final AuthProvider authProvider;

  const _SidebarHeader({
    required this.nama,
    required this.nip,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = authProvider.userPhotoPath != null &&
        File(authProvider.userPhotoPath!).existsSync();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      color: darkBrown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            backgroundImage: hasPhoto
                ? FileImage(File(authProvider.userPhotoPath!))
                : null,
            child: !hasPhoto
                ? const Icon(Icons.person, size: 36, color: darkBrown)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            nama,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            nip,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;

  const _SidebarTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor = darkBrown,
    this.textColor = darkBrown,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: darkBrown.withOpacity(0.06),
    );
  }
}