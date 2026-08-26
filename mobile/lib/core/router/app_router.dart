import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/gerbang_permukaan.dart';
import '../../features/klien/detail_order/detail_order_screen.dart';
import '../../features/klien/order_jalur_a/form_anter_jemput_screen.dart';
import '../../features/klien/order_jalur_a/form_jastip_barang_screen.dart';
import '../../features/klien/pembayaran/pembayaran_screen.dart';
import '../../features/klien/riwayat/riwayat_order_screen.dart';

/// Nama rute ditulis sebagai konstanta supaya tidak ada string jalur yang
/// tersebar di dalam layar.
class Rute {
  const Rute._();

  static const String beranda = '/';
  static const String riwayat = '/order';
  static const String detailOrderPola = '/order/:orderId';
  static const String bayarPola = '/order/:orderId/bayar';
  static const String formAnterJemput = '/buat/anter-jemput';
  static const String formJastipBarang = '/buat/jastip-barang';

  static String detailOrder(String orderId) => '/order/$orderId';
  static String bayar(String orderId) => '/order/$orderId/bayar';
}

/// Router dibuat lewat provider, bukan variabel global.
///
/// GoRouter menyimpan riwayat navigasi di dalam dirinya. Sebagai variabel
/// global, satu instance itu hidup selama proses berjalan dan posisinya
/// terbawa ke mana-mana, antar tes, dan nanti antar sesi login. Lewat
/// provider, setiap [ProviderScope] mendapat router bersih sendiri.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Rute.beranda,
    routes: [
      GoRoute(
        path: Rute.beranda,
        // Bukan langsung beranda klien: permukaan yang terbuka ditentukan
        // peran akun yang masuk (bagian 14.1).
        builder: (context, state) => const GerbangPermukaan(),
      ),
      GoRoute(
        path: Rute.riwayat,
        builder: (context, state) => const RiwayatOrderScreen(),
      ),
      GoRoute(
        path: Rute.detailOrderPola,
        builder: (context, state) =>
            DetailOrderScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: Rute.bayarPola,
        builder: (context, state) =>
            PembayaranScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: Rute.formAnterJemput,
        builder: (context, state) => const FormAnterJemputScreen(),
      ),
      GoRoute(
        path: Rute.formJastipBarang,
        builder: (context, state) => const FormJastipBarangScreen(),
      ),
    ],
  );
});
