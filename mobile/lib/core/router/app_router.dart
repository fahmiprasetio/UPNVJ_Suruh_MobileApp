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
import '../../features/profil/profil_screen.dart';
import '../../features/runner/ajukan_tawaran/ajukan_tawaran_screen.dart';
import '../../domain/enums.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/order.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../providers/repository_providers.dart';

/// Nama rute ditulis sebagai konstanta supaya tidak ada string jalur yang
/// tersebar di dalam layar.
class Rute {
  const Rute._();

  static const String masuk = '/masuk';
  static const String beranda = '/';
  static const String riwayat = '/order';
  static const String profil = '/profil';
  static const String detailOrderPola = '/order/:orderId';
  static const String bayarPola = '/order/:orderId/bayar';
  static const String chatOrderPola = '/order/:orderId/chat';
  static const String chatOrderRunnerPola = '/runner/order/:orderId/chat';
  static const String formAnterJemput = '/buat/anter-jemput';
  static const String formJastipBarang = '/buat/jastip-barang';
  static const String formPermintaanPola = '/buat/permintaan/:layanan';
  static const String ajukanTawaranPola = '/runner/order/:orderId/tawar';

  static String ajukanTawaran(String orderId) => '/runner/order/$orderId/tawar';

  static String detailOrder(String orderId) => '/order/$orderId';
  static String bayar(String orderId) => '/order/$orderId/bayar';

  /// [runnerId] cuma berarti selama order Jalur B masih menerima tawaran:
  /// jalur obrolan pribadi runner mana yang mau dilihat, karena bisa ada
  /// beberapa runner menawar bersamaan. Diabaikan begitu order sudah punya
  /// runner tetap.
  static String chatOrder(String orderId, {String? runnerId}) => runnerId == null
      ? '/order/$orderId/chat'
      : '/order/$orderId/chat?runnerId=$runnerId';

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

  return GoRouter(
    initialLocation: Rute.beranda,
    // Router ikut menyimak sesi. Tanpa ini, pengalihan di bawah cuma dihitung
    // saat ada perpindahan halaman, sehingga layar masuk tetap terpampang setelah
    // kode diterima, dan layar dalam tetap terbuka setelah pengguna keluar.
    //
    // Layar pembuka sengaja TIDAK ikut di sini, dan itu keputusan yang berubah:
    // dulu ia rute tersendiri dengan gerbang di `redirect`, sekarang ia lapisan
    // di atas seluruh aplikasi (lihat `UpnvjSuruhApp`). Sebagai rute, layar di
    // belakangnya baru mulai dibangun setelah pembukanya pergi, jadi selalu ada
    // jeda kosong di antara keduanya. Sebagai lapisan, layar di belakangnya
    // dibangun sejak bingkai pertama, tertutup pembuka, dan sudah tergambar utuh
    // saat pembukanya diangkat.
    refreshListenable: pendengar,
    redirect: (context, state) {
      // Sesinya dibaca dari pendengar, bukan dari `userAktifProvider`. Provider itu
      // beraliran dan otomatis dibuang saat tidak ada yang mengawasinya, jadi
      // membacanya di sini selalu menghasilkan keadaan "sedang memuat" dan
      // pengalihannya tidak pernah terjadi.
      final sudahMasuk = pendengar.user != null;
      final diLayarMasuk = state.matchedLocation == Rute.masuk;

      if (!sudahMasuk && !diLayarMasuk) return Rute.masuk;
      if (sudahMasuk && diLayarMasuk) return Rute.beranda;
      return null;
    },
    routes: [
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
        path: Rute.profil,
        builder: (context, state) => const ProfilScreen(),
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
        builder: (context, state) => ChatOrderScreen(
          orderId: state.pathParameters['orderId']!,
          runnerId: state.uri.queryParameters['runnerId'],
        ),
      ),
      GoRoute(
        path: Rute.chatOrderRunnerPola,
        builder: (context, state) => ChatOrderScreen(
          orderId: state.pathParameters['orderId']!,
          pengirim: MessageSender.runner,
        ),
      ),
      // Ketiga form order menerima order lama lewat `extra` untuk "Pesan lagi".
      // `extra` sengaja tidak divalidasi lebih jauh dari cast ini: yang bisa
      // mengisinya cuma kode aplikasi sendiri, bukan jalur yang diketik orang.
      GoRoute(
        path: Rute.formAnterJemput,
        builder: (context, state) =>
            FormAnterJemputScreen(contoh: state.extra as Order?),
      ),
      GoRoute(
        path: Rute.formJastipBarang,
        builder: (context, state) =>
            FormJastipBarangScreen(contoh: state.extra as Order?),
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
          return FormPermintaanScreen(
            serviceType: layanan,
            contoh: state.extra as Order?,
          );
        },
      ),
      GoRoute(
        path: Rute.ajukanTawaranPola,
        builder: (context, state) =>
            AjukanTawaranScreen(orderId: state.pathParameters['orderId']!),
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
