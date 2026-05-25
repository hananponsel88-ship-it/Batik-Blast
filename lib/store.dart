import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pjbl_yallah/koleksi.dart'; // ← WAJIB untuk CollectionItem & BatikCollectionPage

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────
class StoreItem {
  final String id;
  final String name;
  final String imageAsset;
  final String imageUrl;
  final int price;
  final String description;
  final String origin;

  StoreItem({
    required this.id,
    required this.name,
    this.imageAsset = '',
    this.imageUrl = '',
    required this.price,
    this.description = '',
    this.origin = '',
  });

  factory StoreItem.fromMap(Map<String, dynamic> map) {
    return StoreItem(
      id: map['id'].toString(),
      name: map['name'] ?? '',
      imageAsset: map['image_asset'] ?? '',
      imageUrl: map['image_url'] ?? '',
      price: map['price'] ?? 0,
      description: map['description'] ?? '',
      origin: map['origin'] ?? '',
    );
  }
}

// ─────────────────────────────────────────────
// DATA HARDCODED
// ─────────────────────────────────────────────
final List<StoreItem> _hardcodedItems = [
  StoreItem(id: 'local_1', name: 'Taman Arum', imageAsset: 'assets/images/batik3.png.jpg', price: 200,
    description: 'Motif sulur melingkar khas Cirebon dengan warna cerah orange dan biru. Melambangkan keindahan taman surga.', origin: 'Cirebon, Jawa Barat'),
  StoreItem(id: 'local_2', name: 'Kawung', imageAsset: 'assets/images/kawung.png.jpg', price: 180,
    description: 'Motif geometris buah kawung (aren) yang dulunya hanya boleh dipakai keluarga kerajaan.', origin: 'Yogyakarta, Jawa Tengah'),
  StoreItem(id: 'local_3', name: 'Parang', imageAsset: 'assets/images/parang.png.jpg', price: 160,
    description: 'Salah satu motif batik tertua dari Solo. Diagonal kuat melambangkan keberanian dan semangat.', origin: 'Solo, Jawa Tengah'),
  StoreItem(id: 'local_4', name: 'Ceplok', imageAsset: 'assets/images/ceplok.png.jpg', price: 150,
    description: 'Motif geometris simetris berbentuk lingkaran dan bintang. Melambangkan keselarasan hidup.', origin: 'Jawa Tengah'),
  StoreItem(id: 'local_5', name: 'Sidomukti', imageAsset: 'assets/images/sidomukti.png.jpg', price: 220,
    description: 'Sido artinya "menjadi", mukti artinya "mulia". Motif harapan akan kemuliaan dan kemakmuran.', origin: 'Solo, Jawa Tengah'),
  StoreItem(id: 'local_6', name: 'Truntum', imageAsset: 'assets/images/truntum.jpg', price: 190,
    description: 'Motif bunga bintang yang tumbuh kembali. Melambangkan cinta yang tumbuh setelah ujian.', origin: 'Surakarta, Jawa Tengah'),
  StoreItem(id: 'local_7', name: 'Pekalongan', imageAsset: 'assets/images/batik4.png.jpg', price: 170,
    description: 'Batik pesisir khas Pekalongan dengan warna cerah dan motif bunga sulur yang dipengaruhi budaya Tionghoa dan Arab.', origin: 'Pekalongan, Jawa Tengah'),
  StoreItem(id: 'local_8', name: 'Singabarong', imageAsset: 'assets/images/singabarong.jpg', price: 240,
    description: 'Motif kepala singa mitos dari Cirebon. Melambangkan kekuatan, keberanian, dan perlindungan.', origin: 'Cirebon, Jawa Barat'),
  StoreItem(id: 'local_9', name: 'Sogan', imageAsset: 'assets/images/sogan.png.jpg', price: 130,
    description: 'Batik dengan warna coklat soga alami dari kulit pohon soga. Klasik dan penuh keanggunan.', origin: 'Solo, Jawa Tengah'),
  StoreItem(id: 'local_10', name: 'Tambal', imageAsset: 'assets/images/tambal1.jpg', price: 145,
    description: 'Motif tambal (tambalan) dipercaya bisa menyembuhkan orang sakit bila dipakai. Penuh makna spiritual.', origin: 'Jawa Tengah'),
];

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────
class StoreService {
  final _supabase = Supabase.instance.client;

  Future<List<StoreItem>> fetchItems() async {
    try {
      final response = await _supabase.from('store_items').select().order('price');
      final fromSupabase = (response as List).map((e) => StoreItem.fromMap(e)).toList();
      final combined = List<StoreItem>.from(_hardcodedItems);
      for (final item in fromSupabase) {
        if (!combined.any((e) => e.name == item.name)) combined.add(item);
      }
      return combined;
    } catch (_) {
      return _hardcodedItems;
    }
  }

