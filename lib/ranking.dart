import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});
  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _players = [];
  bool _loading = true;

  late AnimationController _floatCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _staggerCtrl;
  late Animation<double> _floatAnim;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatAnim = Tween(begin: -8.0, end: 8.0).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);

    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _fetchRanking();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _shimmerCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRanking() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('scores')
          .select('username, score')
          .order('score', ascending: false)
          .limit(10);
      setState(() {
        _players = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
      _staggerCtrl.forward(from: 0);
      // Pop-up selamat untuk rank 1
      if (_players.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _showTopPlayerPopup(_players[0]);
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _showTopPlayerPopup(Map<String, dynamic> player) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _TopPlayerDialog(player: player),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.35),
          child: SafeArea(
            child: Column(children: [
              _buildTopNav(),
              Expanded(child: _buildContent()),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTopNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        _buildBackButton(),
      ]),
    );
  }

  Widget _buildBackButton() {
    return _PulseBackButton(onTap: () {
      HapticFeedback.mediumImpact();
      _showExitConfirmPopup();
    });
  }

  void _showExitConfirmPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ExitConfirmDialog(
        onConfirm: () { Navigator.pop(context); Navigator.pop(context); },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(children: [
        _buildTrophyHeader(),
        const SizedBox(height: 8),
        _buildBoard(),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildTrophyHeader() {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, child) => Transform.translate(offset: Offset(0, _floatAnim.value * 0.5), child: child),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 20, spreadRadius: 6)],
            ),
          ),
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 32),
          ),
        ]),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: _shimmerAnim,
          builder: (_, child) {
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: const [Color(0xFFFFD700), Colors.white, Color(0xFFFFD700)],
                stops: [
                  (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                  _shimmerAnim.value.clamp(0.0, 1.0),
                  (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds),
              child: const Text('LEADERBOARD',
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white,
                  letterSpacing: 3,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(1, 2))],
                )),
            );
          },
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.5)),
          ),
          child: const Text('Top Pemain Batik Maker 🎨',
            style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.5)),
        ),
      ]),
    );
  }

  Widget _buildBoard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5D2E17), Color(0xFF3E1F0B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFFFD700), width: 3),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
          const BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5E6C0),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          _buildTableHeader(),
          const SizedBox(height: 6),
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFFE67E22)),
                )
              : _players.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('Belum ada data ranking',
                        style: TextStyle(color: Color(0xFF5D2E17), fontSize: 16)),
                    )
                  : _buildRankList(),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8B4513), Color(0xFF5D2E17)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
      ),
      child: const Row(children: [
        Expanded(flex: 2, child: Center(child: Text('RANK', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)))),
        Expanded(flex: 4, child: Center(child: Text('PEMAIN', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)))),
        Expanded(flex: 3, child: Center(child: Text('SKOR', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)))),
      ]),
    );
  }

  Widget _buildRankList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      itemCount: _players.length,
      itemBuilder: (context, index) {
        final delay = index * 0.1;
        return AnimatedBuilder(
          animation: _staggerCtrl,
          builder: (_, child) {
            final t = (((_staggerCtrl.value - delay) / (1 - delay)).clamp(0.0, 1.0));
            return Transform.translate(
              offset: Offset(50 * (1 - t), 0),
              child: Opacity(opacity: t, child: child),
            );
          },
          child: _buildPlayerRow(index, _players[index]),
        );
      },
    );
  }

  Widget _buildPlayerRow(int index, Map<String, dynamic> data) {
    final isTop3 = index < 3;
    final rank = index + 1;

    final List<List<Color>> top3Gradients = [
      [const Color(0xFFFFD700), const Color(0xFFFF8C00)], // Gold
      [const Color(0xFFB0C4DE), const Color(0xFF708090)], // Silver
      [const Color(0xFFCD853F), const Color(0xFF8B4513)], // Bronze
    ];

    final gradient = isTop3
        ? LinearGradient(colors: top3Gradients[index])
        : LinearGradient(colors: [
            index % 2 == 0 ? const Color(0xFF4B230B) : const Color(0xFF3E1F0B),
            index % 2 == 0 ? const Color(0xFF3E1F0B) : const Color(0xFF4B230B),
          ]);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showPlayerDetail(rank, data);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        height: isTop3 ? 54 : 46,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTop3 ? Colors.white.withOpacity(0.4) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isTop3 ? [
            BoxShadow(color: top3Gradients[index][0].withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
          ] : [],
        ),
        child: Row(children: [
          Expanded(flex: 2, child: Center(child: _buildRankBadge(rank, isTop3))),
          Expanded(
            flex: 4,
            child: Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  (data['username'] ?? '?')[0].toUpperCase(),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isTop3 ? 12 : 11),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  data['username'] ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isTop3 ? FontWeight.w900 : FontWeight.w600,
                    fontSize: isTop3 ? 14 : 13,
                    shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${data['score'] ?? 0}',
                  style: TextStyle(
                    color: isTop3 ? Colors.white : const Color(0xFFF3E5AB),
                    fontWeight: FontWeight.w900,
                    fontSize: isTop3 ? 14 : 13,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRankBadge(int rank, bool isTop3) {
    if (rank == 1) return const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24);
    if (rank == 2) return const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22);
    if (rank == 3) return const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20);
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Center(
        child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
      ),
    );
  }

  void _showPlayerDetail(int rank, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _PlayerDetailDialog(rank: rank, data: data),
    );
  }
}

