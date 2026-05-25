import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pjbl_yallah/settings.dart';

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────
class CollectionItem {
  final String id;
  final String name;
  final String imageUrl;
  final String imageAsset; // ← TAMBAHAN: support asset lokal
  final String origin;
  final String description;
  final int rarity;

  CollectionItem({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.imageAsset = '',
    this.origin = '',
    this.description = '',
    this.rarity = 1,
  });

  factory CollectionItem.fromMap(Map<String, dynamic> map) {
    final item = map['store_items'] as Map<String, dynamic>? ?? map;
    return CollectionItem(
      id: item['id'].toString(),
      name: item['name'] ?? '',
      imageUrl: item['image_url'] ?? '',
      imageAsset: item['image_asset'] ?? '',
      origin: item['origin'] ?? '',
      description: item['description'] ?? '',
      rarity: item['rarity'] ?? 1,
    );
  }

  // ← Buat dari StoreItem (dipakai saat beli di store)
  factory CollectionItem.fromStoreItem(Map<String, dynamic> storeMap) {
    return CollectionItem(
      id: storeMap['id']?.toString() ?? '',
      name: storeMap['name'] ?? '',
      imageUrl: storeMap['imageUrl'] ?? '',
      imageAsset: storeMap['imageAsset'] ?? '',
      origin: storeMap['origin'] ?? '',
      description: storeMap['description'] ?? '',
      rarity: storeMap['rarity'] ?? 1,
    );
  }
}

// ─────────────────────────────────────────────
// DATA KOLEKSI AWAL (pakai asset lokal, sama dengan store)
// ─────────────────────────────────────────────
final List<CollectionItem> _dummyCollection = [
  CollectionItem(id: 'local_3', name: 'Parang', imageAsset: 'assets/images/parang.png.jpg',
    origin: 'Solo, Jawa Tengah', description: 'Salah satu motif batik tertua dari Solo. Diagonal kuat melambangkan keberanian dan semangat.', rarity: 3),
  CollectionItem(id: 'local_2', name: 'Kawung', imageAsset: 'assets/images/kawung.png.jpg',
    origin: 'Yogyakarta, Jawa Tengah', description: 'Motif geometris buah kawung, dulu eksklusif keluarga kerajaan.', rarity: 4),
  CollectionItem(id: 'local_6', name: 'Truntum', imageAsset: 'assets/images/truntum.jpg',
    origin: 'Surakarta, Jawa Tengah', description: 'Motif bunga bintang simbol cinta yang bersemi kembali.', rarity: 2),
];

