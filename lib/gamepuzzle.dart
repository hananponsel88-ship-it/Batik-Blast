import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pjbl_yallah/level.dart';
// tambahkan di pubspec.yaml: audioplayers: ^5.2.1
import 'package:audioplayers/audioplayers.dart';

final supabase = Supabase.instance.client;

Future<void> saveSkor(int score) async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final profile =
        await supabase.from('profiles').select('username').eq('id', user.id).single();
    final username = profile['username'] ?? 'Player';
    await supabase
        .from('scores')
        .insert({'user_id': user.id, 'username': username, 'score': score});
  } catch (e) {
    debugPrint('Gagal simpan skor: $e');
  }
}

// ── Target skor per level (LEBIH SUSAH) ──
// Level 1: 500, setiap level naik drastis
int targetSkorLevel(int level) {
  if (level <= 1) return 500;
  // Kenaikan makin cepat setiap level
  return targetSkorLevel(level - 1) + 300 + (level - 1) * 150;
}

// ==========================================
// DIFFICULTY CONFIG
// ==========================================
class DifficultyConfig {
  final int gridSize;
  final List<List<List<int>>> shapes;
  final int scoreMultiplier;
  final String label;

  const DifficultyConfig({
    required this.gridSize,
    required this.shapes,
    required this.scoreMultiplier,
    required this.label,
  });

  static DifficultyConfig fromString(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return DifficultyConfig(
          label: 'Easy',
          gridSize: 6,
          scoreMultiplier: 1,
          shapes: [
            [[1]],
            [[1, 1]],
            [[1], [1]],
            [[1, 1], [1, 0]],
            [[1, 0], [1, 1]],
            [[1, 1], [1, 1]],
            [[1, 1, 1]],
            [[1], [1], [1]],
          ],
        );
      case 'Hard':
        return DifficultyConfig(
          label: 'Hard',
          gridSize: 10,
          scoreMultiplier: 2,
          shapes: [
            [[1, 1, 1, 1]],
            [[1], [1], [1], [1]],
            [[1, 1, 1], [1, 0, 0]],
            [[1, 1, 1], [0, 0, 1]],
            [[1, 0, 0], [1, 1, 1]],
            [[0, 0, 1], [1, 1, 1]],
            [[1, 1, 1], [0, 1, 0]],
            [[0, 1, 0], [1, 1, 1]],
            [[1, 0], [1, 1], [0, 1]],
            [[0, 1], [1, 1], [1, 0]],
            [[1, 1, 0], [0, 1, 1]],
            [[0, 1, 1], [1, 1, 0]],
            [[1, 1, 1, 1, 1]],
            [[1, 1], [1, 1]],
          ],
        );
      default: // Medium
        return DifficultyConfig(
          label: 'Medium',
          gridSize: 8,
          scoreMultiplier: 1,
          shapes: [
            [[1, 1], [1, 1]],
            [[1, 1, 1]],
            [[1, 1], [1, 0]],
            [[1], [1], [1]],
            [[1, 1, 1, 1]],
            [[1, 1, 1], [0, 1, 0]],
            [[1, 0], [1, 1]],
            [[0, 1], [1, 1]],
          ],
        );
    }
  }
}

// ==========================================
// ASSETS & MODELS
// ==========================================
class GameAssets {
  static const String backgroundUrl = "background.png.jpg";
  static const String motifUrl = "parang.png.jpg";
}

class PuzzleBlock {
  final List<List<int>> shape;
  final String id;
  final Color color;
  PuzzleBlock({required this.shape, required this.id, required this.color});
}

class Particle {
  Offset position;
  Offset velocity;
  double life;
  final Color color;
  Particle({required this.position, required this.velocity, required this.color})
      : life = 1.0;
}

