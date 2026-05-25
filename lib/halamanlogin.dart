import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pjbl_yallah/main.dart';
import 'dart:ui';
import 'dart:math' as math;

final supabase = Supabase.instance.client;

class PuzzleBatikApp extends StatelessWidget {
  const PuzzleBatikApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuzzleBatik Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  String _view = 'home';
  bool _loading = false;
  final _nameCtrl = TextEditingController();

  late AnimationController _cardAnim, _shakeAnim, _floatAnim;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _shakeAnim2, _floatY;

  @override
  void initState() {
    super.initState();
    _cardAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _cardFade = CurvedAnimation(parent: _cardAnim, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardAnim, curve: Curves.easeOutBack));
    _shakeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim2 = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeAnim, curve: Curves.easeInOut));
    _floatAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _floatY = Tween<double>(begin: -6, end: 6).animate(CurvedAnimation(parent: _floatAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _cardAnim.dispose(); _shakeAnim.dispose(); _floatAnim.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _shake() { _shakeAnim.reset(); _shakeAnim.forward(); }

  void _showPopup({required String emoji, required Color iconBg, required String title, required String subtitle, required String btnLabel, required VoidCallback onBtn, bool showStars = false, bool isSuccess = false}) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _PremiumPopupSheet(emoji: emoji, iconBg: iconBg, title: title, subtitle: subtitle, btnLabel: btnLabel, onBtn: onBtn, showStars: showStars, isSuccess: isSuccess, onSecondBtn: () => Navigator.pop(context)),
    );
  }

  Future<void> _onGuestLogin() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _shake();
      _showPopup(emoji: '👤', iconBg: const Color(0xFFFFF3E0), title: 'Nama Kosong', subtitle: 'Masukkan nama tampilan kamu dulu!', btnLabel: 'OK', onBtn: () => Navigator.pop(context));
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signInAnonymously();
      if (res.user == null) throw Exception('Gagal membuat sesi anonim.');
      await supabase.from('profiles').upsert({'id': res.user!.id, 'username': name, 'is_guest': true});
      if (mounted) {
        _showPopup(
          emoji: '🎮', iconBg: const Color(0xFFE8F5E9),
          title: 'Selamat Datang, $name!', subtitle: 'Kamu masuk sebagai tamu.\nData tidak tersimpan permanen.',
          btnLabel: 'Mulai Bermain 🎮', showStars: true, isSuccess: true,
          onBtn: () { Navigator.pop(context); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainMenuScreen())); },
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) { _shake(); _showPopup(emoji: '😓', iconBg: const Color(0xFFFFEBEE), title: 'Gagal Simpan Profil', subtitle: 'Error: ${e.message}', btnLabel: 'OK', onBtn: () => Navigator.pop(context)); }
    } on AuthException catch (e) {
      if (mounted) { _shake(); _showPopup(emoji: '🔐', iconBg: const Color(0xFFFFEBEE), title: 'Login Gagal', subtitle: e.message, btnLabel: 'OK', onBtn: () => Navigator.pop(context)); }
    } catch (e) {
      if (mounted) { _shake(); _showPopup(emoji: '😓', iconBg: const Color(0xFFFFEBEE), title: 'Gagal Masuk', subtitle: e.toString(), btnLabel: 'OK', onBtn: () => Navigator.pop(context)); }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onGoogleLogin() async {
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
    } catch (e) {
      if (mounted) { _shake(); _showPopup(emoji: '😓', iconBg: const Color(0xFFFFEBEE), title: 'Login Gagal', subtitle: e.toString(), btnLabel: 'OK', onBtn: () => Navigator.pop(context)); }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSaveGameName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _shake(); return; }
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({'id': userId, 'username': name});
      if (mounted) {
        _showPopup(
          emoji: '🚀', iconBg: const Color(0xFFE8F5E9),
          title: 'Siap Bermain!', subtitle: 'Nama "$name" terdaftar. Ayo main!',
          btnLabel: 'Masuk ke Game 🎮', showStars: true, isSuccess: true,
          onBtn: () { Navigator.pop(context); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainMenuScreen())); },
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) { _shake(); _showPopup(emoji: '😓', iconBg: const Color(0xFFFFEBEE), title: 'Gagal Simpan', subtitle: e.message, btnLabel: 'OK', onBtn: () => Navigator.pop(context)); }
    } catch (e) {
      if (mounted) { _shake(); _showPopup(emoji: '😓', iconBg: const Color(0xFFFFEBEE), title: 'Gagal', subtitle: e.toString(), btnLabel: 'OK', onBtn: () => Navigator.pop(context)); }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/background.png.jpg'), fit: BoxFit.cover))),
        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.2)]))),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _cardFade,
                child: SlideTransition(
                  position: _cardSlide,
                  child: AnimatedBuilder(
                    animation: _shakeAnim2,
                    builder: (_, child) => Transform.translate(offset: Offset(_shakeAnim2.value, 0), child: child),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                      child: _view == 'guest' ? _buildGuestView() : _view == 'username' ? _buildUsernameView() : _buildHomeView(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHomeView() => _glassCard(
    key: const ValueKey('home'),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _buildFloatingLogo(), const SizedBox(height: 28),
      _buildPrimaryButton('🎮  Main sebagai Tamu', () { setState(() { _view = 'guest'; _nameCtrl.clear(); _cardAnim.reset(); _cardAnim.forward(); }); }),
      const SizedBox(height: 16), _buildDivider(), const SizedBox(height: 16),
      _buildGoogleButton(), const SizedBox(height: 8),
      const Text('Login Google untuk simpan progress permanen', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );

  Widget _buildGuestView() => _glassCard(
    key: const ValueKey('guest'),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _buildFloatingLogo(), const SizedBox(height: 16),
      const Text('Main Sebagai Tamu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 4),
      const Text('Masukkan nama untuk game', style: TextStyle(fontSize: 14, color: Colors.white70)),
      const SizedBox(height: 24),
      _buildTextField('Nama tampilan kamu', Icons.person_outline, ctrl: _nameCtrl),
      const SizedBox(height: 8),
      const Text('⚠️ Data tamu tidak tersimpan jika keluar app', style: TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 20),
      _buildPrimaryButton('Masuk  ▶', _loading ? null : _onGuestLogin),
      const SizedBox(height: 12),
      TextButton(onPressed: _loading ? null : () => setState(() => _view = 'home'), child: const Text('← Kembali', style: TextStyle(color: Colors.white70))),
    ]),
  );

  Widget _buildUsernameView() => _glassCard(
    key: const ValueKey('username'),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _buildFloatingLogo(), const SizedBox(height: 16),
      const Text('Nama di Game', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 4),
      const Text('Nama ini tampil di leaderboard', style: TextStyle(fontSize: 14, color: Colors.white70)),
      const SizedBox(height: 24),
      _buildTextField('Nama tampilan kamu', Icons.person_outline, ctrl: _nameCtrl),
      const SizedBox(height: 24),
      _buildPrimaryButton('Lanjut ✨', _loading ? null : _onSaveGameName),
    ]),
  );

  Widget _glassCard({required Widget child, Key? key}) => ClipRRect(
    key: key, borderRadius: BorderRadius.circular(32),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.45), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: child,
      ),
    ),
  );

  Widget _buildFloatingLogo() => AnimatedBuilder(
    animation: _floatY,
    builder: (_, child) => Transform.translate(offset: Offset(0, _floatY.value), child: child),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(height: 64, width: 64, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFFFF8533).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))], image: const DecorationImage(image: AssetImage('assets/images/jatim.png'), fit: BoxFit.cover))),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('Batik Blast', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF6B4226), fontStyle: FontStyle.italic, shadows: [Shadow(color: Colors.white54, offset: Offset(1, 1), blurRadius: 4)])),
        Text('Indonesia Edition', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
      ]),
    ]),
  );

  Widget _buildTextField(String hint, IconData icon, {TextEditingController? ctrl}) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))]),
    child: TextField(controller: ctrl, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14), prefixIcon: Icon(icon, color: const Color(0xFFFF8533)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20))),
  );

  Widget _buildPrimaryButton(String label, VoidCallback? onPressed) => AnimatedContainer(
    duration: const Duration(milliseconds: 200), width: double.infinity, height: 56,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: onPressed != null ? [const Color(0xFFFF6B1A), const Color(0xFFFFB347)] : [Colors.grey.shade400, Colors.grey.shade300]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: onPressed != null ? [BoxShadow(color: const Color(0xFFFF8533).withOpacity(0.5), blurRadius: 14, offset: const Offset(0, 5))] : [],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
      child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
    ),
  );

  Widget _buildDivider() => const Row(children: [
    Expanded(child: Divider(color: Colors.white60, thickness: 1.2)),
    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('atau', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
    Expanded(child: Divider(color: Colors.white60, thickness: 1.2)),
  ]);

  Widget _buildGoogleButton() => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
    child: ElevatedButton(
      onPressed: _loading ? null : _onGoogleLogin,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.network('https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png', width: 26, height: 26, errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Color(0xFF4285F4), size: 28)),
        const SizedBox(width: 12),
        const Text('Login dengan Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
      ]),
    ),
  );
}