// Semua item hardcoded dari store (untuk ditampilkan di koleksi setelah dibeli)
final List<CollectionItem> _hardcodedForCollection = [
  CollectionItem(id: 'local_1', name: 'Taman Arum', imageAsset: 'assets/images/batik3.png.jpg', origin: 'Cirebon, Jawa Barat', description: 'Motif sulur melingkar khas Cirebon dengan warna cerah orange dan biru.', rarity: 2),
  CollectionItem(id: 'local_2', name: 'Kawung', imageAsset: 'assets/images/kawung.png.jpg', origin: 'Yogyakarta, Jawa Tengah', description: 'Motif geometris buah kawung, dulu eksklusif keluarga kerajaan.', rarity: 4),
  CollectionItem(id: 'local_3', name: 'Parang', imageAsset: 'assets/images/parang.png.jpg', origin: 'Solo, Jawa Tengah', description: 'Salah satu motif batik tertua dari Solo. Melambangkan keberanian.', rarity: 3),
  CollectionItem(id: 'local_4', name: 'Ceplok', imageAsset: 'assets/images/ceplok.png.jpg', origin: 'Jawa Tengah', description: 'Motif geometris simetris berbentuk lingkaran dan bintang.', rarity: 1),
  CollectionItem(id: 'local_5', name: 'Sidomukti', imageAsset: 'assets/images/sidomukti.png.jpg', origin: 'Solo, Jawa Tengah', description: 'Motif harapan akan kemuliaan dan kemakmuran.', rarity: 3),
  CollectionItem(id: 'local_6', name: 'Truntum', imageAsset: 'assets/images/truntum.jpg', origin: 'Surakarta, Jawa Tengah', description: 'Motif bunga bintang simbol cinta yang bersemi kembali.', rarity: 2),
  CollectionItem(id: 'local_7', name: 'Pekalongan', imageAsset: 'assets/images/batik4.png.jpg', origin: 'Pekalongan, Jawa Tengah', description: 'Batik pesisir khas Pekalongan dengan warna cerah.', rarity: 2),
  CollectionItem(id: 'local_8', name: 'Singabarong', imageAsset: 'assets/images/singabarong.jpg', origin: 'Cirebon, Jawa Barat', description: 'Motif kepala singa mitos dari Cirebon.', rarity: 4),
  CollectionItem(id: 'local_9', name: 'Sogan', imageAsset: 'assets/images/sogan.png.jpg', origin: 'Solo, Jawa Tengah', description: 'Batik warna coklat soga alami. Klasik dan elegan.', rarity: 1),
  CollectionItem(id: 'local_10', name: 'Tambal', imageAsset: 'assets/images/tambal1.jpg', origin: 'Jawa Tengah', description: 'Motif tambal penuh makna spiritual.', rarity: 2),
];

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────
// ── PERSISTENT LOCAL COLLECTION ──
final Set<String> localOwnedItems = {};

Future<void> loadLocalOwned() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getStringList('local_owned') ?? [];
  localOwnedItems.addAll(saved);
}

Future<void> saveLocalOwned() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList('local_owned', localOwnedItems.toList());
}

class KoleksiService {
  final _supabase = Supabase.instance.client;

  Future<List<CollectionItem>> fetchUserCollection() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User belum login.');
    try {
      final response = await _supabase
          .from('user_collections')
          .select('item_id, store_items(id, name, image_url, image_asset, origin, description, rarity)')
          .eq('user_id', userId)
          .order('purchased_at', ascending: false);
      final fromDB = (response as List).map((e) => CollectionItem.fromMap(e)).toList();
      // Tambahkan item lokal yang sudah dibeli
      final localBought = _hardcodedForCollection
          .where((e) => localOwnedItems.contains(e.id))
          .toList();
      if (fromDB.isNotEmpty || localBought.isNotEmpty) {
        final combined = [...fromDB];
        for (final l in localBought) {
          if (!combined.any((c) => c.id == l.id)) combined.add(l);
        }
        return combined;
      }
      return _dummyCollection;
    } catch (_) {
      return _dummyCollection;
    }
  }
}

// ─────────────────────────────────────────────
// RARITY CONFIG
// ─────────────────────────────────────────────
class RarityConfig {
  static Color borderColor(int rarity) {
    switch (rarity) {
      case 4: return const Color(0xFFFFD700);
      case 3: return const Color(0xFFB44FD8);
      case 2: return const Color(0xFF4FA8D8);
      default: return const Color(0xFF9E9E9E);
    }
  }
  static String label(int rarity) {
    switch (rarity) {
      case 4: return '✦ LEGENDARY';
      case 3: return '◆ EPIC';
      case 2: return '● RARE';
      default: return '· COMMON';
    }
  }
  static Color labelColor(int rarity) {
    switch (rarity) {
      case 4: return const Color(0xFFFFD700);
      case 3: return const Color(0xFFE040FB);
      case 2: return const Color(0xFF40C4FF);
      default: return const Color(0xFFBDBDBD);
    }
  }
}

// ─────────────────────────────────────────────
// PARTICLES
// ─────────────────────────────────────────────
class _Particle {
  double x, y, vx, vy, size, opacity;
  Color color;
  _Particle({required this.x, required this.y, required this.vx,
    required this.vy, required this.size, required this.opacity, required this.color});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        Paint()..color = p.color.withOpacity(p.opacity),
      );
    }
  }
  @override bool shouldRepaint(covariant CustomPainter _) => true;
}

