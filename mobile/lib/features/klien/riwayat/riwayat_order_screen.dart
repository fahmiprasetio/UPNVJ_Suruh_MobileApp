import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/ukuran_daftar.dart';
import '../../widgets/tombol_muat_lagi.dart';
import '../widgets/kartu_order_ringkas.dart';

/// Daftar order milik klien.
///
/// Dipisah jadi dua bagian karena keduanya dibaca dengan kebutuhan berbeda:
/// yang berjalan dipantau, yang sudah kelar dicari-cari.
class RiwayatOrderScreen extends ConsumerWidget {
  const RiwayatOrderScreen({super.key, this.onMintaBeranda});

  /// Dipanggil saat pengguna yang belum punya order memilih mulai memesan.
  ///
  /// Diminta dari luar, bukan diurus sendiri lewat navigasi, karena beranda
  /// bukan layar yang bisa didorong ke atas layar ini: ia tab sebelah di
  /// cangkang yang sama, dan mendorongnya sebagai rute baru akan menumpuk dua
  /// beranda di riwayat navigasi.
  final VoidCallback? onMintaBeranda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderKlienProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order Saya')),
      body: orders.when(
        // Jendela yang baru diperbesar membuat provider ini dihitung ulang. Tanpa ini
        // daftar yang sudah tampil berkedip jadi pemuat setiap kali "muat lagi"
        // ditekan, yaitu tepat pada saat orang sedang menatapnya.
        skipLoadingOnReload: true,
        loading: () => const _RangkaMuat(),
        error: (galat, _) => _PesanKosong(
          ikon: Icons.wifi_off_outlined,
          judul: 'Order gagal dimuat',
          // Kalimat yang sudah ditulis untuk dibaca orang kalau ada; jejak galat
          // mentah tidak pernah. Nama pengecualian dan jalur berkasnya tidak
          // menolong siapa pun yang sedang mencari pesanannya, dan yang terbaca
          // olehnya cuma bahwa aplikasi ini rusak lebih parah daripada
          // sebenarnya.
          keterangan: galat is GalatApi
              ? galat.pesan
              : 'Sambungan ke server terputus.',
          labelAksi: 'Coba lagi',
          onAksi: () => ref.invalidate(orderKlienProvider),
        ),
        data: (halaman) {
          final semua = halaman.isi;
          if (semua.isEmpty) {
            return _PesanKosong(
              ikon: Icons.receipt_long_outlined,
              judul: 'Belum ada order',
              // Mengajari, bukan sekadar memberi tahu bahwa kosong. Ini layar
              // pertama yang dilihat pengguna baru di tab ini, dan kalau ia
              // cuma berkata "tidak ada apa-apa", satu-satunya yang dipelajari
              // pengguna adalah bahwa tab ini tidak berguna.
              keterangan:
                  'Pesanan yang kamu buat muncul di sini, lengkap dengan '
                  'harga dan statusnya.',
              labelAksi: onMintaBeranda == null ? null : 'Mulai memesan',
              onAksi: onMintaBeranda,
            );
          }

          final berjalan = semua.where((o) => o.status.isAktif).toList();
          final selesai = semua.where((o) => !o.status.isAktif).toList();

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            children: [
              if (berjalan.isNotEmpty)
                ..._bagian(context, 'Sedang berjalan', berjalan, pertama: true),
              if (selesai.isNotEmpty)
                ..._bagian(
                  context,
                  'Sudah selesai',
                  selesai,
                  pertama: berjalan.isEmpty,
                ),
              TombolMuatLagi(
                halaman: halaman,
                ukuranProvider: ukuranOrderKlienProvider,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _bagian(
    BuildContext context,
    String judul,
    List<Order> orders, {
    required bool pertama,
  }) {
    return [
      // Jarak di atas judul lebih besar daripada di bawahnya, supaya judul
      // menempel pada kelompok yang ia namai alih-alih mengambang di antara dua
      // kelompok. Yang pertama tidak butuh jarak atas: di atasnya sudah ada tepi
      // halaman.
      if (!pertama) const SizedBox(height: AppTheme.spasiBesar),
      Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil + 2),
        child: Text(
          '$judul (${orders.length})',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      for (final order in orders)
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil + 2),
          child: KartuOrderRingkas(
            order: order,
            onTap: () => context.push(Rute.detailOrder(order.id)),
          ),
        ),
    ];
  }
}

/// Bentuk kasar daftar order selagi isinya diambil.
///
/// Bukan pemutar di tengah layar. Yang dinanti pengguna adalah daftar, dan
/// rangka yang sudah berbentuk daftar membuat isinya terasa sedang datang alih-
/// alih membuat layarnya terasa berhenti. Hanya muncul pada pengambilan pertama;
/// pengambilan ulang berkala mempertahankan daftar yang sudah tampil.
class _RangkaMuat extends StatelessWidget {
  const _RangkaMuat();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    Widget balok(double lebar, double tinggi) => Container(
      width: lebar,
      height: tinggi,
      decoration: BoxDecoration(
        color: skema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.spasiKecil / 2),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil + 2),
          child: balok(150, 20),
        ),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil + 2),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spasiSedang),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        balok(120, 14),
                        const Spacer(),
                        balok(72, 18),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spasiKecil),
                    balok(160, 12),
                    const SizedBox(height: AppTheme.spasiSedang),
                    balok(110, 22),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Layar tanpa isi: kosong, gagal dimuat, atau belum pernah dipakai.
///
/// Selalu menawarkan satu jalan keluar kalau ada. Layar yang cuma menyatakan
/// keadaan meninggalkan pengguna di jalan buntu, dan jalan buntu di tab yang
/// baru pertama kali dibuka adalah kesan pertama yang tidak perlu.
class _PesanKosong extends StatelessWidget {
  const _PesanKosong({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    this.labelAksi,
    this.onAksi,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final String? labelAksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final aksi = onAksi;
    final label = labelAksi;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spasiBesar),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spasiSedang),
              decoration: BoxDecoration(
                color: skema.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(ikon, size: 32, color: skema.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spasiSedang),
            Text(
              judul,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: skema.onSurfaceVariant),
            ),
            if (aksi != null && label != null) ...[
              const SizedBox(height: AppTheme.spasiBesar),
              FilledButton(
                onPressed: aksi,
                // Tidak selebar layar. Tombol di tengah layar kosong yang
                // membentang penuh terbaca sebagai formulir yang belum selesai;
                // yang ini sebuah tawaran, bukan langkah wajib.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spasiBesar,
                  ),
                ),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