// ==========================================
// MAIN NAVIGATOR
// ==========================================
class MainNavigator extends StatefulWidget {
  final VoidCallback? onLevelComplete;
  final int initialLevel;
  const MainNavigator({super.key, this.onLevelComplete, this.initialLevel = 1});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  String currentPage = 'game';
  int score = 0;
  int bestScore = 0;
  int currentLevel = 1;
  bool _levelUpShown = false;
  bool _isLoadingDiff = true;

  DifficultyConfig diffConfig = DifficultyConfig.fromString('Medium');
  List<List<String?>> board = List.generate(8, (_) => List.generate(8, (_) => null));

  @override
  void initState() {
    super.initState();
    currentLevel = widget.initialLevel;
    _loadDifficulty();
  }

  Future<void> _loadDifficulty() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoadingDiff = false);
        return;
      }
      final data = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data != null && mounted) {
        final diff = data['difficulty'] ?? 'Medium';
        final config = DifficultyConfig.fromString(diff);
        setState(() {
          diffConfig = config;
          board = List.generate(
            config.gridSize,
            (_) => List.generate(config.gridSize, (_) => null),
          );
        });
      }
    } catch (e) {
      debugPrint('Load difficulty error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDiff = false);
    }
  }

  void resetGame() => setState(() {
        score = 0;
        _levelUpShown = false;
        board = List.generate(
          diffConfig.gridSize,
          (_) => List.generate(diffConfig.gridSize, (_) => null),
        );
        currentPage = 'game';
      });

  void triggerGameOver() async {
    HapticFeedback.heavyImpact();
    if (score > bestScore) bestScore = score;
    await saveSkor(score);
    // Tetap unlock level berikutnya walau game over (sudah progress sejauh ini)
    widget.onLevelComplete?.call();
    setState(() => currentPage = 'score');
  }

  void onScoreChanged(int newScore) {
    setState(() => score = newScore);
    if (!_levelUpShown && newScore >= targetSkorLevel(currentLevel)) {
      _levelUpShown = true;
      // Unlock level berikutnya saat target tercapai
      widget.onLevelComplete?.call();
      Future.delayed(const Duration(milliseconds: 300), _showLevelUpPopup);
    }
  }

  void _showLevelUpPopup() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _LevelUpDialog(
        level: currentLevel,
        onContinue: () {
          Navigator.pop(context);
          setState(() {
            currentLevel++;
            score = 0;
            _levelUpShown = false;
            board = List.generate(
              diffConfig.gridSize,
              (_) => List.generate(diffConfig.gridSize, (_) => null),
            );
          });
        },
        onMenu: () {
          Navigator.pop(context);
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const LevelGameApp()));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDiff) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage('assets/images/background.png.jpg'),
                fit: BoxFit.cover),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 3),
          ),
        ),
      );
    }

    Widget page;
    switch (currentPage) {
      case 'game':
        page = BatikGamePage(
          key: ValueKey('game_${currentLevel}_${diffConfig.label}'),
          score: score,
          board: board,
          currentLevel: currentLevel,
          diffConfig: diffConfig,
          onScoreChanged: onScoreChanged,
          onPauseRequest: () => setState(() => currentPage = 'pause'),
          onGameOver: triggerGameOver,
        );
        break;
      case 'pause':
        page = PausePage(
          key: const ValueKey('pause'),
          onResume: () => setState(() => currentPage = 'game'),
          onReplay: resetGame,
          onHome: resetGame,
        );
        break;
      case 'score':
        page = MyScorePage(
          key: const ValueKey('score'),
          score: score,
          bestScore: bestScore,
          onReplay: resetGame,
        );
        break;
      default:
        page = const SizedBox();
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: page,
      ),
    );
  }
}

// ==========================================
// HALAMAN GAME
// ==========================================
class BatikGamePage extends StatefulWidget {
  final int score;
  final List<List<String?>> board;
  final int currentLevel;
  final DifficultyConfig diffConfig;
  final Function(int) onScoreChanged;
  final VoidCallback onPauseRequest;
  final VoidCallback onGameOver;

