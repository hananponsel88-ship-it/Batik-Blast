import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pjbl_yallah/gamepuzzle.dart';
import 'package:pjbl_yallah/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LevelGameApp extends StatelessWidget {
  const LevelGameApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const LevelGame();
  }
}

class LevelGame extends StatefulWidget {
  const LevelGame({super.key});
  @override State<LevelGame> createState() => _LevelGameState();
}

class _LevelGameState extends State<LevelGame> with TickerProviderStateMixin {
  // Default hanya level 1 yang terbuka
  int _maxUnlocked = 1;
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _floatAnim = Tween(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _floatCtrl.dispose(); super.dispose(); }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _maxUnlocked = prefs.getInt('max_unlocked') ?? 1);
  }

  /// Dipanggil HANYA saat player menyelesaikan level (bukan game over)
  Future<void> _unlockNext(int completedLevel) async {
    final nextLevel = completedLevel + 1;
    if (nextLevel > _maxUnlocked) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('max_unlocked', nextLevel);
      setState(() => _maxUnlocked = nextLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/background.png.jpg"), fit: BoxFit.cover),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(children: [
              _buildHeader(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: _buildCard(MediaQuery.of(context).size),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainMenuScreen()));
          },
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFB05A1A), Color(0xFF7A3A0A)]),
              border: Border.all(color: const Color(0xFFFFD700), width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0,4))],
            ),
            child: const Icon(Icons.undo_rounded, color: Colors.white, size: 26),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard(Size screen) {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, child) => Transform.translate(offset: Offset(0, _floatAnim.value * 0.3), child: child),
      child: Container(
        width: screen.width * 0.88,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFF0C080), Color(0xFFD4894A)],
          ),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: const Color(0xFF5D3A1A), width: 5),
          boxShadow: [
            BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 25, spreadRadius: 3, offset: const Offset(0,8)),
            const BoxShadow(color: Colors.black38, blurRadius: 15, offset: Offset(0,6)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8B4513), Color(0xFF5D3A1A)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0,4))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.menu_book_rounded, color: Color(0xFFFFD700), size: 22),
              SizedBox(width: 10),
              Text('PILIH LEVEL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 2)),
            ]),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _buildLevelGrid(),
          ),
        ]),
      ),
    );
  }

  Widget _buildLevelGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0),
      itemCount: 12,
      itemBuilder: (context, index) {
        final level = index + 1;
        final isLocked = level > _maxUnlocked;
        final isCompleted = level < _maxUnlocked;
        final target = targetSkorLevel(level);

        return _LevelButton(
          level: level,
          isLocked: isLocked,
          isCompleted: isCompleted,
          targetScore: target,
          onTap: () {
            if (isLocked) {
              HapticFeedback.heavyImpact();
              _showLockedDialog(level);
            } else {
              HapticFeedback.lightImpact();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MainNavigatorWithCallback(
                  initialLevel: level,
                  // Callback ini hanya dipanggil saat level WIN (target tercapai)
                  onLevelComplete: () => _unlockNext(level),
                ),
              ));
            }
          },
        );
      },
    );
  }

  void _showLockedDialog(int level) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFD4894A), Color(0xFF8B4513)]),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFD700), width: 3),
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 20)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFFFD700), size: 52),
            const SizedBox(height: 12),
            const Text('Level Terkunci!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Selesaikan level ${level - 1} dulu\n(capai target skornya!)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF5D3A1A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LevelButton extends StatefulWidget {
  final int level;
  final bool isLocked;
  final bool isCompleted;
  final int targetScore;
  final VoidCallback onTap;
  const _LevelButton({
    required this.level, required this.isLocked, required this.isCompleted,
    required this.targetScore, required this.onTap,
  });
  @override State<_LevelButton> createState() => _LevelButtonState();
}

class _LevelButtonState extends State<_LevelButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.88).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.isLocked
        ? const LinearGradient(colors: [Color(0xFF9E9E9E), Color(0xFF757575)])
        : widget.isCompleted
            ? const LinearGradient(colors: [Color(0xFF66BB6A), Color(0xFF388E3C)])
            : const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFE65100)]);

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isCompleted ? const Color(0xFFA5D6A7) : Colors.white.withOpacity(0.4),
              width: 2,
            ),
            boxShadow: widget.isLocked ? [] : [
              BoxShadow(
                color: (widget.isCompleted ? Colors.green : Colors.orange).withOpacity(0.5),
                blurRadius: 10, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(children: [
            if (!widget.isLocked)
              Positioned(top: 4, left: 4, right: 20,
                child: Container(height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            Center(
              child: widget.isLocked
                  ? const Icon(Icons.lock_rounded, color: Colors.white, size: 28)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      if (widget.isCompleted)
                        const Icon(Icons.star_rounded, color: Colors.yellow, size: 16),
                      Text('${widget.level}',
                        style: const TextStyle(color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
                      Text('${widget.targetScore}⭐',
                        style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class MainNavigatorWithCallback extends StatelessWidget {
  final VoidCallback onLevelComplete;
  final int initialLevel;
  const MainNavigatorWithCallback({super.key, required this.onLevelComplete, this.initialLevel = 1});

  @override
  Widget build(BuildContext context) {
    return MainNavigator(onLevelComplete: onLevelComplete, initialLevel: initialLevel);
  }
}