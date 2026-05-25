import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
// SHOW SETTINGS POPUP - dipanggil dari main screen
// ─────────────────────────────────────────────
void showPengaturanPopup(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Settings',
    barrierColor: Colors.black.withOpacity(0.7),
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (_, __, ___) => const _PengaturanPopupContent(),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.5, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
}

class _PengaturanPopupContent extends StatefulWidget {
  const _PengaturanPopupContent();

  @override
  State<_PengaturanPopupContent> createState() =>
      _PengaturanPopupContentState();
}

class _PengaturanPopupContentState extends State<_PengaturanPopupContent>
    with TickerProviderStateMixin {
  String selectedDifficulty = "Medium";
  double musicVolume = 0.5;
  bool _isLoading = true;
  bool _isSaving = false;

  final _supabase = Supabase.instance.client;

  late AnimationController _entryController;
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _sparkCtrl;
  late Animation<double> _entryAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _entryAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.elasticOut);
    _entryController.forward();

    _glowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glowAnim =
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sparkCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    _loadSettings();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data != null) {
        setState(() {
          selectedDifficulty = data['difficulty'] ?? 'Medium';
          musicVolume = (data['music_volume'] ?? 0.5).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('user_settings').upsert({
        'user_id': userId,
        'difficulty': selectedDifficulty,
        'music_volume': musicVolume,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      if (mounted) _showSavedPopup();
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        _showErrorPopup();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSavedPopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (ctx, anim, _, __) {
        final curve =
            CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 36),
                  padding:
                      const EdgeInsets.fromLTRB(24, 28, 24, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                        color: const Color(0xFF5D3A1A), width: 4),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFFD700)
                              .withOpacity(0.3),
                          blurRadius: 35,
                          spreadRadius: 4),
                      const BoxShadow(
                          color: Colors.black45,
                          blurRadius: 20,
                          offset: Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated sparkles
                      AnimatedBuilder(
                        animation: _sparkCtrl,
                        builder: (_, __) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final s = 14.0 +
                                math.sin(_sparkCtrl.value *
                                            2 *
                                            math.pi +
                                        i * math.pi / 2.5) *
                                    6;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3),
                              child: Icon(Icons.auto_awesome,
                                  color: Colors.amber, size: s),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF4CAF50), size: 60),
                      const SizedBox(height: 12),
                      const Text(
                        'Berhasil Disimpan!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A2511)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC68E5C)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF8B4513)
                                  .withOpacity(0.25)),
                        ),
                        child: Column(children: [
                          _popupRow(
                              "⚔️ Difficulty", selectedDifficulty),
                          const SizedBox(height: 6),
                          _popupRow("🎵 Volume",
                              "${(musicVolume * 100).toInt()}%"),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFFFF7043),
                              Color(0xFFBF360C)
                            ]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0xFFCD5C45)
                                      .withOpacity(0.45),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Lanjut Main! 🎮',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showErrorPopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (ctx, anim, _, __) {
        return ScaleTransition(
          scale: CurvedAnimation(
              parent: anim, curve: Curves.easeOutBack),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 44),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: const Color(0xFFCD5C45), width: 4),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black38, blurRadius: 18)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("❌",
                        style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 10),
                    const Text(
                      'Gagal Menyimpan',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4E342E)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Periksa koneksi internet kamu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF8B4513), fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCD5C45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('OK',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _popupRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B4513),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(8)),
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final btnW = (sw * 0.9 - 40 - 36 - 20) / 3;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: sw * 0.9,
          constraints: BoxConstraints(maxHeight: sh * 0.88),
          child: _isLoading
              ? Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFFD700), strokeWidth: 3),
                  ),
                )
              : ScaleTransition(
                  scale: _entryAnim,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC68E5C),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                              color: const Color(0xFF5D3A1A), width: 6),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.45),
                                blurRadius: 20,
                                offset: const Offset(0, 10)),
                            BoxShadow(
                                color: const Color(0xFFFFD700)
                                    .withOpacity(0.1),
                                blurRadius: 28,
                                spreadRadius: 2),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // HEADER
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                  vertical: sh * 0.022),
                              decoration: const BoxDecoration(
                                color: Color(0xFFAD6F3B),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                              ),
                              child: AnimatedBuilder(
                                animation: _glowAnim,
                                builder: (_, __) => Column(
                                  children: [
                                    Text("⚙️",
                                        style: TextStyle(
                                            fontSize: sw * 0.08,
                                            shadows: [
                                              Shadow(
                                                  color: const Color(0xFFFFD700)
                                                      .withOpacity(
                                                          _glowAnim.value *
                                                              0.8),
                                                  blurRadius: 18),
                                            ])),
                                    SizedBox(height: sh * 0.006),
                                    Text(
                                      "PUZZLE SETTINGS",
                                      style: TextStyle(
                                        fontSize: sw * 0.055,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFFFF8E7),
                                        letterSpacing: 1.5,
                                        shadows: [
                                          Shadow(
                                              color: const Color(0xFFFFD700)
                                                  .withOpacity(
                                                      _glowAnim.value * 0.4),
                                              blurRadius: 16),
                                          const Shadow(
                                              color: Colors.black38,
                                              blurRadius: 4,
                                              offset: Offset(0, 2)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // BODY
                            SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                  sw * 0.04, sh * 0.022, sw * 0.04, sh * 0.026),
                              child: Column(children: [
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                      vertical: sh * 0.022,
                                      horizontal: sw * 0.035),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1CC),
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4)),
                                      const BoxShadow(
                                          color: Colors.white38,
                                          blurRadius: 4,
                                          offset: Offset(0, -2)),
                                    ],
                                  ),
                                  child: Column(children: [
                                    _sectionLabel("⚔️  Difficulty", sw),
                                    SizedBox(height: sh * 0.014),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _difficultyBtn("Easy", "🟢",
                                            const Color(0xFF4CAF50), btnW, sh),
                                        SizedBox(width: sw * 0.025),
                                        _difficultyBtn("Medium", "🟡",
                                            const Color(0xFFFFC107), btnW, sh),
                                        SizedBox(width: sw * 0.025),
                                        _difficultyBtn("Hard", "🔴",
                                            const Color(0xFFF44336), btnW, sh),
                                      ],
                                    ),
                                    SizedBox(height: sh * 0.008),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: Text(
                                        selectedDifficulty == "Easy"
                                            ? "Santai & menyenangkan 😊"
                                            : selectedDifficulty == "Medium"
                                                ? "Seimbang & menantang 💪"
                                                : "Ekstrem! Siap ditantang? 🔥",
                                        key: ValueKey(selectedDifficulty),
                                        style: TextStyle(
                                            color: const Color(0xFFAA7744),
                                            fontSize: sw * 0.03,
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                    SizedBox(height: sh * 0.02),
                                    const Divider(
                                        color: Color(0xFFD7CCC8),
                                        thickness: 1.5,
                                        indent: 8,
                                        endIndent: 8),
                                    SizedBox(height: sh * 0.018),
                                    _sectionLabel("🎵  Music Volume", sw),
                                    SizedBox(height: sh * 0.012),
                                    Row(children: [
                                      const Icon(Icons.volume_mute,
                                          color: Color(0xFF8B4513), size: 20),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context)
                                              .copyWith(
                                            trackHeight: 8,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                    enabledThumbRadius: 12),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                    overlayRadius: 22),
                                            thumbColor:
                                                const Color(0xFFCD5C45),
                                            activeTrackColor:
                                                const Color(0xFFCD5C45),
                                            inactiveTrackColor:
                                                const Color(0xFF8B4513)
                                                    .withOpacity(0.2),
                                            overlayColor:
                                                const Color(0xFFCD5C45)
                                                    .withOpacity(0.15),
                                          ),
                                          child: Slider(
                                            value: musicVolume,
                                            onChanged: (v) {
                                              HapticFeedback.selectionClick();
                                              setState(
                                                  () => musicVolume = v);
                                            },
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.volume_up,
                                          color: Color(0xFF8B4513), size: 20),
                                    ]),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: musicVolume == 0
                                            ? Colors.grey.withOpacity(0.12)
                                            : musicVolume < 0.4
                                                ? const Color(0xFF4CAF50)
                                                    .withOpacity(0.12)
                                                : musicVolume < 0.75
                                                    ? const Color(0xFFFFC107)
                                                        .withOpacity(0.15)
                                                    : const Color(0xFFCD5C45)
                                                        .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              musicVolume == 0
                                                  ? "🔇"
                                                  : musicVolume < 0.4
                                                      ? "🔈"
                                                      : musicVolume < 0.75
                                                          ? "🔉"
                                                          : "🔊",
                                              style: TextStyle(
                                                  fontSize: sw * 0.042),
                                            ),
                                            SizedBox(width: sw * 0.02),
                                            Text(
                                              "${(musicVolume * 100).toInt()}%",
                                              style: TextStyle(
                                                  color:
                                                      const Color(0xFF8B4513),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: sw * 0.038),
                                            ),
                                          ]),
                                    ),
                                  ]),
                                ),
                                SizedBox(height: sh * 0.022),

                                // TOMBOL SIMPAN
                                AnimatedBuilder(
                                  animation: _glowAnim,
                                  builder: (_, __) => ScaleTransition(
                                    scale: _isSaving
                                        ? const AlwaysStoppedAnimation(1.0)
                                        : _pulseAnim,
                                    child: GestureDetector(
                                      onTap:
                                          _isSaving ? null : _saveSettings,
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                            vertical: sh * 0.018),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: _isSaving
                                                ? [
                                                    const Color(0xFF8B4513),
                                                    const Color(0xFF6D3410)
                                                  ]
                                                : [
                                                    const Color(0xFFFF7043),
                                                    const Color(0xFFBF360C)
                                                  ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          border: Border.all(
                                              color: Colors.white.withOpacity(
                                                  _glowAnim.value * 0.55),
                                              width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFCD5C45)
                                                  .withOpacity(_isSaving
                                                      ? 0.1
                                                      : _glowAnim.value * 0.5),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                            const BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 6,
                                                offset: Offset(0, 4)),
                                          ],
                                        ),
                                        child: Center(
                                          child: _isSaving
                                              ? Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      height: sw * 0.048,
                                                      width: sw * 0.048,
                                                      child:
                                                          const CircularProgressIndicator(
                                                              color:
                                                                  Colors.white,
                                                              strokeWidth: 2.5),
                                                    ),
                                                    SizedBox(width: sw * 0.025),
                                                    Text("Menyimpan...",
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize:
                                                                sw * 0.038)),
                                                  ])
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.save_rounded,
                                                        color: Colors.white,
                                                        size: sw * 0.052),
                                                    SizedBox(width: sw * 0.022),
                                                    Text(
                                                        "SIMPAN PENGATURAN",
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: sw * 0.04,
                                                            letterSpacing:
                                                                1.0)),
                                                  ]),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),

                      // Close button top-right
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
      ),
    );
  }

  Widget _difficultyBtn(
      String label, String emoji, Color accentColor, double w, double sh) {
    bool isSelected = selectedDifficulty == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => selectedDifficulty = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: w,
        padding: EdgeInsets.symmetric(vertical: sh * 0.013),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : const Color(0xFF8B4513),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accentColor.withOpacity(0.5)
                  : Colors.black.withOpacity(0.28),
              blurRadius: isSelected ? 12 : 3,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(fontSize: isSelected ? 22 : 18),
            child: Text(emoji),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text, double sw) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: sw * 0.06, vertical: sw * 0.022),
      decoration: BoxDecoration(
        color: const Color(0xFF8B4513),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 3))
        ],
      ),
      child: Text(text,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: sw * 0.038,
              letterSpacing: 0.4)),
    );
  }
}