  const BatikGamePage({
    super.key,
    required this.score,
    required this.board,
    required this.currentLevel,
    required this.diffConfig,
    required this.onScoreChanged,
    required this.onPauseRequest,
    required this.onGameOver,
  });

  @override
  State<BatikGamePage> createState() => _BatikGamePageState();
}

class _BatikGamePageState extends State<BatikGamePage>
    with TickerProviderStateMixin {
  late List<PuzzleBlock> availableBlocks;
  List<Particle> particles = [];
  late AnimationController _particleController;
  late AnimationController _scorePopController;
  late Animation<double> _scorePopAnim;

  // ── Perfect clear overlay ──
  bool _showPerfect = false;
  int _perfectBonus = 0;
  late AnimationController _perfectCtrl;
  late Animation<double> _perfectAnim;

  // ── Audio player ──
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<Color> blockColors = [
    const Color(0xFFE74C3C),
    const Color(0xFF3498DB),
    const Color(0xFF2ECC71),
    const Color(0xFFF39C12),
    const Color(0xFF9B59B6),
    const Color(0xFF1ABC9C),
  ];

  int get gs => widget.diffConfig.gridSize;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(_updateParticles)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => particles.clear());
      });

    _scorePopController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scorePopAnim =
        CurvedAnimation(parent: _scorePopController, curve: Curves.elasticOut);

    _perfectCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _perfectAnim =
        CurvedAnimation(parent: _perfectCtrl, curve: Curves.elasticOut);

    _generateNewBlocks();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _scorePopController.dispose();
    _perfectCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _updateParticles() {
    setState(() {
      for (var p in particles) {
        p.position += p.velocity;
        p.velocity += const Offset(0, 0.3);
        p.life -= 0.03;
      }
      particles.removeWhere((p) => p.life <= 0);
    });
  }

  void _spawnParticles(Offset center, Color color, {int count = 12}) {
    final rng = math.Random();
    for (int i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = rng.nextDouble() * 5 + 1;
      particles.add(Particle(
        position: center,
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: color,
      ));
    }
    _particleController.forward(from: 0);
  }

  void _generateNewBlocks() {
    final rng = math.Random();
    setState(() {
      availableBlocks = List.generate(
          3,
          (i) => PuzzleBlock(
                id: "${DateTime.now().millisecondsSinceEpoch}_$i",
                shape: widget.diffConfig.shapes[
                    rng.nextInt(widget.diffConfig.shapes.length)],
                color: blockColors[rng.nextInt(blockColors.length)],
              ));
    });
    _validateRemainingBlocks();
  }

  void _validateRemainingBlocks() {
    if (availableBlocks.isEmpty) return;
    for (var block in availableBlocks) {
      bool canPlace = false;
      for (int r = 0; r < gs && !canPlace; r++)
        for (int c = 0; c < gs && !canPlace; c++)
          if (_canPlace(r, c, block)) canPlace = true;
      if (!canPlace) {
        Future.delayed(const Duration(milliseconds: 500), widget.onGameOver);
        return;
      }
    }
  }

  bool _canPlace(int r, int c, PuzzleBlock block) {
    for (int dr = 0; dr < block.shape.length; dr++)
      for (int dc = 0; dc < block.shape[dr].length; dc++)
        if (block.shape[dr][dc] == 1)
          if (r + dr >= gs ||
              c + dc >= gs ||
              widget.board[r + dr][c + dc] != null) return false;
    return true;
  }

  /// Returns (clearedCells, linesCleared) — linesCleared untuk bonus besar
  (int, int) _clearFullLines() {
    int clearedCells = 0;
    int linesCleared = 0;
    Set<int> rowsToClear = {};
    Set<int> colsToClear = {};

    for (int r = 0; r < gs; r++)
      if (widget.board[r].every((cell) => cell != null)) rowsToClear.add(r);
    for (int c = 0; c < gs; c++)
      if (List.generate(gs, (r) => widget.board[r][c])
          .every((cell) => cell != null)) colsToClear.add(c);

    linesCleared = rowsToClear.length + colsToClear.length;

    for (int r in rowsToClear)
      for (int c = 0; c < gs; c++) {
        widget.board[r][c] = null;
        clearedCells++;
      }
    for (int c in colsToClear)
      for (int r = 0; r < gs; r++)
        if (widget.board[r][c] != null) {
          widget.board[r][c] = null;
          clearedCells++;
        }

    return (clearedCells, linesCleared);
  }

  Future<void> _playSempurna() async {
    // Gunakan SystemSound atau asset audio
    // Jika punya asset: await _audioPlayer.play(AssetSource('audio/sempurna.mp3'));
    // Fallback: heavy haptic + selectionClick sequence
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
  }

  void _showPerfectOverlay(int bonus, Offset center, Color color) async {
    await _playSempurna();
    // Partikel lebih banyak & warna-warni
    final colors = [Colors.yellow, Colors.orange, Colors.red, Colors.greenAccent, Colors.cyanAccent];
    for (final c in colors) {
      _spawnParticles(center, c, count: 20);
    }
    setState(() {
      _showPerfect = true;
      _perfectBonus = bonus;
    });
    _perfectCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showPerfect = false);
    });
  }

  void _placeBlock(int r, int c, PuzzleBlock block) {
    if (!_canPlace(r, c, block)) return;
    HapticFeedback.lightImpact();

    setState(() {
      int cells = 0;
      for (int dr = 0; dr < block.shape.length; dr++)
        for (int dc = 0; dc < block.shape[dr].length; dc++)
          if (block.shape[dr][dc] == 1) {
            widget.board[r + dr][c + dc] = GameAssets.motifUrl;
            cells++;
          }

      final mult = widget.diffConfig.scoreMultiplier;
      int baseScore = cells * 10 * mult;
      final (clearedCells, linesCleared) = _clearFullLines();

      // Bonus per baris/kolom: 50 per line, combo +25 tiap line tambahan
      int clearBonus = 0;
      if (linesCleared > 0) {
        clearBonus = (linesCleared * 50 + (linesCleared - 1) * 25) * mult;
        int newScore = widget.score + baseScore + clearBonus;
        widget.onScoreChanged(newScore);

        // Tampilkan overlay sempurna
        final boardSize = MediaQuery.of(context).size.width * 0.92;
        final cellSize = boardSize / gs;
        final center = Offset(
          MediaQuery.of(context).size.width / 2,
          (r + 0.5) * cellSize + 120,
        );
        _showPerfectOverlay(clearBonus, center, block.color);
      } else {
        widget.onScoreChanged(widget.score + baseScore);
      }

      availableBlocks.removeWhere((b) => b.id == block.id);
      if (availableBlocks.isEmpty)
        _generateNewBlocks();
      else
        _validateRemainingBlocks();
    });

    _scorePopController.forward(from: 0);

    final boardSize = MediaQuery.of(context).size.width * 0.92;
    final cellSize = boardSize / gs;
    final center = Offset((c + 0.5) * cellSize, (r + 0.5) * cellSize + 120);
    _spawnParticles(center, block.color);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth * 0.92;
    final target = targetSkorLevel(widget.currentLevel);

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
            image: AssetImage('assets/images/background.png.jpg'),
            fit: BoxFit.cover),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 6),
                _buildScoreDisplay(target),
                const Spacer(),
                _buildBoard(boardSize),
                const Spacer(),
                _buildBlockPicker(screenWidth),
                const SizedBox(height: 20),
              ],
            ),
            if (particles.isNotEmpty)
              Positioned.fill(
                  child: CustomPaint(painter: _ParticlePainter(particles))),
            // ── PERFECT overlay ──
            if (_showPerfect)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: ScaleTransition(
                      scale: _perfectAnim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF6B00)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.orange.withOpacity(0.8),
                                blurRadius: 30,
                                spreadRadius: 6),
                          ],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('✨ SEMPURNA! ✨',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(color: Colors.black38, blurRadius: 6)
                                  ])),
                          const SizedBox(height: 6),
                          Text('+$_perfectBonus poin!',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final Color badgeColor = widget.diffConfig.label == 'Easy'
        ? const Color(0xFF4CAF50)
        : widget.diffConfig.label == 'Hard'
            ? const Color(0xFFF44336)
            : const Color(0xFFB05A1A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [badgeColor, badgeColor.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.yellow, width: 2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('LVL ${widget.currentLevel}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.diffConfig.label.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10),
                ),
              ),
            ]),
          ),
          _circleBtn(Icons.pause_rounded, widget.onPauseRequest),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback tap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        tap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFB05A1A), Color(0xFF7A3A0A)]),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.yellow, width: 2.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildScoreDisplay(int target) {
    final progress = (widget.score / target).clamp(0.0, 1.0);
    return ScaleTransition(
      scale: _scorePopAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFB05A1A), Color(0xFF7A3A0A)]),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.yellow, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, color: Colors.yellow, size: 22),
              const SizedBox(width: 8),
              Text('${widget.score} / $target',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(
                  progress >= 1.0 ? Colors.greenAccent : Colors.orangeAccent),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBoard(double size) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB05A1A), width: 4),
        boxShadow: [
          BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2)
        ],
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gs),
        itemCount: gs * gs,
        itemBuilder: (ctx, i) {
          int r = i ~/ gs;
          int c = i % gs;
          return DragTarget<PuzzleBlock>(
            onAccept: (b) => _placeBlock(r, c, b),
            builder: (ctx, data, rej) {
              final isHovering =
                  data.isNotEmpty && _canPlace(r, c, data.first!);
              final isFilled = widget.board[r][c] != null;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(0.8),
                decoration: BoxDecoration(
                  color: isHovering
                      ? Colors.white.withOpacity(0.5)
                      : isFilled
                          ? null
                          : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(3),
                  border: isHovering
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                  image: isFilled
                      ? const DecorationImage(
                          image: AssetImage('assets/images/parang.png.jpg'),
                          fit: BoxFit.cover)
                      : null,
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 4)
                        ]
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBlockPicker(double screenWidth) {
    final blockSize = screenWidth * 0.065;
    return Container(
      height: 130,
      width: screenWidth * 0.95,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.black.withOpacity(0.6),
          Colors.brown.withOpacity(0.4)
        ]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: availableBlocks.map((b) {
          return Draggable<PuzzleBlock>(
            data: b,
            feedback: Material(
                color: Colors.transparent,
                child: _preview(b, blockSize * 1.6, b.color, true)),
            childWhenDragging: Opacity(
                opacity: 0.15,
                child: _preview(b, blockSize, b.color, false)),
            child: _preview(b, blockSize, b.color, false),
          );
        }).toList(),
      ),
    );
  }

  Widget _preview(PuzzleBlock b, double s, Color color, bool isFeedback) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: b.shape
          .map((row) => Row(
                mainAxisSize: MainAxisSize.min,
                children: row
                    .map((cell) => Container(
                          width: s,
                          height: s,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: cell == 1 ? color : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: cell == 1
                                ? [
                                    BoxShadow(
                                        color: color.withOpacity(0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1)
                                  ]
                                : null,
                            border: cell == 1
                                ? Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1)
                                : null,
                          ),
                        ))
                    .toList(),
              ))
          .toList(),
    );
  }
}

