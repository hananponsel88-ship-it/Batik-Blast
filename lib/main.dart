import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pjbl_yallah/settings.dart';
import 'package:pjbl_yallah/halamanlogin.dart';
import 'package:pjbl_yallah/level.dart';
import 'package:pjbl_yallah/profilegame.dart';
import 'package:pjbl_yallah/ranking.dart';
import 'package:pjbl_yallah/store.dart';
import 'package:pjbl_yallah/gamepuzzle.dart';
import 'package:pjbl_yallah/splashbaru.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://enniuhihkgoxogljkbux.supabase.co',
    anonKey: 'sb_publishable_uJd94LPLtBGw-iJYouak-A_4-DRXusy',
  );
  runApp(const BatikMakerApp());
}

class BatikMakerApp extends StatelessWidget {
  const BatikMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Batik Maker',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const SplashScreen(),
    );
  }
}

// ══════════════════════════════════════════
//  MAIN MENU SCREEN
// ══════════════════════════════════════════
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/back.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Awan dekorasi
            Positioned(top: 50, left: 20, child: _buildCloud(110, 0.4)),
            Positioned(top: 120, right: 30, child: _buildCloud(90, 0.3)),
            Positioned(top: 250, left: -20, child: _buildCloud(70, 0.2)),

            // Konten utama
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    children: [
                      const SizedBox(height: 75),   // ← diubah: 40 → 80
                      const LogoSection(),
                      const SizedBox(height: 100),  // ← diubah: 170 → 100
                      const MainButtonsSection(),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),

            // ── KIRI ATAS: Tombol AKUN ──
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 12),
                  child: _CornerIconButton(
                    icon: Icons.account_circle_rounded,
                    gradientColors: const [Color(0xFFFFD700), Color(0xFFE67E22)],
                    glowColor: const Color(0xFFFFD700),
                    onTap: () => showProfilePopup(context),
                  ),
                ),
              ),
            ),

            // ── KANAN ATAS: Tombol SETTING ──
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, top: 12),
                  child: _CornerIconButton(
                    icon: Icons.tune_rounded,
                    gradientColors: const [Color(0xFFB05A1A), Color(0xFF7A3A0A)],
                    glowColor: const Color(0xFFE67E22),
                    onTap: () => showPengaturanPopup(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloud(double size, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Icon(Icons.cloud, size: size, color: Colors.white),
    );
  }
}

// ══════════════════════════════════════════
//  CORNER ICON BUTTON — tanpa label
// ══════════════════════════════════════════
class _CornerIconButton extends StatefulWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final Color glowColor;
  final VoidCallback onTap;

  const _CornerIconButton({
    required this.icon,
    required this.gradientColors,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_CornerIconButton> createState() => _CornerIconButtonState();
}

class _CornerIconButtonState extends State<_CornerIconButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _tapCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _tapAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.09)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _tapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _tapAnim = Tween<double>(begin: 1.0, end: 0.86)
        .animate(CurvedAnimation(parent: _tapCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.mediumImpact();
        _tapCtrl.forward();
      },
      onTapUp: (_) {
        _tapCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tapCtrl.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnim, _glowAnim, _tapAnim]),
        builder: (_, __) {
          final scale = _tapCtrl.isAnimating ? _tapAnim.value : _pulseAnim.value;
          final glow = 0.35 + _glowAnim.value * 0.4;

          return Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Glow ring
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.glowColor.withOpacity(glow),
                          blurRadius: 20 + _glowAnim.value * 14,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                // Tombol bulat tanpa label
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.gradientColors,
                    ),
                    border: Border.all(
                      color: Colors.white
                          .withOpacity(0.55 + _glowAnim.value * 0.45),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.38),
                          blurRadius: 8,
                          offset: const Offset(0, 5)),
                      BoxShadow(
                          color: widget.gradientColors[0].withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, -2)),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 27,
                      shadows: [
                        Shadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 4)
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 5),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════
//  LOGO SECTION
// ══════════════════════════════════════════
class LogoSection extends StatelessWidget {
  const LogoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Image.asset(
        'assets/images/batik_blast_logo.png',
        width: 305,   // ← diubah: 330 → 300
        height: 195,  // ← diubah: 210 → 190
        fit: BoxFit.contain,
      ),
    );
  }
}

// ══════════════════════════════════════════
//  MAIN BUTTONS
// ══════════════════════════════════════════
class MainButtonsSection extends StatelessWidget {
  const MainButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PopUpButton(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LevelGame()),
          ),
          text: "PUZZLE",
          fontSize: 30,
          topColor: const Color(0xFFFFD54F),
          bottomColor: const Color(0xFFFFA000),
        ),
        const SizedBox(height: 20),
        PopUpButton(
          text: "STORE",
          fontSize: 30,
          topColor: const Color(0xFFFF7043),
          bottomColor: const Color(0xFFD84315),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BatikStorePage()),
          ),
        ),
        const SizedBox(height: 20),
        PopUpButton(
          text: "LEADERBOARD",
          fontSize: 20,
          width: 220,
          topColor: const Color(0xFF7B5EA7),
          bottomColor: const Color(0xFF4A3080),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RankingPage()),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  POPUP BUTTON
// ══════════════════════════════════════════
class PopUpButton extends StatefulWidget {
  final String text;
  final Color topColor;
  final Color bottomColor;
  final VoidCallback onTap;
  final double fontSize;
  final double width;

  const PopUpButton({
    super.key,
    required this.text,
    required this.topColor,
    required this.bottomColor,
    required this.onTap,
    this.fontSize = 30,
    this.width = 220,
  });

  @override
  State<PopUpButton> createState() => _PopUpButtonState();
}

class _PopUpButtonState extends State<PopUpButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _scale;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.1,
    )..addListener(() => setState(() {}));
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1.0 - _controller.value;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: Transform.scale(
        scale: _scale,
        child: Container(
          width: widget.width,
          height: 65,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.topColor, widget.bottomColor],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.bottomColor.withOpacity(0.9),
                offset: Offset(0, 8 * _scale),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                offset: Offset(0, 10 * _scale),
                blurRadius: 15,
              ),
            ],
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Center(
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2.5,
                shadows: [
                  Shadow(
                      blurRadius: 4,
                      color: Colors.black38,
                      offset: Offset(2, 2))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}