import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_officer_barantin/services/auth_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animated_text_kit/animated_text_kit.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    if (_navigated) return;
    _navigated = true;

    if (kDebugMode) {
      print('[SplashScreen] Memulai splash screen...');
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await Future.wait([
        Future.delayed(const Duration(seconds: 5)),
        authProvider.checkLoginStatus(),
      ]);

      if (!mounted) return;

      final isLoggedIn = authProvider.isLoggedIn;
      if (kDebugMode) {
        print('[SplashScreen] Status login: $isLoggedIn');
      }

      Navigator.pushReplacementNamed(
        context,
        isLoggedIn ? '/home' : '/login',
      );
    } on SocketException catch (_) {
      if (kDebugMode) print('[SplashScreen] Tidak ada koneksi internet.');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SplashScreen] Terjadi kesalahan: $e');
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Widget _buildLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'images/logo_barantin.png',
          width: 216,
          height: 216,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              print('[SplashScreen] Error dalam memuat gambar: $error');
            }
            return Container(
              width: 216,
              height: 216,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.error, size: 50, color: Colors.red),
            );
          },
        ),

        Shimmer.fromColors(
          baseColor: Colors.transparent,
          highlightColor: Colors.white.withOpacity(0.3),
          child: Container(
            width: 216,
            height: 216,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(68),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomSpacing = MediaQuery.of(context).size.height * 0.07;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFEFEFE), Color(0xFF522E2E)],
              ),
            ),
          ),

          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLogo(),
                const SizedBox(height: 20),
                AnimatedTextKit(
                  isRepeatingAnimation: false,
                  animatedTexts: [
                    TyperAnimatedText(
                      'Q-Officer',
                      textStyle: const TextStyle(
                        color: Color(0xFF133139),
                        fontSize: 30,
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                      speed: const Duration(milliseconds: 200),
                    ),
                  ],
                )
              ],
            ),
          ),

          Positioned(
            bottom: bottomSpacing,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Powered by',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 109,
                  height: 25,
                  decoration: BoxDecoration(
                    color: const Color(0xFF133139),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Image.asset(
                      'images/best_trust.png',
                      width: 100,
                      height: 21,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        if (kDebugMode) {
                          print('[SplashScreen] Error dalam memuat logo Best Trust: $error');
                        }
                        return const Icon(Icons.error, size: 16, color: Colors.red);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