// ── Level UP Dialog ──
class _LevelUpDialog extends StatefulWidget {
  final int level;
  final VoidCallback onContinue;
  final VoidCallback onMenu;
  const _LevelUpDialog(
      {required this.level, required this.onContinue, required this.onMenu});
  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog>
    with TickerProviderStateMixin {
  late AnimationController _cardCtrl;
  late Animation<double> _cardScale;
  late AnimationController _starMidCtrl;
  late Animation<double> _starMidScale;
  late AnimationController _starSideCtrl;
  late Animation<double> _starSideScale;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _btnCtrl;
  late Animation<Offset> _btnSlide;
  late Animation<double> _btnFade;
  late AnimationController _sparkleCtrl;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _cardScale = CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut);

    _starMidCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _starMidScale =
        CurvedAnimation(parent: _starMidCtrl, curve: Curves.elasticOut);

    _starSideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _starSideScale =
        CurvedAnimation(parent: _starSideCtrl, curve: Curves.elasticOut);

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _glowAnim = Tween(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _btnSlide =
        Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(
            CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut));
    _btnFade = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeIn);

    _sparkleCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();

    _cardCtrl.forward();
    Future.delayed(
        const Duration(milliseconds: 300), () { if (mounted) _starMidCtrl.forward(); });
    Future.delayed(
        const Duration(milliseconds: 550), () { if (mounted) _starSideCtrl.forward(); });
    Future.delayed(
        const Duration(milliseconds: 800), () { if (mounted) _btnCtrl.forward(); });
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _starMidCtrl.dispose();
    _starSideCtrl.dispose();
    _glowCtrl.dispose();
    _btnCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ScaleTransition(
        scale: _cardScale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 70, 24, 28),
              decoration: BoxDecoration(
                color: const Color(0xFFF5DFA0),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFF8B5E1A), width: 5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 4),
                  const BoxShadow(color: Colors.black38, blurRadius: 15),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, child) => Text(
                    'LEVEL UP!',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: const Color(0xFF5D3A1A),
                      shadows: [
                        Shadow(
                            color: Colors.orange.withOpacity(_glowAnim.value),
                            blurRadius: 20),
                        const Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(2, 3)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5E1A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF8B5E1A).withOpacity(0.3)),
                  ),
                  child: Column(children: [
                    Text('Level ${widget.level} Selesai! 🎊',
                        style: const TextStyle(
                            color: Color(0xFF5D3A1A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        'Level ${widget.level + 1} terbuka!\nTarget: ${targetSkorLevel(widget.level + 1)} poin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color:
                                const Color(0xFF5D3A1A).withOpacity(0.7),
                            fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _sparkleCtrl,
                  builder: (_, __) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final offset = ((_sparkleCtrl.value * 2 * math.pi) +
                            i * math.pi / 2.5);
                        final size = 6.0 + math.sin(offset) * 3;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child:
                              Icon(Icons.auto_awesome, color: Colors.amber, size: size),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SlideTransition(
                  position: _btnSlide,
                  child: FadeTransition(
                    opacity: _btnFade,
                    child: Column(children: [
                      _bigBtn('Continue', const Color(0xFFE67E22),
                          const Color(0xFFD35400), widget.onContinue),
                      const SizedBox(height: 12),
                      _bigBtn('Menu', const Color(0xFFCD853F),
                          const Color(0xFF8B5E1A), widget.onMenu),
                    ]),
                  ),
                ),
              ]),
            ),
            Positioned(
              top: -50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ScaleTransition(
                      scale: _starSideScale,
                      child: _starWidget(60, const Color(0xFFFFD700), -15)),
                  const SizedBox(width: 4),
                  ScaleTransition(
                      scale: _starMidScale,
                      child: _starWidget(80, const Color(0xFFFFD700), 0)),
                  const SizedBox(width: 4),
                  ScaleTransition(
                      scale: _starSideScale,
                      child: _starWidget(60, const Color(0xFFFFD700), -15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _starWidget(double size, Color color, double yOffset) {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, yOffset + math.sin(_sparkleCtrl.value * 2 * math.pi) * 4),
        child: Icon(Icons.star_rounded, color: color, size: size, shadows: [
          Shadow(color: Colors.orange.withOpacity(_glowAnim.value), blurRadius: 20),
          const Shadow(color: Colors.yellow, blurRadius: 8),
        ]),
      ),
    );
  }

  Widget _bigBtn(
      String label, Color colorTop, Color colorBot, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorTop, colorBot],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF5D3A1A), width: 3),
          boxShadow: [
            BoxShadow(
                color: colorBot.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Stack(children: [
          Positioned(
            top: 4, left: 12, right: 12,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
                    ])),
          ),
        ]),
      ),
    );
  }
}

