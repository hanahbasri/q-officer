import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:q_officer_barantin/services/auth_provider.dart';

const Color darkBrown = Color(0xFF522E2E);

Future<Future<Object?>> showAnimatedLogoutDialog(BuildContext context) async {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Logout Dialog",
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
          child: const _LogoutDialogContent(),
        ),
      );
    },
  );
}

class _LogoutDialogContent extends StatefulWidget {
  const _LogoutDialogContent();

  @override
  State<_LogoutDialogContent> createState() => _LogoutDialogContentState();
}

class _LogoutDialogContentState extends State<_LogoutDialogContent> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _playShakeAnimation();
  }

  void _playShakeAnimation() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _shakeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: const Offset(-0.05, 0),
              ).animate(
                CurvedAnimation(
                  parent: _shakeController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: Icon(
                Icons.logout_rounded,
                size: 60,
                color: darkBrown,
              ),
            )
                .animate(onPlay: (controller) => controller.forward())
                .fadeIn(duration: 300.ms)
                .scale(duration: 400.ms),

            const SizedBox(height: 24),

            Text(
              'Keluar Aplikasi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: darkBrown,
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: 200.ms)
                .moveY(begin: 20, end: 0),

            const SizedBox(height: 12),

            Text(
              'Apakah Anda yakin ingin keluar dari akun?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: 300.ms),

            const SizedBox(height: 30),

            FadeTransition(
              opacity: CurvedAnimation(
                parent: ModalRoute.of(context)!.animation!,
                curve: Interval(0.6, 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFF522E2E),
                        side: const BorderSide(color: Color(0xFF522E2E)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Tidak',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF522E2E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isLoading ? null : () => _handleLogout(context),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Ya, Keluar',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}

class AnimatedLogoutButton extends StatefulWidget {
  final VoidCallback onTap;

  const AnimatedLogoutButton({super.key, required this.onTap});

  @override
  State<AnimatedLogoutButton> createState() => _AnimatedLogoutButtonState();
}

class _AnimatedLogoutButtonState extends State<AnimatedLogoutButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovering = true;
        });
        _controller.repeat(reverse: true);
      },
      onExit: (_) {
        setState(() {
          _isHovering = false;
        });
        _controller.stop();
        _controller.reset();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _isHovering ? Colors.red.withOpacity(0.1) : Colors.transparent,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 0.2,
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 22 + (_controller.value * 2),
                ),
              );
            },
          ),
          title: const Text(
            "Keluar",
            style: TextStyle(
              color: Colors.red,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: widget.onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}