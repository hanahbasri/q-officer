import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:q_officer_barantin/beranda/side_bar.dart';
import 'package:q_officer_barantin/main.dart';
import 'package:q_officer_barantin/services/auth_provider.dart';
import 'package:shimmer/shimmer.dart';

import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _iconController;
  bool _isLogoLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkLoginStatus();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _isLogoLoaded = true);
        }
      });
    });
    _iconController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _showEmptyFeatureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_iconController),
              child: const Icon(Icons.hourglass_empty_rounded, size: 48, color: MyApp.karantinaBrown),
            ),
            const SizedBox(height: 16),
            const Text('Fitur Kosong', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: MyApp.karantinaBrown)),
            const SizedBox(height: 8),
            const Text('Mohon maaf, halaman ini masih kosong.\nSilakan coba kembali nanti.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: MyApp.karantinaBrown, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            height: 24,
            width: 4,
            decoration: BoxDecoration(color: const Color(0xFF8D6E63), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFD69983), Color(0xFF4E342E)],
            ).createShader(bounds),
            child: const Text('Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SideBar(),
      body: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.isLoggedIn) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF8D6E63)));
            }

            final userName = auth.userFullName ?? "User";

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(context),
                SliverToBoxAdapter(child: _buildWelcomeSection(userName)),
                SliverToBoxAdapter(child: _buildMenuHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildMenuCard(
                        icon: 'images/pk_icon.png',
                        title: 'Pemeriksaan\nLapangan',
                        onTap: () {
                          Navigator.pushNamed(context, '/surat-tugas');
                        },
                      ),

                      _buildMenuCard(
                        icon: 'images/icon_qdc.png',
                        title: 'Q-Declare',
                        onTap: () {
                          Navigator.pushNamed(context, '/q-declare');
                        },
                      ),
                      _buildMenuCard(
                        icon: 'images/plus_icon.png',
                        title: 'Lainnya',
                        onTap: _showEmptyFeatureDialog,
                        isDashed: true,
                      ),
                    ]),
                  ),
                ),
              ],
            );
          }
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          ClipPath(
            clipper: BottomWaveClipper(),
            child: Container(
              height: 230,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8D6E63), Color(0xFF422929), Color(0xFF5A2F2F)],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, size: 32, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.notifications, size: 32, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pushNamed('/notif-history');
              },
            ),
          ),
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _iconController,
                builder: (context, child) {
                  double dx = 6 * (0.5 - (_iconController.value - 0.5).abs());
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: _isLogoLoaded
                        ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset('images/logo_barantin.png', height: 90, width: 90),
                        ClipOval(
                          child: SizedBox(
                            width: 70,
                            height: 70,
                            child: Opacity(
                              opacity: 0.3,
                              child: Shimmer.fromColors(
                                baseColor: Colors.white.withOpacity(0.4),
                                highlightColor: Colors.white.withOpacity(0.8),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        : const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(String userName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selamat Datang,', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: MyApp.karantinaBrown)),
          const SizedBox(height: 4),
          Text('Siap memulai hari yang produktif?', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String icon,
    required String title,
    required VoidCallback onTap,
    bool isDashed = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = constraints.maxWidth * 0.25;

        return GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isDashed
                  ? BorderSide(color: Colors.grey.shade300, width: 1.2)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    icon,
                    height: iconSize,
                    width: iconSize,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: MyApp.karantinaBrown,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30);
    var secondControlPoint = Offset(3 * size.width / 4, size.height - 60);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