// ── Custom painter untuk partikel ──
class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  _ParticlePainter(this.particles);
  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.life.clamp(0, 1))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, 5 * p.life, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// ==========================================
// HALAMAN SKOR
// ==========================================
class MyScorePage extends StatefulWidget {
  final int score;
  final int bestScore;
  final VoidCallback onReplay;
  const MyScorePage(
      {super.key, required this.score, required this.bestScore, required this.onReplay});
  @override
  State<MyScorePage> createState() => _MyScorePageState();
}

class _MyScorePageState extends State<MyScorePage> with TickerProviderStateMixin {
  late AnimationController _cardCtrl;
  late AnimationController _numberCtrl;
  late Animation<double> _cardAnim;
  late Animation<int> _numberAnim;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cardAnim = CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut);
    _numberCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _numberAnim = IntTween(begin: 0, end: widget.score)
        .animate(CurvedAnimation(parent: _numberCtrl, curve: Curves.easeOut));
    _cardCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () => _numberCtrl.forward());
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _numberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.score > 0 && widget.score >= widget.bestScore;
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
            image: AssetImage('assets/images/background.png.jpg'),
            fit: BoxFit.cover),
      ),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: ScaleTransition(
            scale: _cardAnim,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE8A456), Color(0xFFB05A1A)],
                ),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFF633316), width: 5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5),
                  const BoxShadow(color: Colors.black54, blurRadius: 20),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (isNew) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.yellow[700],
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.stars, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('NEW BEST!',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('GAME OVER',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 6)])),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _numberAnim,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(children: [
                      const Text('SCORE',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 14, letterSpacing: 3)),
                      const SizedBox(height: 4),
                      Text(_numberAnim.value.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Colors.black38, blurRadius: 8)
                              ])),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.emoji_events, color: Colors.yellow, size: 20),
                    const SizedBox(width: 8),
                    Text('BEST: ${widget.bestScore}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 30),
                Row(children: [
                  Expanded(child: _actionBtn('REPLAY', Icons.replay_rounded, Colors.orange, widget.onReplay)),
                  const SizedBox(width: 12),
                  Expanded(child: _actionBtn(
                      'HOME',
                      Icons.home_rounded,
                      const Color(0xFF7A3A0A),
                      () => Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => const LevelGameApp())))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      ),
    );
  }
}

