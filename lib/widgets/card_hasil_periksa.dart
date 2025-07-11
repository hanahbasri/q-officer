import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:q_officer_barantin/main.dart';
import '../databases/db_helper.dart';
import 'package:q_officer_barantin/additional/tanggal.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HasilPeriksaCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool canTap;
  final bool showSync;
  final bool enableAutoSlide;
  final VoidCallback? onTap;
  final Future<void> Function()? onSyncPressed;
  final Key? syncButtonKey;


  const HasilPeriksaCard({
    super.key,
    required this.item,
    this.canTap = false,
    this.showSync = false,
    this.enableAutoSlide = false,
    this.onTap,
    this.onSyncPressed,
    this.syncButtonKey,
  });

  @override
  State<HasilPeriksaCard> createState() => _HasilPeriksaCardState();
}

class _HasilPeriksaCardState extends State<HasilPeriksaCard> {
  bool _isSyncing = false;
  late PageController _localPageController;
  int _currentPhotoIndex = 0;
  Timer? _autoScrollTimer;

  List<Map<String, dynamic>>? _cachedFotoList;
  bool _isLoadingFoto = true;

  @override
  void initState() {
    super.initState();
    _localPageController = PageController();
    _loadFotoData();
  }

  Future<void> _loadFotoData() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoadingFoto = true;
      });

      final fotoList = await DatabaseHelper().getImageFromDatabase(widget.item['id_pemeriksaan']);

      if (mounted) {
        setState(() {
          _cachedFotoList = fotoList;
          _isLoadingFoto = false;
        });
        if (widget.enableAutoSlide && fotoList.length > 1) {
          _startAutoScroll();
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print("Error loading foto data: $e");
      }
      if (mounted) {
        setState(() {
          _isLoadingFoto = false;
        });
      }
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _cachedFotoList != null && _cachedFotoList!.length > 1) {
        _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
          if (mounted && _cachedFotoList != null) {
            _scrollToNextPhoto();
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _scrollToNextPhoto() {
    if (!mounted || _cachedFotoList == null) return;

    final photoCount = _cachedFotoList!.length;
    if (photoCount <= 1) return;

    final nextIndex = (_currentPhotoIndex + 1) % photoCount;

    if (_localPageController.hasClients && mounted) {
      try {
        _localPageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        if (kDebugMode) {
          print("Error in page animation: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _localPageController.dispose();
    super.dispose();
  }

  Widget _buildPhotoSection() {
    if (_isLoadingFoto) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF522E2E)),
        ),
      );
    }

    if (_cachedFotoList == null || _cachedFotoList!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey[200],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, color: Colors.grey, size: 36),
              SizedBox(height: 8),
              Text(
                "Tidak ada foto",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final fotoList = _cachedFotoList!;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _localPageController,
            itemCount: fotoList.length,
            onPageChanged: (index) {
              if (mounted) {
                setState(() {
                  _currentPhotoIndex = index;
                });
              }
            },
            itemBuilder: (context, index) {
              final bytes = base64Decode(fotoList[index]['foto'] as String);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        if (fotoList.length > 1)
          SmoothPageIndicator(
            controller: _localPageController,
            count: fotoList.length,
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              spacing: 6,
              activeDotColor: Color(0xFF522E2E),
              dotColor: Colors.grey.shade300,
            ),
          ),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final bool isSynced = item['syncdata'] == 1; // Cek status sinkronisasi

    final Color syncButtonBorderColor = isSynced ? Colors.green.shade700 : const Color(0xFF522E2E);
    final Color syncIconColor = isSynced ? Colors.green.shade700 : const Color(0xFF522E2E);
    final Color syncTextColor = isSynced ? Colors.green.shade700 : const Color(0xFF522E2E);

    return GestureDetector(
      onTap: widget.canTap ? widget.onTap : null,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Container(
              decoration: BoxDecoration(
                color: MyApp.karantinaBrown,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['nama_lokasi'] ?? '-',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      formatTanggal(item['tgl_periksa'] ?? ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // FOTO & DETAIL
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 120,
                              child: _buildPhotoSection(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.category, size: 16, color: Color(0xFF522E2E)),
                                const SizedBox(width: 6),
                                const Text(
                                  "Komoditas",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF522E2E),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 22, top: 4, bottom: 12),
                              child: Text(
                                item['nama_komoditas'] ?? '-',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.find_in_page, size: 16, color: Color(0xFF522E2E)),
                                const SizedBox(width: 6),
                                const Text(
                                  "Temuan",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF522E2E),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 22, top: 4),
                              child: Text(
                                item['temuan'] ?? '-',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (widget.showSync) ...[
                    const Divider(height: 24, thickness: 0.5),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: OutlinedButton.icon(
                        key: widget.syncButtonKey,
                        onPressed: isSynced || _isSyncing
                            ? null
                            : () async {
                          if (mounted) setState(() => _isSyncing = true);
                          if (widget.onSyncPressed != null) await widget.onSyncPressed!();
                          if (mounted) setState(() => _isSyncing = false);
                        },
                        icon: _isSyncing
                            ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: syncButtonBorderColor),
                        )
                            : Icon(
                          isSynced ? Icons.check_circle : Icons.sync,
                          color: syncIconColor,
                          size: 18,
                        ),
                        label: Text(
                          _isSyncing
                              ? 'Menyinkron...'
                              : isSynced
                              ? 'Telah Sinkron'
                              : 'Sinkron Sekarang',
                          style: TextStyle(color: syncTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: syncButtonBorderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Bentuk tombol
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Padding tombol
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
