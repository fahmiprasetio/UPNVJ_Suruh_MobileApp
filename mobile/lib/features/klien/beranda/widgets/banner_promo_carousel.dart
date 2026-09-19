import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:upnvj_suruh/core/theme/app_theme.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/features/klien/buka_form_order.dart';

/// Model data item untuk banner carousel promo di beranda klien.
class ItemBannerPromo {
  const ItemBannerPromo({
    required this.tag,
    required this.judul,
    required this.deskripsi,
    required this.ikon,
    required this.warnaTag,
    required this.warnaLatarAwal,
    required this.warnaLatarAkhir,
    required this.detailJudul,
    required this.detailIsi,
    this.kodeVoucher,
    this.teksAksi,
    this.aksiServiceType,
  });

  final String tag;
  final String judul;
  final String deskripsi;
  final IconData ikon;
  final Color warnaTag;
  final Color warnaLatarAwal;
  final Color warnaLatarAkhir;
  final String detailJudul;
  final String detailIsi;
  final String? kodeVoucher;
  final String? teksAksi;
  final ServiceType? aksiServiceType;
}

/// Daftar bawaan banner promo, tips hemat mahasiswa, dan layanan andalan kampus.
const List<ItemBannerPromo> daftarPromoBawaan = [
  ItemBannerPromo(
    tag: 'PROMO SPESIAL',
    judul: 'Diskon Ongkir Rp 5.000',
    deskripsi: 'Pakai kode VJHEMAT untuk pesanan pertamamu di UPNVJ Suruh!',
    ikon: Icons.confirmation_number_outlined,
    warnaTag: Color(0xFFFFD54F),
    warnaLatarAwal: Color(0xFF2E5E2A),
    warnaLatarAkhir: Color(0xFF1E401B),
    detailJudul: 'Voucher Pengguna Baru: VJHEMAT',
    detailIsi:
        'Nikmati potongan ongkir Rp 5.000 untuk pesanan pertamamu di UPNVJ Suruh. Salin kode voucher ini dan konfirmasikan ke runner saat menyepakati penawaran layanan!',
    kodeVoucher: 'VJHEMAT',
    teksAksi: 'Salin Kode',
  ),
  ItemBannerPromo(
    tag: 'TIPS HEMAT KAMPUS',
    judul: 'Titip Makan Bareng Teman',
    deskripsi: '1 runner bisa bawa hingga 3 porsi pesanan sekaligus tanpa ongkir dobel.',
    ikon: Icons.restaurant_rounded,
    warnaTag: Color(0xFFFF8A80),
    warnaLatarAwal: Color(0xFF6B1B26),
    warnaLatarAkhir: Color(0xFF4A0F18),
    detailJudul: 'Tips Hemat Jastip Makanan Kantin & Warteg',
    detailIsi:
        'Mau pesan makanan di kantin Pondok Labu, kantin Limo, atau warteg favorit sekitar kampus bareng teman kos? Buat 1 pesanan jastip dengan beberapa porsi sekaligus. Ongkir flat kurir tetap sama, jadi biaya patungan makin hemat!',
    teksAksi: 'Pesan Jastip Makanan',
    aksiServiceType: ServiceType.jastipMakanan,
  ),
  ItemBannerPromo(
    tag: 'LAYANAN KAMPUS',
    judul: 'Pindahan Kos Lebih Ringan',
    deskripsi: 'Runner mahasiswa siap bantu angkat kardus buku, koper, dan perabot.',
    ikon: Icons.inventory_2_outlined,
    warnaTag: Color(0xFF80CBC4),
    warnaLatarAwal: Color(0xFF1E302E),
    warnaLatarAkhir: Color(0xFF121E1C),
    detailJudul: 'Bantuan Pindah Kos UPNVJ',
    detailIsi:
        'Repot angkat kasur lipat, galon, koper, atau kardus buku saat pindah kamar kos di sekitar Pondok Labu atau Limo? Manfaatkan layanan Bantu Pindah Kos untuk mendapatkan partner runner mahasiswa dengan tenaga ekstra.',
    teksAksi: 'Buka Bantu Pindah Kos',
    aksiServiceType: ServiceType.bantuPindahKos,
  ),
];

/// Komponen carousel banner promo di beranda klien.
///
/// Menyediakan slide promo mahasiswa, tips hemat, dan informasi layanan dengan
/// animasi pergantian halus, indikator halaman, serta pop-up detail interaktif.
class BannerPromoCarousel extends StatefulWidget {
  const BannerPromoCarousel({
    super.key,
    this.daftarPromo = daftarPromoBawaan,
  });

  final List<ItemBannerPromo> daftarPromo;

  static const double tinggi = 140;
  static const double tinggiDiLuarKepala = 40;

  @override
  State<BannerPromoCarousel> createState() => _BannerPromoCarouselState();
}

class _BannerPromoCarouselState extends State<BannerPromoCarousel> {
  late final PageController _pageController;
  int _halamanAktif = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _tampilkanDetailPromo(BuildContext context, ItemBannerPromo item) {
    final skema = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.warnaTag.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
              ),
              child: Icon(item.ikon, color: item.warnaTag, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.tag,
                    style: TextStyle(
                      color: item.warnaTag,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    item.detailJudul,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              item.detailIsi,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: skema.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            if (item.kodeVoucher != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: skema.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
                  border: Border.all(color: skema.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kode Kupon',
                            style: TextStyle(
                              fontSize: 11,
                              color: skema.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            item.kodeVoucher!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: skema.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.kodeVoucher!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Kode kupon ${item.kodeVoucher} berhasil disalin!',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Salin'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Tutup'),
          ),
          if (item.aksiServiceType != null)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                bukaFormOrder(context, item.aksiServiceType!);
              },
              child: Text(item.teksAksi ?? 'Buka Layanan'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.daftarPromo.isEmpty) {
      return const SizedBox(height: BannerPromoCarousel.tinggi);
    }

    return Container(
      width: double.infinity,
      height: BannerPromoCarousel.tinggi,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.daftarPromo.length,
              onPageChanged: (indeks) {
                setState(() => _halamanAktif = indeks);
              },
              itemBuilder: (context, indeks) {
                final item = widget.daftarPromo[indeks];
                return _KartuBannerItem(
                  item: item,
                  onTap: () => _tampilkanDetailPromo(context, item),
                );
              },
            ),
            if (widget.daftarPromo.length > 1)
              Positioned(
                bottom: 12,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < widget.daftarPromo.length; i++)
                      GestureDetector(
                        key: ValueKey('indikator_promo_$i'),
                        onTap: () {
                          _pageController.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 6,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: i == _halamanAktif ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _halamanAktif
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusPil),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KartuBannerItem extends StatelessWidget {
  const _KartuBannerItem({
    required this.item,
    required this.onTap,
  });

  final ItemBannerPromo item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [item.warnaLatarAwal, item.warnaLatarAkhir],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: item.warnaTag.withValues(alpha: 0.22),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusPil),
                          border: Border.all(
                            color: item.warnaTag.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          item.tag,
                          style: TextStyle(
                            color: item.warnaTag,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.judul,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.deskripsi,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 11.5,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    item.ikon,
                    color: item.warnaTag,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