class _PremiumPopupSheet extends StatefulWidget {
  final String emoji; final Color iconBg; final String title;
  final String subtitle; final String btnLabel; final VoidCallback onBtn;
  final bool showStars, isSuccess; final VoidCallback onSecondBtn;
  const _PremiumPopupSheet({required this.emoji, required this.iconBg, required this.title, required this.subtitle, required this.btnLabel, required this.onBtn, this.showStars = false, this.isSuccess = false, required this.onSecondBtn});
  @override State<_PremiumPopupSheet> createState() => _PremiumPopupSheetState();
}

class _PremiumPopupSheetState extends State<_PremiumPopupSheet> with TickerProviderStateMixin {
  late AnimationController _slideCtrl, _iconCtrl, _confettiCtrl;
  late Animation<Offset> _slide;
  late Animation<double> _iconScale, _confettiAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _iconCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _iconScale = CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut);
    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _confettiAnim = CurvedAnimation(parent: _confettiCtrl, curve: Curves.easeOut);
    _slideCtrl.forward().then((_) { _iconCtrl.forward(); if (widget.isSuccess) _confettiCtrl.forward(); });
  }

  @override void dispose() { _slideCtrl.dispose(); _iconCtrl.dispose(); _confettiCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: Stack(children: [
        if (widget.isSuccess) Positioned.fill(child: AnimatedBuilder(animation: _confettiAnim, builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_confettiAnim.value)))),
        Container(
          padding: EdgeInsets.fromLTRB(28, 12, 28, MediaQuery.of(context).viewInsets.bottom + 36),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(3))),
            ScaleTransition(scale: _iconScale, child: Container(width: 88, height: 88, decoration: BoxDecoration(color: widget.iconBg, shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.iconBg.withOpacity(0.6), blurRadius: 20, spreadRadius: 4)]), child: Center(child: Text(widget.emoji, style: const TextStyle(fontSize: 44))))),
            const SizedBox(height: 16),
            if (widget.showStars) const Text('★★★★★', style: TextStyle(color: Color(0xFFFFB347), fontSize: 24, letterSpacing: 4)),
            const SizedBox(height: 10),
            Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            Text(widget.subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5)),
            const SizedBox(height: 24),
            Container(
              width: double.infinity, height: 56,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B1A), Color(0xFFFFB347)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFFFF8533).withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 5))]),
              child: ElevatedButton(onPressed: widget.onBtn, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: Text(widget.btnLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5))),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final _rng = math.Random(42);
  static final List<Color> _colors = [const Color(0xFFFF8533), const Color(0xFFFFB347), const Color(0xFF4CAF50), const Color(0xFF2196F3), const Color(0xFFE91E63), const Color(0xFFFFEB3B)];
  _ConfettiPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final paint = Paint();
    for (int i = 0; i < 60; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = -20.0 + (size.height * 0.85 + 20) * progress + math.sin(progress * math.pi * 2 + i) * 20;
      paint.color = _colors[i % _colors.length].withOpacity((1 - progress).clamp(0.0, 1.0));
      final rect = Rect.fromCenter(center: Offset(x, y), width: 6 + _rng.nextDouble() * 6, height: 8 + _rng.nextDouble() * 6);
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(progress * math.pi * 4 + i.toDouble());
      canvas.translate(-rect.center.dx, -rect.center.dy);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
      canvas.restore();
    }
  }
  @override bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}