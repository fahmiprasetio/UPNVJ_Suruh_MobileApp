import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/masuk_screen.dart';
import '../../features/gerbang_permukaan.dart';
import '../../features/chat/chat_order_screen.dart';
import '../../features/klien/detail_order/detail_order_screen.dart';
import '../../features/klien/order_jalur_a/form_anter_jemput_screen.dart';
import '../../features/klien/order_jalur_a/form_jastip_barang_screen.dart';
import '../../features/klien/order_jalur_b/form_permintaan_screen.dart';
import '../../features/klien/pembayaran/pembayaran_screen.dart';
import '../../features/klien/riwayat/riwayat_order_screen.dart';
import '../../features/pembuka/pembuka_screen.dart';
import '../../domain/enums.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../providers/pembuka_providers.dart';
import '../../providers/repository_providers.dart';

/// Nama rute ditulis sebagai konstanta supaya tidak ada string jalur yang
/// tersebar di dalam layar.
class Rute {
  const Rute._();

  static const String pembuka = '/pembuka';
  static const String masuk = '/masuk';
  static const String beranda = '/';
  static const String riwayat = '/order';
  static const String detailOrderPola = '/order/:orderId';
  static const String bayarPola = '/order/:orderId/bayar';
  static const String chatOrderPola = '/order/:orderId/chat';
  static const String chatOrderRunnerPola = '/runner/order/:orderId/chat';
  static const String formAnterJemput = '/buat/anter-jemput';
  static const String formJastipBarang = '/buat/jastip-barang';
  static const String formPermintaanPola = '/buat/permintaan/:layanan';

  static String detailOrder(String orderId) => '/order/$orderId';
  static String bayar(String orderId) => '/order/$orderId/bayar';
  static String chatOrder(String orderId) => '/order/$orderId/chat';

  /// Ruang chat yang sama, dibuka dari sisi runner. Jalurnya dipisah supaya
  /// peran penulis pesan ditentukan rute, bukan ditebak dari isi layar.
  static String chatOrderRunner(String orderId) =>
      '/runner/order/$orderId/chat';

  /// Satu rute untuk seluruh layanan Jalur B, jenis layanannya ikut di jalur.
  static String formPermintaan(ServiceType layanan) =>
      '/buat/permintaan/${layanan.name}';
}

/// Router dibuat lewat provider, bukan variabel global.
///
/// GoRouter menyimpan riwayat navigasi di dalam dirinya. Sebagai variabel
/// global, satu instance itu hidup selama proses berjalan dan posisinya
/// terbawa ke mana-mana, antar tes, dan nanti antar sesi login. Lewat
/// provider, setiap [ProviderScope] mendapat router bersih sendiri.
final routerProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final pendengar = _PendengarSesi(repo);
  ref.onDispose(pendengar.dispose);
  final pembuka = ref.watch(statusPembukaProvider);

  return GoRouter(
    initialLocation: Rute.pembuka,
    // Router menyimak dua hal sekaligus: sesi menentukan layar mana yang boleh
    // dibuka, pembuka menentukan kapan layar mana pun boleh dibuka. Tanpa
    // disimak, pengalihan di bawah cuma dihitung saat ada perpindahan halaman,
    // sehingga layar masuk tetap terpampang setelah kode diterima, layar dalam
    // tetap terbuka setelah pengguna keluar, dan pembuka tidak pernah bubar
    // karena tidak ada yang menyuruh router menghitung ulang.
    refreshListenable: Listenable.merge([pendengar, pembuka]),
    redirect: (context, state) {
      final diPembuka = state.matchedLocation == Rute.pembuka;

      // Selama animasi pembuka berjalan, tidak ada layar lain yang terbuka.
      // Gerbangnya di sini, bukan di dalam layar pembukanya, supaya jalur yang
      // diketik langsung di bilah alamat browser juga ikut tertahan.
      if (!pembuka.selesai) return diPembuka ? null : Rute.pembuka;

      // Sesinya dibaca dari pendengar, bukan dari `userAktifProvider`. Provider itu
      // beraliran dan otomatis dibuang saat tidak ada yang mengawasinya, jadi
      // membacanya di sini selalu menghasilkan keadaan "sedang memuat" dan
      // pengalihannya tidak pernah terjadi.
      final sudahMasuk = pendengar.user != null;
      final diLayarMasuk = state.matchedLocation == Rute.masuk;

      // Pembuka tidak punya isi setelah animasinya habis, jadi ia tidak boleh
      // ditinggali. Ke mana perginya ditentukan sesi, sama seperti rute lain.
      if (diPembuka) return sudahMasuk ? Rute.beranda : Rute.masuk;

      if (!sudahMasuk && !diLayarMasuk) return Rute.masuk;
      if (sudahMasuk && diLayarMasuk) return Rute.beranda;
      return null;
    },
    routes: [
      GoRoute(
        path: Rute.pembuka,
        builder: (context, state) => const PembukaScreen(),
      ),
      GoRoute(
        path: Rute.masuk,
        builder: (context, state) => const MasukScreen(),
      ),
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
        path: Rute.chatOrderPola,
        builder: (context, state) =>
            ChatOrderScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: Rute.chatOrderRunnerPola,
        builder: (context, state) => ChatOrderScreen(
          orderId: state.pathParameters['orderId']!,
          pengirim: MessageSender.runner,
        ),
      ),
      GoRoute(
        path: Rute.formAnterJemput,
        builder: (context, state) => const FormAnterJemputScreen(),
      ),
      GoRoute(
        path: Rute.formJastipBarang,
        builder: (context, state) => const FormJastipBarangScreen(),
      ),
      GoRoute(
        path: Rute.formPermintaanPola,
        builder: (context, state) {
          final nama = state.pathParameters['layanan'];
          // Jalur yang dikarang tangan tidak boleh menjatuhkan aplikasi, dan
          // tidak boleh diam-diam berubah jadi layanan lain. Pintu permintaan
          // bebas adalah tempat yang paling jujur untuk menampungnya.
          final layanan = ServiceType.values.firstWhere(
            (s) => s.name == nama && s.track == OrderTrack.jalurB,
            orElse: () => ServiceType.permintaanLain,
          );
          return FormPermintaanScreen(serviceType: layanan);
        },
      ),
    ],
  );
});

/// Menjembatani sesi ke GoRouter, sekaligus memegang nilai terakhirnya.
///
/// GoRouter menerima [Listenable], sementara sesi datang sebagai [Stream]. Nilainya
/// ikut disimpan di sini, bukan dibaca ulang dari provider saat `redirect` dipanggil,
/// karena provider sesi beraliran dan otomatis dibuang begitu tidak ada yang
/// mengawasinya; membacanya dari dalam `redirect` selalu menghasilkan keadaan
/// "sedang memuat", dan pengalihannya tidak pernah terjadi.
///
/// Nilai awalnya diambil serentak dari [AuthRepository.userAktif], supaya keputusan
/// pengalihan pertama sudah benar di frame pertama. Tanpa itu, pengguna yang belum
/// masuk sempat melihat layar dalam berkedip sebelum dilempar ke layar masuk.
class _PendengarSesi extends ChangeNotifier {
  _PendengarSesi(AuthRepository repo) : _user = repo.userAktif {
    _langganan = repo.watchUserAktif().listen((user) {
      if (user == _user) return;
      _user = user;
      notifyListeners();
    });
  }

  AppUser? _user;

  AppUser? get user => _user;

  late final StreamSubscription<AppUser?> _langganan;

  @override
  void dispose() {
    _langganan.cancel();
    super.dispose();
  }
}