class _BatikPatternPainter extends CustomPainter {
  final Color color; final double opacity;
  _BatikPatternPainter({required this.color, required this.opacity});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2;
    const step = 40.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        canvas.drawCircle(Offset(x, y), 10, paint);
        canvas.drawCircle(Offset(x + step / 2, y + step / 2), 10, paint);
        canvas.drawArc(Rect.fromCenter(center: Offset(x, y), width: 20, height: 28), 0, pi, false, paint);
        canvas.drawArc(Rect.fromCenter(center: Offset(x, y), width: 20, height: 28), pi, pi, false, paint);
      }
    }
    paint.strokeWidth = 0.6;
    paint.color = color.withOpacity(opacity * 0.4);
    for (double i = -size.height; i < size.width + size.height; i += 28) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────
// HALAMAN KOLEKSI
// ─────────────────────────────────────────────
class BatikCollectionPage extends StatefulWidget {
  final CollectionItem? newlyPurchased; // ← item yang baru dibeli (opsional)
  const BatikCollectionPage({super.key, this.newlyPurchased});

  @override
  State<BatikCollectionPage> createState() => _BatikCollectionPageState();
}

class _BatikCollectionPageState extends State<BatikCollectionPage>
    with TickerProviderStateMixin {
  final KoleksiService _service = KoleksiService();
  late Future<List<CollectionItem>> _collectionFuture;

  late AnimationController _shimmerController;
  late AnimationController _particleController;
  late AnimationController _titleController;
  late AnimationController _glowController;
  late Animation<double> _shimmerAnim;
  late Animation<double> _titleAnim;
  late Animation<double> _glowAnim;

  final List<_Particle> _particles = [];
  final Random _rng = Random();
  bool _marketingShown = false;

  @override
  void initState() {
    super.initState();
    // Tunggu loadLocalOwned selesai DULU baru fetch koleksi
    _collectionFuture = loadLocalOwned().then((_) async {
      final items = await _service.fetchUserCollection();
      // Pastikan item baru langsung muncul tanpa tunggu DB/storage
      if (widget.newlyPurchased != null &&
          !items.any((e) => e.id == widget.newlyPurchased!.id)) {
        items.insert(0, widget.newlyPurchased!);
      }
      return items;
    });
    _initAnimations();
    _initParticles();

    // Kalau ada item baru dibeli → tampilkan popup reveal dulu
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (widget.newlyPurchased != null) {
        _showNewItemPopup(widget.newlyPurchased!);
      } else if (!_marketingShown) {
        _marketingShown = true;
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _showMarketingPopup();
        });
      }
    });
  }

  void _initAnimations() {
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5)
        .animate(CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut));

    _particleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(_updateParticles)..repeat();

    _titleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _titleAnim = CurvedAnimation(parent: _titleController, curve: Curves.elasticOut);
    _titleController.forward();

    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
  }

  void _initParticles() {
    for (int i = 0; i < 18; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(), y: _rng.nextDouble(),
        vx: (_rng.nextDouble() - 0.5) * 0.002,
        vy: -_rng.nextDouble() * 0.003 - 0.001,
        size: _rng.nextDouble() * 3 + 1,
        opacity: _rng.nextDouble() * 0.5 + 0.2,
        color: [const Color(0xFFFFD700), const Color(0xFFFF9800),
          const Color(0xFFF5E1A4), const Color(0xFFE040FB)][_rng.nextInt(4)],
      ));
    }
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.x += p.vx; p.y += p.vy;
      if (p.y < -0.05) { p.y = 1.05; p.x = _rng.nextDouble(); }
      if (p.x < 0 || p.x > 1) p.vx = -p.vx;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _particleController.dispose();
    _titleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ── POPUP ITEM BARU (setelah beli) ──
  void _showNewItemPopup(CollectionItem item) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (ctx, anim, _, __) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim,
            child: Center(child: _NewItemPopup(item: item, onClose: () {
              Navigator.pop(ctx);
            })),
          ),
        );
      },
    );
  }

  void _showMarketingPopup() {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (ctx, anim, _, __) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: FadeTransition(
            opacity: anim,
            child: Center(child: _MarketingPopupWidget(
              onClose: () => Navigator.pop(ctx),
              onGoToStore: () { Navigator.pop(ctx); Navigator.pop(context); },
            )),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/background.png.jpg', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.35))),
          Positioned.fill(child: CustomPaint(painter: _BatikPatternPainter(color: const Color(0xFFFFD700), opacity: 0.06))),
          Positioned.fill(child: CustomPaint(painter: _ParticlePainter(_particles))),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: FutureBuilder<List<CollectionItem>>(
                    future: _collectionFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();
                      if (snapshot.hasError) return _buildError(snapshot.error.toString());
                      return _buildCollectionBoard(snapshot.data!);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _headerBtn(Icons.undo_rounded, () { HapticFeedback.lightImpact(); Navigator.pop(context); }),
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7B3F00), Color(0xFF4B230B)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color.lerp(const Color(0xFFFFD700), const Color(0xFFFF9800), _glowAnim.value)!,
                  width: 2,
                ),
                boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(_glowAnim.value * 0.5), blurRadius: 12)],
              ),
              child: const Row(children: [
                Text('📜', style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Text('KOLEKSIKU', style: TextStyle(color: Color(0xFFF5E1A4), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
              ]),
            ),
          ),
          // SESUDAH:
_headerBtn(Icons.settings_rounded, () => showPengaturanPopup(context)),
        ],
      ),
    );
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF4B230B), shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Icon(icon, color: const Color(0xFFF5E1A4), size: 24),
    ),
  );

  Widget _buildLoading() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 3),
    const SizedBox(height: 16),
    Text('Memuat koleksimu...', style: TextStyle(color: const Color(0xFFF5E1A4).withOpacity(0.8), fontSize: 14)),
  ]));

  Widget _buildError(String err) => Center(child: Container(
    margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.red.withOpacity(0.3))),
    child: Text('Gagal memuat:\n$err', textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
  ));

  Widget _buildCollectionBoard(List<CollectionItem> items) {
    final totalSlots = _calcTotalSlots(items.length);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF5C2A0D), Color(0xFF3B1A07)]),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFF9E5E31), width: 6),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.15), blurRadius: 30, spreadRadius: 4),
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _BatikPatternPainter(color: const Color(0xFFFFD700), opacity: 0.04))),
          Column(children: [
            const SizedBox(height: 20),
            ScaleTransition(scale: _titleAnim, child: _buildTitle()),
            const SizedBox(height: 8),
            _buildStatsBar(items),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.82),
                  itemCount: totalSlots,
                  itemBuilder: (ctx, i) => i < items.length
                      ? _ItemCard(item: items[i], index: i, onTap: () => _showDetailPopup(items[i]))
                      : _LockedSlot(index: i),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ]),
      ),
    );
  }

  Widget _buildTitle() => AnimatedBuilder(
    animation: _glowAnim,
    builder: (_, __) => Column(children: [
      ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: const [Color(0xFFFFD700), Color(0xFFFFF8DC), Color(0xFFFFD700)],
          stops: [(_shimmerAnim.value - 1).clamp(0.0, 1.0), _shimmerAnim.value.clamp(0.0, 1.0), (_shimmerAnim.value + 1).clamp(0.0, 1.0)],
        ).createShader(bounds),
        child: AnimatedBuilder(animation: _shimmerAnim, builder: (_, child) => child!,
          child: const Text('BATIK\nCOLLECTION', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3, height: 1.05))),
      ),
      const SizedBox(height: 4),
      Container(height: 3, width: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent,
            const Color(0xFFFFD700).withOpacity(0.8 + _glowAnim.value * 0.2), Colors.transparent]),
          borderRadius: BorderRadius.circular(2))),
    ]),
  );

  Widget _buildStatsBar(List<CollectionItem> items) {
    final legendary = items.where((e) => e.rarity == 4).length;
    final epic = items.where((e) => e.rarity == 3).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _statChip('📦', '${items.length}', 'Total'),
        _vertDiv(),
        _statChip('✦', '$legendary', 'Legendary'),
        _vertDiv(),
        _statChip('◆', '$epic', 'Epic'),
      ]),
    );
  }

  Widget _statChip(String emoji, String value, String label) => Column(mainAxisSize: MainAxisSize.min, children: [
    Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 4),
      Text(value, style: const TextStyle(color: Color(0xFFF5E1A4), fontWeight: FontWeight.w900, fontSize: 16)),
    ]),
    Text(label, style: TextStyle(color: const Color(0xFFF5E1A4).withOpacity(0.55), fontSize: 9, letterSpacing: 0.5)),
  ]);

  Widget _vertDiv() => Container(height: 28, width: 1, color: const Color(0xFFFFD700).withOpacity(0.2));

  int _calcTotalSlots(int owned) {
    const min = 6;
    final total = owned < min ? min : owned + 2;
    return total % 2 == 0 ? total : total + 1;
  }

  void _showDetailPopup(CollectionItem item) {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true, barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.78),
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (ctx, anim, _, __) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: FadeTransition(opacity: anim,
          child: Center(child: _DetailPopupWidget(item: item, onClose: () => Navigator.pop(ctx)))),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HELPER: tampilkan gambar (URL / asset lokal)