  Future<void> purchaseItem(String itemId) async {
    // Item lokal: simpan ke localOwnedItems (tanpa Supabase — id bukan UUID)
    if (itemId.startsWith('local_')) {
      if (localOwnedItems.contains(itemId)) throw Exception('Item sudah dimiliki.');
      localOwnedItems.add(itemId);
      await saveLocalOwned(); // simpan permanen
      return;
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User belum login.');
    final existing = await _supabase.from('user_collections').select()
        .eq('user_id', userId).eq('item_id', itemId).maybeSingle();
    if (existing != null) throw Exception('Item sudah dimiliki.');
    await _supabase.from('user_collections').insert({
      'user_id': userId,
      'item_id': itemId,
      'purchased_at': DateTime.now().toIso8601String(),
    });
  }
}

// ─────────────────────────────────────────────
// HALAMAN STORE
// ─────────────────────────────────────────────
class BatikStorePage extends StatefulWidget {
  const BatikStorePage({super.key});
  @override State<BatikStorePage> createState() => _BatikStorePageState();
}

class _BatikStorePageState extends State<BatikStorePage> with TickerProviderStateMixin {
  final StoreService _service = StoreService();
  late Future<List<StoreItem>> _itemsFuture;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  late AnimationController _entryController;
  late Animation<double> _entryAnim;
  int _userCoins = 850;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _service.fetchItems();
    loadLocalOwned(); // muat koleksi lokal dari storage
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entryAnim = CurvedAnimation(parent: _entryController, curve: Curves.elasticOut);
    _entryController.forward();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Widget _buildImage(StoreItem item, {BoxFit fit = BoxFit.cover}) {
    if (item.imageUrl.isNotEmpty) {
      return Image.network(item.imageUrl, fit: fit,
        errorBuilder: (_, __, ___) => _imgError(),
        loadingBuilder: (_, child, prog) => prog == null ? child : _imgLoading());
    } else if (item.imageAsset.isNotEmpty) {
      return Image.asset(item.imageAsset, fit: fit,
        errorBuilder: (_, __, ___) => _imgError());
    }
    return _imgError();
  }