// ── Pulse Back Button ─────────────────────────────────────────
class _PulseBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PulseBackButton({required this.onTap});
  @override
  State<_PulseBackButton> createState() => _PulseBackButtonState();
}

class _PulseBackButtonState extends State<_PulseBackButton> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _tapCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _tapAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
    _tapCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _tapAnim = Tween(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _tapCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); _glowCtrl.dispose(); _tapCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.mediumImpact(); _tapCtrl.forward(); },
      onTapUp: (_) { _tapCtrl.reverse(); widget.onTap(); },
      onTapCancel: () => _tapCtrl.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnim, _glowAnim, _tapAnim]),
        builder: (_, __) {
          final scale = _tapCtrl.isAnimating ? _tapAnim.value : _pulseAnim.value;
          final glow = 0.4 + _glowAnim.value * 0.45;
          return Transform.scale(
            scale: scale,
            child: Stack(clipBehavior: Clip.none, children: [
              // Glow ring luar
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(glow),
                      blurRadius: 22 + _glowAnim.value * 16,
                      spreadRadius: 4,
                    )],
                  ),
                ),
              ),
              // Tombol utama
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB05A1A), Color(0xFF7A3A0A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5 + _glowAnim.value * 0.5),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 5)),
                    BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3 + _glowAnim.value * 0.2), blurRadius: 6, offset: const Offset(0, -2)),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 24,
                    shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 4)]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ── Exit Confirm Dialog ───────────────────────────────────────
class _ExitConfirmDialog extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _ExitConfirmDialog({required this.onConfirm, required this.onCancel});
  @override
  State<_ExitConfirmDialog> createState() => _ExitConfirmDialogState();
}

class _ExitConfirmDialogState extends State<_ExitConfirmDialog> with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _sparkleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _sparkleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _scaleCtrl.forward();
  }

  @override
  void dispose() { _scaleCtrl.dispose(); _sparkleCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5D2E17), Color(0xFF3E1F0B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
            boxShadow: [
              BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 25, spreadRadius: 3),
              const BoxShadow(color: Colors.black54, blurRadius: 15),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Sparkle row
            AnimatedBuilder(
              animation: _sparkleCtrl,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final s = 5.0 + math.sin((_sparkleCtrl.value * 2 * math.pi) + i * 1.2) * 3;
                  return Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(Icons.auto_awesome, color: const Color(0xFFFFD700), size: s));
                }),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 16)],
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 14),
            const Text('Tinggalkan Ranking?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Text(
                '🎨 Terus bermain Batik Maker\ndan raih peringkat #1!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Center(child: Text('TETAP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onConfirm,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Center(child: Text('KELUAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
class _TopPlayerDialog extends StatefulWidget {
  final Map<String, dynamic> player;
  const _TopPlayerDialog({required this.player});
  @override
  State<_TopPlayerDialog> createState() => _TopPlayerDialogState();
}

class _TopPlayerDialogState extends State<_TopPlayerDialog> with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _sparkleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _sparkleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _scaleCtrl.forward();
  }

  @override
  void dispose() { _scaleCtrl.dispose(); _sparkleCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.6), blurRadius: 30, spreadRadius: 5)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _sparkleCtrl,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final s = 6.0 + math.sin((_sparkleCtrl.value * 2 * math.pi) + i * 1.2) * 4;
                  return Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(Icons.auto_awesome, color: Colors.white, size: s));
                }),
              ),
            ),
            const SizedBox(height: 12),
            const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 64,
              shadows: [Shadow(color: Colors.black38, blurRadius: 12)]),
            const SizedBox(height: 8),
            const Text('🏆 JUARA 1 🏆',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: Column(children: [
                Text(widget.player['username'] ?? '-',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text('${widget.player['score'] ?? 0} poin',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('Pemain terbaik Batik Maker! 🎨',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D2E17),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Text('KEREN! 🔥',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Pop-up Detail Pemain ──────────────────────────────────────
class _PlayerDetailDialog extends StatefulWidget {
  final int rank;
  final Map<String, dynamic> data;
  const _PlayerDetailDialog({required this.rank, required this.data});
  @override
  State<_PlayerDetailDialog> createState() => _PlayerDetailDialogState();
}

class _PlayerDetailDialogState extends State<_PlayerDetailDialog> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isTop3 = widget.rank <= 3;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _anim,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5D2E17), Color(0xFF3E1F0B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 20)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFFFFD700).withOpacity(0.2),
              child: Text(
                (widget.data['username'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 32, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.data['username'] ?? '-',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            if (isTop3) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                ),
                child: Text('🏆 Rank #${widget.rank}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ] else
              Text('Rank #${widget.rank}',
                style: const TextStyle(color: Colors.white54, fontSize: 15)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(children: [
                const Text('TOTAL SKOR', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('${widget.data['score'] ?? 0}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 36, fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.orange, blurRadius: 10)])),
              ]),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Text('TUTUP',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}