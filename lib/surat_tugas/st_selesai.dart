import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:q_officer_barantin/databases/db_helper.dart';
import 'package:q_officer_barantin/main.dart';

class SuratTugasSelesai extends StatefulWidget {
  final Map<String, dynamic> hasilPemeriksaan;

  const SuratTugasSelesai({super.key, required this.hasilPemeriksaan});

  @override
  State<SuratTugasSelesai> createState() => _SuratTugasSelesaiState();
}

class _SuratTugasSelesaiState extends State<SuratTugasSelesai> {
  List<String> base64List = [];
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    loadFoto();
    _pageController.addListener(() {
      if (!_pageController.hasClients) return;
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> loadFoto() async {
    final id = widget.hasilPemeriksaan['id_pemeriksaan'];
    final db = DatabaseHelper();
    final list = await db.getImageBase64List(id);
    setState(() {
      base64List = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasil = widget.hasilPemeriksaan;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hasil Pemeriksaan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: MyApp.karantinaBrown,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (base64List.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      itemCount: base64List.length,
                      controller: _pageController,
                      itemBuilder: (context, index) {
                        final bytes = base64Decode(base64List[index]);
                        return Container(
                          width: MediaQuery.of(context).size.width * 0.105,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: MyApp.karantinaBrown.withOpacity(0.8),
                              width: 1,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () => _showImagePreview(context, bytes),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(bytes, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const Text("Belum ada foto"),

                if (base64List.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        base64List.length,
                            (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? MyApp.karantinaBrown
                                : Colors.grey.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                _buildRow("Lokasi", hasil['nama_lokasi']),
                _buildRow("Target / Sasaran", hasil['target']),
                _buildRow("Metode", hasil['metode']),
                _buildRow("Komoditas", hasil['nama_komoditas']),
                _buildRow("Temuan", hasil['temuan']),
                _buildRow("Catatan", hasil['catatan']),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String? value) {
    final isCatatan = label.toLowerCase().contains("catatan");
    final isEmpty = value == null || value.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(label, style: TextStyle(fontWeight: FontWeight.bold))),
          Text(" : "),
          Expanded(
            flex: 5,
            child: isCatatan && isEmpty
                ? Text("Tidak ada catatan", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]))
                : Text(value ?? "-"),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    child: Image.memory(imageBytes),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Tutup"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}