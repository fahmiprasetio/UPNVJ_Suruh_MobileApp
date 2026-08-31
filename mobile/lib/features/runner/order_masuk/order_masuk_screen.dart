import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/order.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/runner_providers.dart';
import '../../dev/pengalih_akun.dart';
import '../../peran/tombol_ganti_mode.dart';
import '../../widgets/tombol_profil.dart';
import 'widgets/kartu_order_siaran.dart';
import '../../../providers/ukuran_daftar.dart';
import '../../widgets/pesan_kosong.dart';
import '../../widgets/rangka_daftar_order.dart';
import '../../widgets/tombol_muat_lagi.dart';

/// Layar utama runner: order yang sudah dibayar dan sedang mencari runner.
///
/// Semua runner melihat daftar yang sama pada saat yang sama, jadi dua orang
/// bisa menekan TERIMA untuk order yang sama dalam hitungan detik. Yang
/// menentukan siapa dapat bukan layar ini, melainkan repository, layar hanya
/// menyampaikan jawabannya (rencana capstone bagian 14.5).
class OrderMasukScreen extends ConsumerStatefulWidget {
  const OrderMasukScreen({super.key});

  @override
  ConsumerState<OrderMasukScreen> createState() => _OrderMasukScreenState();
}

class _OrderMasukScreenState extends ConsumerState<OrderMasukScreen> {
  /// Order yang tombolnya sedang menunggu jawaban. Disimpan per order, bukan
  /// satu bendera untuk seluruh layar, supaya menerima satu order tidak
  /// mengunci tombol order lain.
  final Set<String> _sedangDiproses = {};

  @override
  Widget build(BuildContext context) {
    final tersiar = ref.watch(orderTersiarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Masuk'),
        actions: const [TombolGantiMode(), PengalihAkun(), TombolProfil()],
      ),
      body: SafeArea(
        child: tersiar.when(
          skipLoadingOnReload: true,
          // Rangka berbentuk daftar, bukan pemutar di tengah layar; alasannya
          // sama seperti di daftar klien. Kartunya bertombol, jadi rangkanya
          // ikut bertombol, kalau tidak tata letaknya melompat sekali tepat
          // saat isinya datang.
          loading: () => const RangkaDaftarOrder(
            denganJudulBagian: false,
            denganTombol: true,
          ),
          error: (galat, _) => PesanKosong(
            ikon: Icons.wifi_off_outlined,
            judul: 'Order gagal dimuat',
            // Kalimat yang memang ditulis untuk dibaca orang kalau ada, jejak
            // pengecualian mentah tidak pernah. Runner yang sedang mencari
            // pekerjaan tidak tertolong oleh nama kelas Dart, dan yang terbaca
            // olehnya cuma bahwa aplikasi ini rusak lebih parah daripada
            // sebenarnya.
            keterangan: galat is GalatApi
                ? galat.pesan
                : 'Sambungan ke server terputus.',
            labelAksi: 'Coba lagi',
            onAksi: () => ref.invalidate(orderTersiarProvider),
          ),
          data: (halaman) {
            final orders = halaman.isi;
            if (orders.isEmpty) {
              return PesanKosong(
                ikon: Icons.inbox_outlined,
                judul: 'Belum ada order masuk',
                keterangan:
                    'Order yang sudah dibayar klien akan muncul di sini. '
                    'Siapa cepat, dia dapat.',
                // Kosong di sini bukan jalan buntu seperti di daftar milik
                // sendiri: yang ditunggu runner adalah kiriman orang lain, dan
                // satu-satunya hal masuk akal yang bisa ia lakukan adalah
                // menengok lagi. Tanpa tombol ini ia akan berpindah tab
                // bolak-balik untuk memaksa daftarnya dimuat ulang.
                labelAksi: 'Cek lagi',
                onAksi: () => ref.invalidate(orderTersiarProvider),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppTheme.spasiSedang),
              // Satu baris tambahan di ujung untuk tombol muat lagi, yang menyembunyikan
              // dirinya sendiri kalau memang tidak ada sisanya.
              itemCount: orders.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.spasiKecil + 2),
              itemBuilder: (context, indeks) {
                if (indeks == orders.length) {
                  return TombolMuatLagi(
                    halaman: halaman,
                    ukuranProvider: ukuranOrderTersiarProvider,
                  );
                }

                final order = orders[indeks];
                return KartuOrderSiaran(
                  order: order,
                  sedangDiproses: _sedangDiproses.contains(order.id),
                  onTerima: () => _terima(order),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _terima(Order order) async {
    final user = ref.read(userAktifProvider).value;
    if (user == null) return;

    setState(() => _sedangDiproses.add(order.id));

    final bool dapat;
    try {
      dapat = await ref
          .read(orderRepositoryProvider)
          .terimaOrder(orderId: order.id);
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangDiproses.remove(order.id));
      _kabari('Order ${order.kodeOrder} gagal diambil: $galat');
      return;
    }

    if (!mounted) return;
    setState(() => _sedangDiproses.remove(order.id));

    // Kalah cepat bukan kegagalan sistem, jadi tidak ditampilkan sebagai
    // galat. Ordernya juga hilang sendiri dari daftar karena siarannya sudah
    // ditutup, runner tidak perlu menyegarkan apa pun.
    _kabari(
      dapat
          ? 'Order ${order.kodeOrder} jadi milikmu. Segera kerjakan, ya.'
          : 'Order ${order.kodeOrder} keburu diambil runner lain.',
    );
  }

  void _kabari(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }
}
