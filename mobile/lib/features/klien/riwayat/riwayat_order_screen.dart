import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/ukuran_daftar.dart';
import '../../widgets/pesan_kosong.dart';
import '../../widgets/rangka_daftar_order.dart';
import '../../widgets/tombol_muat_lagi.dart';
import '../buka_form_order.dart';
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
        loading: () => const RangkaDaftarOrder(),
        error: (galat, _) => PesanKosong(
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
            return PesanKosong(
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
            // Ditawarkan dari status ordernya sendiri, bukan dari bagian mana
            // kartu ini sedang digambar. Keduanya menjawab pertanyaan yang sama,
            // dan yang dibaca dari ordernya tidak bisa tidak sepakat dengan
            // pemisahan bagian di atas.
            //
            // Order yang batal ikut dapat, dan itu disengaja: order yang gagal
            // justru yang paling sering ingin diulang.
            onPesanLagi: order.status.isAktif || !adaFormOrder(order.serviceType)
                ? null
                : () => bukaFormOrder(context, order.serviceType, contoh: order),
          ),
        ),
    ];
  }
}