// ─────────────────────────────────────────────
Widget _buildCollectionImage(CollectionItem item, {BoxFit fit = BoxFit.cover}) {
  if (item.imageUrl.isNotEmpty) {
    return Image.network(item.imageUrl, fit: fit,
      errorBuilder: (_, __, ___) => _imgPlaceholder(),
      loadingBuilder: (_, child, prog) => prog == null ? child : _imgLoading());
  } else if (item.imageAsset.isNotEmpty) {
    return Image.asset(item.imageAsset, fit: fit,
      errorBuilder: (_, __, ___) => _imgPlaceholder());
  }
  return _imgPlaceholder();
}

Widget _imgPlaceholder() => Container(color: const Color(0xFF2D1205),
  child: const Icon(Icons.broken_image_rounded, color: Color(0xFF8B4513), size: 32));
Widget _imgLoading() => Container(color: const Color(0xFF2D1205),
  child: const Center(child: SizedBox(width: 20, height: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)))));

// ─────────────────────────────────────────────
// NEW ITEM POPUP (setelah beli di store)
// ─────────────────────────────────────────────
class _NewItemPopup extends StatefulWidget {
  final CollectionItem item;
  final VoidCallback onClose;
  const _NewItemPopup({required this.item, required this.onClose});

  @override
  State<_NewItemPopup> createState() => _NewItemPopupState();
}

