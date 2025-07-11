import 'package:flutter/material.dart';
import 'package:q_officer_barantin/main.dart';

Future<void> showAnimatedUnsyncedDataDialog({
  required BuildContext context,
}) async {
  final Color primaryColor = MyApp.karantinaBrown;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Unsynced Data Dialog",
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
          child: _UnsyncedDataDialogContent(
            primaryColor: primaryColor,
          ),
        ),
      );
    },
  );
}

class _UnsyncedDataDialogContent extends StatefulWidget {
  final Color primaryColor;

  const _UnsyncedDataDialogContent({
    required this.primaryColor,
  });

  @override
  State<_UnsyncedDataDialogContent> createState() =>
      _UnsyncedDataDialogContentState();
}

class _UnsyncedDataDialogContentState
    extends State<_UnsyncedDataDialogContent> with SingleTickerProviderStateMixin {
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
                  color: Colors.orange.shade100,
                ),
                child: Icon(
                  Icons.sync_problem_rounded,
                  size: 50,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Data Belum Tersinkronisasi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(height: 12),

            // Pesan Dialog
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Anda tidak dapat menyelesaikan tugas ini karena masih ada data yang belum disinkronkan. Harap sinkronkan semua data terlebih dahulu.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: 120,
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
                },
                child: const Text(
                  'Mengerti',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}