import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Pastikan ini diimpor

// Fungsi showLocationRangeValidationDialog tetap sama
Future<bool?> showLocationRangeValidationDialog(
    BuildContext context, {
      required String title,
      required String message,
      required IconData iconData,
      required Color iconColor,
    }) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Location Validation Dialog",
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation1, animation2) => const SizedBox(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.5, end: 1.0).animate(curvedAnimation),
        child: FadeTransition(
          opacity: animation,
          child: _LocationRangeValidationDialogContent(
            title: title,
            message: message,
            iconData: iconData,
            iconColor: iconColor,
          ),
        ),
      );
    },
  );
}

class _LocationRangeValidationDialogContent extends StatefulWidget {
  final String title;
  final String message;
  final IconData iconData;
  final Color iconColor;

  const _LocationRangeValidationDialogContent({
    required this.title,
    required this.message,
    required this.iconData,
    required this.iconColor,
  });

  @override
  State<_LocationRangeValidationDialogContent> createState() =>
      _LocationRangeValidationDialogContentState();
}

class _LocationRangeValidationDialogContentState
    extends State<_LocationRangeValidationDialogContent> with TickerProviderStateMixin { // Tambahkan TickerProviderStateMixin

  late AnimationController _shakeController; // Controller untuk SlideTransition

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this, // Diperlukan TickerProviderStateMixin
      duration: const Duration(milliseconds: 300), // Sama seperti di logout_dialog.dart
    );
    _playShakeAnimation(); // Panggil method untuk memulai animasi slide/shake
  }

  void _playShakeAnimation() async {
    // Mirip dengan logout_dialog.dart
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      _shakeController.forward();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose(); // Jangan lupa dispose controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBrown = Color(0xFF522E2E);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 45, 20, 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Implementasi animasi ikon persis seperti logout_dialog.dart
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0), // Mulai sedikit ke kanan
                    end: const Offset(-0.05, 0),  // Berakhir sedikit ke kiri (efek "shake" atau pergeseran)
                  ).animate(
                    CurvedAnimation(
                      parent: _shakeController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Icon(
                    widget.iconData, // Menggunakan ikon dari parameter widget
                    size: 60,
                    color: widget.iconColor, // Menggunakan warna dari parameter widget
                  ),
                )
                    .animate(onPlay: (controller) => controller.forward()) // Memicu animasi flutter_animate
                    .fadeIn(duration: 300.ms)
                    .scale(duration: 400.ms), // Efek scale dari flutter_animate

                const SizedBox(height: 24),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: darkBrown,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms) // Penyesuaian delay jika perlu
                    .slideY(
                  begin: 0.5,
                  end: 0,
                  duration: 400.ms,
                  delay: 200.ms, // Penyesuaian delay jika perlu
                  curve: Curves.easeOutCubic,
                ),

                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 300.ms) // Penyesuaian delay jika perlu
                      .slideY(
                    begin: 0.5,
                    end: 0,
                    duration: 400.ms,
                    delay: 300.ms, // Penyesuaian delay jika perlu
                    curve: Curves.easeOutCubic,
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(context).pop(true);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200.withOpacity(0.5),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.black54,
                    size: 24,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
        ],
      ),
    );
  }
}