class _NewItemPopupState extends State<_NewItemPopup> with TickerProviderStateMixin {
  late AnimationController _glow;
  late AnimationController _float;
  late Animation<double> _glowAnim;
  late Animation<double> _floatAnim;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glow, curve: Curves.easeInOut);
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut));

    // Auto reveal setelah 800ms
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  void dispose() { _glow.dispose(); _float.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final borderColor = RarityConfig.borderColor(widget.item.rarity);
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF5C2A0D), Color(0xFF1E0D03)]),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(color: borderColor.withOpacity(0.5), blurRadius: 40, spreadRadius: 6),
            const BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 14)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(33),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Sparkle header
              AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) => Text('✨', style: TextStyle(fontSize: 40 + _glowAnim.value * 8)),
              ),
              const SizedBox(height: 8),
              Text('ITEM BARU DIDAPAT!', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: borderColor, letterSpacing: 2)),
              const SizedBox(height: 16),

              // Gambar item dengan animasi reveal
              AnimatedOpacity(
                opacity: _revealed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                child: AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _floatAnim.value), child: child),
                  child: AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, child) => Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 3),
                        boxShadow: [BoxShadow(color: borderColor.withOpacity(0.4 + _glowAnim.value * 0.4), blurRadius: 24, spreadRadius: 4)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(21),
                        child: _buildCollectionImage(widget.item),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              // Rarity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1.5)),
                child: Text(RarityConfig.label(widget.item.rarity),
                  style: TextStyle(color: borderColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
              ),
              const SizedBox(height: 8),
              Text(widget.item.name.toUpperCase(),
                style: const TextStyle(color: Color(0xFFF5E1A4), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              if (widget.item.origin.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFFF9800), size: 13),
                  const SizedBox(width: 4),
                  Text(widget.item.origin, style: const TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
                ]),
              ],
              if (widget.item.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor.withOpacity(0.3))),
                  child: Text(widget.item.description, textAlign: TextAlign.center,
                    style: TextStyle(color: const Color(0xFFF5E1A4).withOpacity(0.85), fontSize: 12, height: 1.5)),
                ),
              ],
              const SizedBox(height: 20),
              // Tombol lihat koleksi
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); widget.onClose(); },
                child: AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [borderColor, const Color(0xFF4B230B)]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: borderColor.withOpacity(0.3 + _glowAnim.value * 0.3), blurRadius: 16)]),
                    child: const Center(child: Text('🎴 Lihat Koleksiku!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ITEM CARD — FIX: pakai TickerProviderStateMixin
// ─────────────────────────────────────────────
class _ItemCard extends StatefulWidget {
  final CollectionItem item;
  final int index;
  final VoidCallback onTap;
  const _ItemCard({required this.item, required this.index, required this.onTap});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> with TickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _scale;
  late Animation<double> _entry;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));

    _entryCtrl = AnimationController(
      vsync: this, duration: Duration(milliseconds: 400 + widget.index * 90));
    _entry = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack));
    _entryCtrl.forward();
  }

  @override
  void dispose() { _pressCtrl.dispose(); _entryCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rarity = widget.item.rarity;
    final borderColor = RarityConfig.borderColor(rarity);
    final isLegendary = rarity == 4;

    return ScaleTransition(
      scale: _entry,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: isLegendary ? 3 : 2),
              boxShadow: [
                BoxShadow(color: borderColor.withOpacity(isLegendary ? 0.5 : 0.2), blurRadius: isLegendary ? 14 : 6, spreadRadius: isLegendary ? 2 : 0),
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(children: [
                Expanded(
                  child: Stack(fit: StackFit.expand, children: [
                    // ← PAKAI HELPER (support URL + asset)
                    _buildCollectionImage(widget.item),
                    // Gradient bawah
                    Positioned(bottom: 0, left: 0, right: 0,
                      child: Container(height: 50,
                        decoration: BoxDecoration(gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.7), Colors.transparent])))),
                    // Rarity badge
                    Positioned(top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(8)),
                        child: Text(RarityConfig.label(rarity),
                          style: TextStyle(color: RarityConfig.labelColor(rarity), fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)))),
                    // Tap hint
                    Positioned(bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                        child: const Icon(Icons.zoom_in_rounded, size: 12, color: Color(0xFF4B230B)))),
                    if (isLegendary)
                      Positioned.fill(child: Container(
                        decoration: BoxDecoration(gradient: RadialGradient(
                          colors: [const Color(0xFFFFD700).withOpacity(0.08), Colors.transparent])))),
                  ]),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF3B1A07),
                      Color.lerp(const Color(0xFF3B1A07), borderColor, 0.15)!])),
                  child: Text(widget.item.name.toUpperCase(),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFF5E1A4), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOCKED SLOT
