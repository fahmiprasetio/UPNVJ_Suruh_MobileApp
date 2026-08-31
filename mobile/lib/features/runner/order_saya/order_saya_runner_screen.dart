import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../providers/runner_providers.dart';
import '../../dev/pengalih_akun.dart';
import '../../peran/tombol_ganti_mode.dart';
import '../../widgets/tombol_profil.dart';
import 'widgets/kartu_order_runner.dart';
import 'widgets/lembar_selesaikan_order.dart';
import '../../../providers/ukuran_daftar.dart';
import '../../widgets/pesan_kosong.dart';
import '../../widgets/rangka_daftar_order.dart';
import '../../widgets/tombol_muat_lagi.dart';

/// Order yang dipegang runner, yang sedang dikerjakan dan yang sudah kelar.
///
/// Sebelum layar ini ada, order yang sudah diterima runner tidak punya
/// kelanjutan sama sekali: statusnya "Dikerjakan" selamanya karena tidak ada
/// tempat untuk menutupnya.
class OrderSayaRunnerScreen extends ConsumerWidget {
  const OrderSayaRunnerScreen({super.key, this.onMintaOrderMasuk});

  /// Dipanggil saat runner yang belum memegang order memilih pergi mencarinya.
  ///
  /// Diminta dari luar, bukan diurus sendiri lewat navigasi, karena Order Masuk
  /// bukan layar yang bisa didorong ke atas layar ini: ia tab sebelah di
  /// cangkang yang sama, dan mendorongnya sebagai rute baru akan menumpuk dua
  /// daftar order masuk di riwayat navigasi.
  final VoidCallback? onMintaOrderMasuk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderRunnerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Saya'),
        actions: const [TombolGantiMode(), PengalihAkun(), TombolProfil()],
      ),
      body: SafeArea(
        child: orders.when(
          // Lihat alasannya di layar riwayat klien: jendela yang diperbesar menghitung
          // ulang provider yang sama, dan daftar yang sudah tampil tidak boleh berkedip
          // jadi pemuat karenanya.
          skipLoadingOnReload: true,
          loading: () => const RangkaDaftarOrder(jumlah: 2, denganTombol: true),
          error: (galat, _) => PesanKosong(
            ikon: Icons.wifi_off_outlined,
            judul: 'Order gagal dimuat',
            keterangan: galat is GalatApi
                ? galat.pesan
                : 'Sambungan ke server terputus.',
            labelAksi: 'Coba lagi',
            onAksi: () => ref.invalidate(orderRunnerProvider),
          ),
          data: (halaman) {
            final semua = halaman.isi;
            if (semua.isEmpty) {
              return PesanKosong(
                ikon: Icons.assignment_outlined,
                judul: 'Belum ada order yang kamu pegang',
                keterangan:
                    'Order yang kamu terima dari daftar Order Masuk akan '
                    'muncul di sini.',
                // Jalan keluarnya tab sebelah, bukan menyegarkan layar ini.
                // Daftar ini kosong bukan karena gagal dimuat, melainkan karena
                // runner memang belum mengambil apa pun, dan yang ia butuhkan
                // adalah tempat mengambilnya.
                labelAksi: 'Lihat Order Masuk',
                onAksi: onMintaOrderMasuk,
              );
            }

            final dikerjakan = semua.where((o) => o.status.isAktif).toList();
            final selesai = semua.where((o) => !o.status.isAktif).toList();

            return ListView(
              padding: const EdgeInsets.all(AppTheme.spasiSedang),
              children: [
                if (dikerjakan.isNotEmpty)
                  ..._bagian(
                    context,
                    'Sedang dikerjakan',
                    dikerjakan,
                    onSelesaikan: (order) => _bukaLembarSelesai(context, order),
                  ),
                if (selesai.isNotEmpty)
                  ..._bagian(context, 'Sudah selesai', selesai),
                TombolMuatLagi(
                  halaman: halaman,
                  ukuranProvider: ukuranOrderRunnerProvider,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _bagian(
    BuildContext context,
    String judul,
    List<Order> orders, {
    void Function(Order order)? onSelesaikan,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
        child: Text(
          '$judul (${orders.length})',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      for (final order in orders)
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil),
          child: KartuOrderRunner(
            order: order,
            onSelesaikan: onSelesaikan == null
                ? null
                : () => onSelesaikan(order),
            onChat: () => context.push(Rute.chatOrderRunner(order.id)),
          ),
        ),
      const SizedBox(height: AppTheme.spasiSedang),
    ];
  }

  Future<void> _bukaLembarSelesai(BuildContext context, Order order) async {
    final ditutup = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Pegangan seret bawaan Material, bukan gambar sendiri. Tanpa itu satu-
      // satunya cara menutup lembar ini adalah menekan latar gelap di atasnya,
      // dan itu hal yang harus ditebak, bukan hal yang terlihat.
      showDragHandle: true,
      builder: (context) => LembarSelesaikanOrder(order: order),
    );

    if (ditutup != true || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Order ${order.kodeOrder} ditandai selesai.')),
      );
  }
}
