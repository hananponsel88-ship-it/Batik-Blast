import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pjbl_yallah/halamanlogin.dart'; // halaman login

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────
class UserProfile {
  final String username;
  final String? avatarUrl;
  final int stars;
  final int pieces;
  final int topPuzzleRank;
  final int score;

  UserProfile({
    required this.username,
    this.avatarUrl,
    required this.stars,
    required this.pieces,
    required this.topPuzzleRank,
    required this.score,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      username: map['username'] ?? 'Player',
      avatarUrl: map['avatar_url'],
      stars: map['stars'] ?? 0,
      pieces: map['pieces'] ?? 0,
      topPuzzleRank: map['top_puzzle_rank'] ?? 0,
      score: map['score'] ?? 0,
    );
  }
}

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────
class ProfileService {
  final _supabase = Supabase.instance.client;

  Future<UserProfile> fetchProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User belum login.');
    final response =
        await _supabase.from('profiles').select().eq('id', userId).single();
    return UserProfile.fromMap(response);
  }

  Future<int> fetchBestScore() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    final rows = await _supabase
        .from('scores')
        .select('score')
        .eq('user_id', userId)
        .order('score', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows[0]['score'] as int?) ?? 0;
  }

  Future<int> fetchPuzzleRank() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;
    final myBest = await fetchBestScore();
    if (myBest == 0) return 0; // belum pernah main
    final rows = await _supabase.from('scores').select('user_id, score');
    if (rows.isEmpty) return 1;
    final Map<String, int> userBest = {};
    for (final r in rows) {
      final uid = r['user_id'] as String;
      final sc = (r['score'] as int?) ?? 0;
      if ((userBest[uid] ?? 0) < sc) userBest[uid] = sc;
    }
    return userBest.values.where((s) => s > myBest).length + 1;
  }

  Future<String?> uploadAvatar(XFile xfile) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final path = 'avatars/$userId.jpg';
    final bytes = await xfile.readAsBytes();
    await _supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final url = _supabase.storage.from('avatars').getPublicUrl(path);
    await _supabase
        .from('profiles')
        .update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}

// ─────────────────────────────────────────────
// PROFILE POPUP - dipanggil dari main screen
// ─────────────────────────────────────────────
void showProfilePopup(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Profile',
    barrierColor: Colors.black.withOpacity(0.7),
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (_, __, ___) => const _ProfilePopupContent(),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1.5, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
}

class _ProfilePopupContent extends StatefulWidget {
  const _ProfilePopupContent();

  @override
  State<_ProfilePopupContent> createState() => _ProfilePopupContentState();
}

