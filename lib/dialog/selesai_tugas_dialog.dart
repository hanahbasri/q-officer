import 'package:flutter/material.dart';
import 'package:q_officer_barantin/main.dart';

Future<void> showAnimatedSelesaikanTugasDialog({
  required BuildContext context,
  required VoidCallback onConfirmed,
}) async {
  final Color primaryColor = MyApp.karantinaBrown;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Selesaikan Tugas Dialog",
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation1, animation2) => const SizedBox(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );

      return ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1.0).animate(curvedAnimation),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
          child: _SelesaikanTugasDialogContent(
            onConfirmed: onConfirmed,
            primaryColor: primaryColor,
          ),
        ),
      );
    },
  );
}

class _SelesaikanTugasDialogContent extends StatefulWidget {
  final VoidCallback onConfirmed;
  final Color primaryColor;

  const _SelesaikanTugasDialogContent({
    required this.onConfirmed,
    required this.primaryColor,
  });

  @override
  State<_SelesaikanTugasDialogContent> createState() =>
      _SelesaikanTugasDialogContentState();
}

class _SelesaikanTugasDialogContentState
    extends State<_SelesaikanTugasDialogContent> with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _iconScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.25)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 35,
      ),
    ]).animate(CurvedAnimation(parent: _iconController, curve: Curves.linear));

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _iconController.forward();
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),

            AnimatedBuilder(
              animation: _iconController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _iconScaleAnimation.value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.primaryColor.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 50,
                  color: widget.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Judul Dialog
            Text(
              'Konfirmasi Selesai Tugas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            // Pesan Dialog
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Apakah Anda yakin ingin menyelesaikan Surat Tugas ini?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.primaryColor,
                      side: BorderSide(color: widget.primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onConfirmed();
                    },
                    child: const Text(
                      'Ya, Selesaikan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}