// ─────────────────────────────────────────────
class _LockedSlot extends StatefulWidget {
  final int index;
  const _LockedSlot({required this.index});
  @override State<_LockedSlot> createState() => _LockedSlotState();
}

class _LockedSlotState extends State<_LockedSlot> with SingleTickerProviderStateMixin {
  late AnimationController _breathe;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _breathe, curve: Curves.easeInOut);
  }
  @override void dispose() { _breathe.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D1205).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF9E5E31).withOpacity(0.3 + _anim.value * 0.2), width: 2)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_rounded, color: const Color(0xFF9E5E31).withOpacity(0.4 + _anim.value * 0.2), size: 30),
        const SizedBox(height: 8),
        Text('? ? ?', style: TextStyle(
          color: const Color(0xFF9E5E31).withOpacity(0.35 + _anim.value * 0.15),
          fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────
// DETAIL POPUP
// ─────────────────────────────────────────────
class _DetailPopupWidget extends StatelessWidget {
  final CollectionItem item;
  final VoidCallback onClose;
  const _DetailPopupWidget({required this.item, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final borderColor = RarityConfig.borderColor(item.rarity);
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF5C2A0D), Color(0xFF2B1205)]),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(color: borderColor.withOpacity(0.4), blurRadius: 30, spreadRadius: 4),
            const BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(children: [
              SizedBox(height: 210, width: double.infinity,
                child: _buildCollectionImage(item)),
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(height: 80, decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [const Color(0xFF2B1205), Colors.transparent])))),
              Positioned(top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.5)),
                  child: Text(RarityConfig.label(item.rarity),
                    style: TextStyle(color: RarityConfig.labelColor(item.rarity), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)))),
              Positioned(top: 12, right: 12,
                child: GestureDetector(onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18)))),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name.toUpperCase(), style: const TextStyle(
                  color: Color(0xFFF5E1A4), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                if (item.origin.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFFFF9800), size: 14),
                    const SizedBox(width: 4),
                    Text(item.origin, style: const TextStyle(color: Color(0xFFFF9800), fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ],
                const SizedBox(height: 12),
                if (item.description.isNotEmpty)
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor.withOpacity(0.3))),
                    child: Text(item.description,
                      style: TextStyle(color: const Color(0xFFF5E1A4).withOpacity(0.85), fontSize: 12, height: 1.6))),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [borderColor.withOpacity(0.8), const Color(0xFF4B230B)]),
                      borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor.withOpacity(0.5))),
                    child: const Center(child: Text('Tutup  ✕',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MARKETING POPUP
// ─────────────────────────────────────────────
class _MarketingPopupWidget extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onGoToStore;
  const _MarketingPopupWidget({required this.onClose, required this.onGoToStore});
  @override State<_MarketingPopupWidget> createState() => _MarketingPopupWidgetState();
}

class _MarketingPopupWidgetState extends State<_MarketingPopupWidget> with TickerProviderStateMixin {
  late AnimationController _shimmer, _float, _glow, _rotateHL;
  late Animation<double> _floatAnim, _glowAnim;
  int _currentHL = 0;

  final _highlights = [
    {'emoji': '✦', 'name': 'Kawung Legendary', 'desc': 'Motif eksklusif Keraton!', 'color': 'gold'},
    {'emoji': '◆', 'name': 'Mega Mendung Epic', 'desc': 'Langka & berharga!', 'color': 'purple'},
    {'emoji': '🔥', 'name': 'Event Terbatas!', 'desc': 'Hanya hari ini — 50% OFF', 'color': 'orange'},
  ];

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -5.0, end: 5.0).animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut));
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glow, curve: Curves.easeInOut);
    _rotateHL = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          if (mounted) setState(() => _currentHL = (_currentHL + 1) % _highlights.length);
          _rotateHL.reset(); _rotateHL.forward();
        }
      })..forward();
  }

  @override
  void dispose() { _shimmer.dispose(); _float.dispose(); _glow.dispose(); _rotateHL.dispose(); super.dispose(); }

  Color _hColor(String key) => key == 'gold' ? const Color(0xFFFFD700) : key == 'purple' ? const Color(0xFFE040FB) : const Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    final hl = _highlights[_currentHL];
    final hc = _hColor(hl['color']!);
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF5C2A0D), Color(0xFF1E0D03)]),
          border: Border.all(color: const Color(0xFFFFD700), width: 3),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.25), blurRadius: 40, spreadRadius: 6),
            const BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 14))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(33),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _BatikPatternPainter(color: const Color(0xFFFFD700), opacity: 0.05))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(animation: _floatAnim,
                  builder: (_, __) => Transform.translate(offset: Offset(0, _floatAnim.value),
                    child: const Text('🎨', style: TextStyle(fontSize: 52)))),
                const SizedBox(height: 10),
                AnimatedBuilder(animation: _shimmer,
                  builder: (_, __) => ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: const [Color(0xFFFFD700), Color(0xFFFFF8DC), Color(0xFFFF9800), Color(0xFFFFD700)],
                      stops: [(_shimmer.value - 0.3).clamp(0.0, 1.0), _shimmer.value.clamp(0.0, 1.0),
                        (_shimmer.value + 0.1).clamp(0.0, 1.0), (_shimmer.value + 0.4).clamp(0.0, 1.0)],
                    ).createShader(bounds),
                    child: const Text('✨ KOLEKSI EKSKLUSIF ✨', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)))),
                const SizedBox(height: 6),
                Text('Lengkapi koleksi batik Nusantara\ndan raih gelar Master Batik!', textAlign: TextAlign.center,
                  style: TextStyle(color: const Color(0xFFF5E1A4).withOpacity(0.8), fontSize: 13, height: 1.4)),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
                    child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(anim), child: child)),
                  child: AnimatedBuilder(key: ValueKey(_currentHL), animation: _glowAnim,
                    builder: (_, __) => Container(
                      width: double.infinity, padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: hc.withOpacity(0.6 + _glowAnim.value * 0.3), width: 2),
                        boxShadow: [BoxShadow(color: hc.withOpacity(_glowAnim.value * 0.35), blurRadius: 16, spreadRadius: 2)]),
                      child: Row(children: [
                        Text(hl['emoji']!, style: TextStyle(fontSize: 28, color: hc)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(hl['name']!, style: TextStyle(color: hc, fontWeight: FontWeight.w900, fontSize: 14)),
                          Text(hl['desc']!, style: TextStyle(color: const Color(0xFFF5E1A4).withOpacity(0.7), fontSize: 11)),
                        ])),
                      ]),
                    )),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_highlights.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentHL ? 18 : 6, height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentHL ? const Color(0xFFFFD700) : const Color(0xFFFFD700).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3))))),
                const SizedBox(height: 20),
                _perkRow('🏆', 'Kumpulkan semua motif Jawa'),
                const SizedBox(height: 8),
                _perkRow('🎖️', 'Unlock gelar & avatar eksklusif'),
                const SizedBox(height: 8),
                _perkRow('💎', 'Batik Legendary = bonus koin 2×'),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: widget.onGoToStore,
                  child: AnimatedBuilder(animation: _glowAnim,
                    builder: (_, __) => Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3 + _glowAnim.value * 0.35), blurRadius: 20, spreadRadius: 2)]),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.storefront_rounded, color: Color(0xFF3B1A07), size: 20),
                        SizedBox(width: 8),
                        Text('Beli di Store Sekarang!',
                          style: TextStyle(color: Color(0xFF3B1A07), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                      ])))),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.15))),
                    child: const Center(child: Text('Nanti saja  →',
                      style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600))))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _perkRow(String emoji, String text) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 16)),
    const SizedBox(width: 10),
    Text(text, style: const TextStyle(color: Color(0xFFF5E1A4), fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}