  Widget _imgError() => Container(color: const Color(0xFFE8C99A),
    child: const Icon(Icons.broken_image_rounded, size: 36, color: Color(0xFF4B230B)));
  Widget _imgLoading() => Container(color: const Color(0xFFE8C99A),
    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4B230B))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: Image.asset('assets/images/background.png.jpg', fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.12))),
        SafeArea(child: Column(children: [
          _buildTopNav(context),
          const SizedBox(height: 4),
          Expanded(child: FutureBuilder<List<StoreItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF4B230B)));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Gagal memuat store:\n${snapshot.error}',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
              }
              return _buildStoreBoard(context, snapshot.data!);
            },
          )),
          const SizedBox(height: 10),
          _buildBottomTitle(),
          const SizedBox(height: 16),
        ])),
      ]),
    );
  }

  Widget _buildTopNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF633316), shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD700), width: 3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))]),
            child: const Icon(Icons.undo_rounded, color: Colors.white, size: 26)),
        ),
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4B230B), width: 2.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFFD700).withOpacity(_glowAnim.value * 0.6), blurRadius: 14, spreadRadius: 2),
                const BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
              ]),
            child: Row(children: [
              const Text("🪙", style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text("$_userCoins", style: const TextStyle(color: Color(0xFF4B230B), fontWeight: FontWeight.w900, fontSize: 16)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildStoreBoard(BuildContext context, List<StoreItem> items) {
    final sw = MediaQuery.of(context).size.width;
    return ScaleTransition(
      scale: _entryAnim,
      child: Center(
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          Container(
            width: sw * 0.92,
            constraints: const BoxConstraints(maxWidth: 380),
            margin: const EdgeInsets.only(top: 38),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4B230B),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF5E1A4), borderRadius: BorderRadius.circular(30)),
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.82,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _buildCollectionItem(context),
                  ...List.generate(items.length, (i) => _buildBatikItem(items[i], i)),
                ],
              ),
            ),
          ),
          // Label STORE
          Positioned(
            top: 0,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFE65100)]),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF4B230B), width: 4),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFFD700).withOpacity(_glowAnim.value * 0.55), blurRadius: 18, spreadRadius: 3),
                    const BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
                  ]),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.star_rounded, color: Color(0xFFFFF8E7), size: 22),
                  SizedBox(width: 8),
                  Text('STORE', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                    color: Color(0xFFFFF8E7), letterSpacing: 2,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))])),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCollectionItem(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BatikCollectionPage()));
      },
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF4B230B), width: 3),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3))]),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("📖", style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text("Collection", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B230B))),
          SizedBox(height: 4),
          Text("Lihat koleksimu", style: TextStyle(fontSize: 10, color: Color(0xFF8B5E3C))),
        ]),
      ),
    );
  }

  Widget _buildBatikItem(StoreItem item, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + index * 80),
      curve: Curves.easeOutBack,
      builder: (_, val, child) => Transform.scale(scale: val, child: child),
      child: GestureDetector(
        onTap: () { HapticFeedback.mediumImpact(); _showBuyPopup(item); },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF4B230B), width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(children: [
              Expanded(child: Stack(fit: StackFit.expand, children: [
                _buildImage(item),
                Positioned(bottom: 0, left: 0, right: 0,
                  child: Container(height: 40, decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.5), Colors.transparent])))),
                Positioned(top: 6, left: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF4B230B).withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
                    child: Text(item.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
                Positioned(bottom: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), shape: BoxShape.circle),
                    child: const Icon(Icons.shopping_cart_rounded, size: 13, color: Color(0xFF4B230B)))),
              ])),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: const Color(0xFFF5E1A4),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("🪙", style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(item.price.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF4B230B))),
                ])),
            ]),
          ),
        ),
      ),
    );
  }

  void _showBuyPopup(StoreItem item) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true, barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.72),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (ctx, anim, _, __) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return ScaleTransition(scale: curve, child: FadeTransition(opacity: anim,
          child: Center(child: Material(color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFF4B230B), width: 4),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 30, spreadRadius: 4),
                  const BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10)),
                ]),
              child: ClipRRect(borderRadius: BorderRadius.circular(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(children: [
                    SizedBox(height: 200, width: double.infinity, child: _buildImage(item, fit: BoxFit.cover)),
                    Positioned(bottom: 0, left: 0, right: 0,
                      child: Container(height: 70, decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [Color(0xFFFFF8E7), Colors.transparent])))),
                    if (item.origin.isNotEmpty)
                      Positioned(top: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF4B230B).withOpacity(0.85), borderRadius: BorderRadius.circular(10)),
                          child: Text("📍 ${item.origin}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(children: [
                      Text(item.name, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4E342E), letterSpacing: 1)),
                      const SizedBox(height: 8),
                      if (item.description.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC68E5C).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF8B4513).withOpacity(0.2))),
                          child: Text(item.description, textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6D4C41), height: 1.5))),
                      const SizedBox(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        Column(children: [
                          const Text("Harga", style: TextStyle(fontSize: 11, color: Color(0xFF8B4513))),
                          Row(children: [
                            const Text("🪙", style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 4),
                            Text(item.price.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4B230B))),
                          ]),
                        ]),
                        Container(height: 36, width: 2, color: const Color(0xFF8B4513).withOpacity(0.2)),
                        Column(children: [
                          const Text("Koinmu", style: TextStyle(fontSize: 11, color: Color(0xFF8B4513))),
                          Row(children: [
                            const Text("💰", style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 4),
                            Text(_userCoins.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                              color: _userCoins >= item.price ? const Color(0xFF388E3C) : Colors.red)),
                          ]),
                        ]),
                      ]),
                      const SizedBox(height: 14),
                      if (_userCoins >= item.price)
                        GestureDetector(
                          onTap: () { HapticFeedback.mediumImpact(); Navigator.pop(ctx); _onBuyPressed(item); },
                          child: Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF388E3C), Color(0xFF1B5E20)]),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [BoxShadow(color: const Color(0xFF388E3C).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text("Beli Sekarang — 🪙${item.price}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            ])))
                      else
                        Container(
                          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(22)),
                          child: const Center(child: Text("Koin Tidak Cukup 😢",
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)))),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); },
                        child: Container(
                          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFBF360C)]),
                            borderRadius: BorderRadius.circular(22)),
                          child: const Center(child: Text("Batal  ✕",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))))),
                    ]),
                  ),
                ])),
            )))));
      },
    );
  }

  // ── FIX: _onBuyPressed langsung navigasi ke koleksi dengan popup reveal ──
  Future<void> _onBuyPressed(StoreItem item) async {
    try {
      await _service.purchaseItem(item.id);
      if (!mounted) return;
      setState(() => _userCoins -= item.price);

      // Konversi StoreItem → CollectionItem
      final collectionItem = CollectionItem(
        id: item.id,
        name: item.name,
        imageUrl: item.imageUrl,
        imageAsset: item.imageAsset,
        origin: item.origin,
        description: item.description,
        rarity: 1,
      );

      if (!mounted) return;
      // Navigasi ke koleksi, tampilkan popup "item baru didapat"
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BatikCollectionPage(newlyPurchased: collectionItem),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildBottomTitle() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Text('BATIK MAKER',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF4B230B),
          fontStyle: FontStyle.italic, letterSpacing: 2,
          shadows: [
            Shadow(color: const Color(0xFFFFD700).withOpacity(_glowAnim.value * 0.5), blurRadius: 12),
            const Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
          ])),
    );
  }
}