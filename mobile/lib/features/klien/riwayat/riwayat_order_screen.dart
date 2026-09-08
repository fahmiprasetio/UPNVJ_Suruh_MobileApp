import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/ukuran_daftar.dart';
import '../../widgets/pesan_kosong.dart';
import '../../widgets/rangka_daftar_order.dart';
import '../../widgets/tombol_muat_lagi.dart';
import '../buka_form_order.dart';
import '../widgets/kartu_order_ringkas.dart';

/// Order ini cocok dengan kata kunci pencarian atau tidak.
///
/// Dicocokkan ke kode order, nama layanan, dan catatan -- tiga hal yang sudah
/// tertulis di kartu ringkasnya sendiri (lihat [KartuOrderRingkas]), supaya
/// apa yang bisa dicari selalu sama dengan apa yang terlihat, tidak lebih
/// tidak kurang. Fungsi murni, terpisah dari widgetnya, supaya pencocokannya
/// bisa diuji tanpa merender apa pun.
///
/// Pencariannya cuma menyaring jendela order yang sudah termuat di layar,
/// bukan meminta server mencari ulang seluruh riwayat: layar ini sudah
/// memakai jendela yang membesar lewat "Muat lagi", dan order yang belum
/// dimuat memang belum bisa disaring sampai dimuat.
bool cocokPencarianOrder(Order order, String kueri) {
  final bersih = kueri.trim().toLowerCase();
  if (bersih.isEmpty) return true;

  return order.kodeOrder.toLowerCase().contains(bersih) ||
      serviceInfoOf(order.serviceType).nama.toLowerCase().contains(bersih) ||
      (order.deskripsi?.toLowerCase().contains(bersih) ?? false);
}

/// Daftar order milik klien.
///
/// Dipisah jadi dua bagian karena keduanya dibaca dengan kebutuhan berbeda:
/// yang berjalan dipantau, yang sudah kelar dicari-cari.
class RiwayatOrderScreen extends ConsumerStatefulWidget {
  const RiwayatOrderScreen({super.key, this.onMintaBeranda});

  /// Dipanggil saat pengguna yang belum punya order memilih mulai memesan.
  ///
  /// Diminta dari luar, bukan diurus sendiri lewat navigasi, karena beranda
  /// bukan layar yang bisa didorong ke atas layar ini: ia tab sebelah di
  /// cangkang yang sama, dan mendorongnya sebagai rute baru akan menumpuk dua
  /// beranda di riwayat navigasi.
  final VoidCallback? onMintaBeranda;

  @override
  ConsumerState<RiwayatOrderScreen> createState() => _RiwayatOrderScreenState();
}

class _RiwayatOrderScreenState extends ConsumerState<RiwayatOrderScreen> {
  final _pencarianController = TextEditingController();

  @override
  void dispose() {
    _pencarianController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              labelAksi: widget.onMintaBeranda == null ? null : 'Mulai memesan',
              onAksi: widget.onMintaBeranda,
            );
          }

          final kueri = _pencarianController.text;
          final tersaring = kueri.trim().isEmpty
              ? semua
              : semua.where((o) => cocokPencarianOrder(o, kueri)).toList();

          final berjalan = tersaring.where((o) => o.status.isAktif).toList();
          final selesai = tersaring.where((o) => !o.status.isAktif).toList();

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            children: [
              TextField(
                controller: _pencarianController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Cari kode, layanan, atau catatan',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: kueri.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_pencarianController.clear),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spasiSedang),
              if (tersaring.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spasiBesar,
                  ),
                  child: Text(
                    'Tidak ada order yang cocok dengan "${kueri.trim()}".',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else ...[
                if (berjalan.isNotEmpty)
                  ..._bagian(
                    context,
                    'Sedang berjalan',
                    berjalan,
                    pertama: true,
                  ),
                if (selesai.isNotEmpty)
                  ..._bagian(
                    context,
                    'Sudah selesai',
                    selesai,
                    pertama: berjalan.isEmpty,
                  ),
              ],
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