class _ProfilePopupContentState extends State<_ProfilePopupContent>
    with TickerProviderStateMixin {
  final ProfileService _service = ProfileService();

  UserProfile? _profile;
  int _bestScore = 0;
  int _rank = 0;
  bool _loading = true;
  String? _error;
  bool _uploadingAvatar = false;
  bool _loggingOut = false;

  late AnimationController _shimmerCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _logoutPulseCtrl;
  late Animation<double> _entryScale;
  late Animation<double> _logoutPulse;
  final List<_FloatingParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _floatCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _particleCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entryScale =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut);

    _logoutPulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _logoutPulse = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _logoutPulseCtrl, curve: Curves.easeInOut),
    );

    final rng = math.Random();
    for (int i = 0; i < 14; i++) {
      _particles.add(_FloatingParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 7 + 3,
        speed: rng.nextDouble() * 0.003 + 0.001,
        phase: rng.nextDouble() * 2 * math.pi,
        color: [
          const Color(0xFFFFD700),
          const Color(0xFFE67E22),
          const Color(0xFFB05A1A),
          Colors.white,
        ][rng.nextInt(4)],
      ));
    }

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profile = await _service.fetchProfile();
      final best = await _service.fetchBestScore();
      final rank = await _service.fetchPuzzleRank();
      if (mounted) {
        setState(() {
          _profile = profile;
          _bestScore = best;
          _rank = rank;
          _loading = false;
        });
        _entryCtrl.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _floatCtrl.dispose();
    _particleCtrl.dispose();
    _entryCtrl.dispose();
    _logoutPulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    HapticFeedback.lightImpact();
    try {
      final url = await _service.uploadAvatar(picked);
      if (url != null && mounted) {
        setState(() {
          _profile = UserProfile(
            username: _profile!.username,
            avatarUrl: url,
            stars: _profile!.stars,
            pieces: _profile!.pieces,
            topPuzzleRank: _rank,
            score: _bestScore,
          );
        });
        _showSuccessSnack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal upload: $e'),
          backgroundColor: Colors.red[700],
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showSuccessSnack() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        Icon(Icons.check_circle, color: Colors.white),
        SizedBox(width: 8),
        Text('Foto berhasil diperbarui! 🎉'),
      ]),
      backgroundColor: Color(0xFF4CAF50),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();

    // Konfirmasi dialog sebelum logout
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3DC),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF633112), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tinggalkan Permainan?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4A2511),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Progres & skor kamu tetap tersimpan.\nSampai jumpa, pengrajin batik! 🎨',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A4A2A),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAD2A8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF633112).withOpacity(0.4)),
                      ),
                      child: const Text(
                        'Batal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF633112),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Log Out',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _loggingOut = true);
    HapticFeedback.heavyImpact();

    try {
      await _service.signOut();
      if (mounted) {
        Navigator.of(context).pop(); // tutup popup
        // Navigasi ke halaman login — sesuaikan route-nya
        // Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal logout: $e'),
          backgroundColor: Colors.red[700],
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: sw * 0.9,
          constraints: BoxConstraints(maxHeight: sh * 0.88),
          child: Stack(
            children: [
              // Particle background layer
              AnimatedBuilder(
                animation: _particleCtrl,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: CustomPaint(
                    painter:
                        _ParticlePainter(_particles, _particleCtrl.value),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              // Main card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF633112),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.orange.withOpacity(0.6),
                        blurRadius: 40,
                        spreadRadius: 6),
                    const BoxShadow(
                        color: Colors.black54, blurRadius: 24),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF3DC), Color(0xFFFDE0A8)],
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: _loading
                        ? const SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFFFD700), strokeWidth: 3),
                            ),
                          )
                        : _error != null
                            ? _buildErrorState()
                            : ScaleTransition(
                                scale: _entryScale,
                                child: _buildContent(),
                              ),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF633112),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFFFD700), width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 6)
                      ],
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isNotLoggedIn =>
      _error != null &&
      (_error!.toLowerCase().contains('belum login') ||
          _error!.toLowerCase().contains('not logged') ||
          _error!.toLowerCase().contains('user null'));

  Widget _buildErrorState() {
    final isLogin = _isNotLoggedIn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title shimmer (same as main)
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, __) => ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: const [
                  Color(0xFF8B4513),
                  Color(0xFFFFD700),
                  Color(0xFF8B4513),
                ],
                stops: [
                  (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                  _shimmerCtrl.value.clamp(0.0, 1.0),
                  (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds),
              child: const Text(
                'BATIK MAKER',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          const Text(
            'PROFILE',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF633112),
                letterSpacing: 2),
          ),
          const SizedBox(height: 28),

          // Floating batik icon
          AnimatedBuilder(
            animation: _floatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, math.sin(_floatCtrl.value * math.pi) * 5),
              child: child,
            ),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFE67E22)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF633112), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.45),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  isLogin ? '🔐' : '😔',
                  style: const TextStyle(fontSize: 38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Main message
          Text(
            isLogin ? 'Belum Masuk Akun' : 'Aduh, Ada Masalah!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4A2511),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Sub message
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAD2A8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF633112).withOpacity(0.25), width: 1.5),
            ),
            child: Text(
              isLogin
                  ? 'Kamu perlu login dulu untuk\nmelihat profil pengrajin batikmu ✨'
                  : 'Tenang, progres batikmu\ntetap aman tersimpan 🎨',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7A4A2A),
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Divider
          Row(children: [
            Expanded(
                child: Container(
                    height: 1.5,
                    color: const Color(0xFF633112).withOpacity(0.2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.auto_awesome,
                  color: const Color(0xFFB05A1A).withOpacity(0.6), size: 14),
            ),
            Expanded(
                child: Container(
                    height: 1.5,
                    color: const Color(0xFF633112).withOpacity(0.2))),
          ]),
          const SizedBox(height: 20),

          // Action button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(); // tutup popup dulu
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (_, anim, __) => const LoginScreen(),
                  transitionsBuilder: (_, anim, __, child) {
                    final curved = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1.0, 0),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 450),
                ),
                (route) => false,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB05A1A), Color(0xFF7A3A0A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: const Color(0xFFFFD700), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.login_rounded,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Masuk Sekarang',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Lanjutkan petualangan batikmu 🌟',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final p = _profile!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title with shimmer
        AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, __) => ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: const [
                Color(0xFF8B4513),
                Color(0xFFFFD700),
                Color(0xFF8B4513),
              ],
              stops: [
                (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                _shimmerCtrl.value.clamp(0.0, 1.0),
                (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds),
            child: const Text(
              'BATIK MAKER',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        const Text(
          'PROFILE',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF633112),
              letterSpacing: 2),
        ),
        const SizedBox(height: 20),

        // Avatar
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _floatCtrl,
              builder: (_, __) => Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(
                          0.4 + 0.3 * math.sin(_floatCtrl.value * math.pi)),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _floatCtrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                    0, math.sin(_floatCtrl.value * math.pi) * 4),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF633112),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                          ? NetworkImage(p.avatarUrl!)
                          : const AssetImage('assets/images/sogan.png.jpg')
                              as ImageProvider,
                ),
              ),
            ),
            // Edit button
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAndUploadPhoto,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFE67E22)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF633112), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 8)
                    ],
                  ),
                  child: _uploadingAvatar
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 17),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Text(
          p.username,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4A2511)),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _statChip(Icons.star_rounded, Colors.yellow[700]!,
              p.stars.toString()),
          const SizedBox(width: 12),
          _statChip(Icons.extension_rounded, Colors.orange[800]!,
              p.pieces.toString()),
        ]),
        const SizedBox(height: 20),

        // Divider
        Row(children: [
          Expanded(
              child: Container(
                  height: 1.5,
                  color: const Color(0xFF633112).withOpacity(0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.auto_awesome,
                color: const Color(0xFFB05A1A).withOpacity(0.7), size: 16),
          ),
          Expanded(
              child: Container(
                  height: 1.5,
                  color: const Color(0xFF633112).withOpacity(0.3))),
        ]),
        const SizedBox(height: 16),

        // Score & Rank
        Row(children: [
          Expanded(
              child: _infoCard(
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFFFD700),
            label: 'BEST SCORE',
            value: _bestScore == 0 ? '-' : _bestScore.toString(),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _infoCard(
            icon: Icons.leaderboard_rounded,
            iconColor: const Color(0xFFE67E22),
            label: 'TOP RANK',
            value: _rank == 0 ? '-' : '#$_rank',
          )),
        ]),
        const SizedBox(height: 18),

        // ── LOGOUT BUTTON ──────────────────────────────────────────
        AnimatedBuilder(
          animation: _logoutPulse,
          builder: (_, child) => Transform.scale(
            scale: _loggingOut ? 1.0 : _logoutPulse.value,
            child: child,
          ),
          child: GestureDetector(
            onTap: _loggingOut ? null : _handleLogout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE74C3C), Color(0xFFAB1C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: const Color(0xFFFF6B6B).withOpacity(0.6),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE74C3C).withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _loggingOut
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.logout_rounded,
                              color: Colors.white, size: 17),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Keluar Akun',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Sampai jumpa, pengrajin batik! 👋',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
        // ── END LOGOUT BUTTON ──────────────────────────────────────
      ],
    );
  }

  Widget _statChip(IconData icon, Color color, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color)),
      ]),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAD2A8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF633112).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.orange.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF633112),
                letterSpacing: 1)),
        const SizedBox(height: 5),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            value,
            key: ValueKey(value),
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4A2511)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// PARTICLES (shared)
// ─────────────────────────────────────────────
class _FloatingParticle {
  final double x;
  double y;
  final double size;
  final double speed;
  final double phase;
  final Color color;
  _FloatingParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_FloatingParticle> particles;
  final double t;
  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = ((p.y - t * p.speed * 30) % 1.0) * size.height;
      final x = p.x * size.width +
          math.sin(t * 2 * math.pi + p.phase) * 15;
      final paint = Paint()
        ..color = p.color.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}