// ==========================================
// HALAMAN PAUSE
// ==========================================
class PausePage extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onReplay;
  final VoidCallback onHome;
  const PausePage(
      {super.key, required this.onResume, required this.onReplay, required this.onHome});
  @override
  State<PausePage> createState() => _PausePageState();
}

class _PausePageState extends State<PausePage> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
            image: AssetImage('assets/images/background.png.jpg'),
            fit: BoxFit.cover),
      ),
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: ScaleTransition(
            scale: _anim,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8D5524), Color(0xFF4A2511)],
                ),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: Colors.orange, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: 3),
                  const BoxShadow(color: Colors.black54, blurRadius: 15),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.pause_circle_filled, color: Colors.orange, size: 50),
                const SizedBox(height: 8),
                const Text('PAUSED',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 6)])),
                const SizedBox(height: 30),
                _pauseBtn('RESUME', Icons.play_arrow_rounded, Colors.green, widget.onResume),
                const SizedBox(height: 12),
                _pauseBtn('REPLAY', Icons.replay_rounded, Colors.orange, widget.onReplay),
                const SizedBox(height: 12),
                _pauseBtn(
                    'HOME',
                    Icons.home_rounded,
                    const Color(0xFF7A3A0A),
                    () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LevelGameApp()))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseBtn(String label, IconData icon, Color color, VoidCallback tap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          tap();
        },
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(label,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: color.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}