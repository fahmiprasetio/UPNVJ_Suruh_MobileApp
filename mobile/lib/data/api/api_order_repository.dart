import 'dart:async';

import '../../core/api/klien_api.dart';
import '../../core/api/konfigurasi_api.dart';
import '../../domain/enums.dart';
import '../../core/config/batas_halaman.dart';
import '../../domain/models/halaman.dart';
import '../../domain/models/order.dart';
import '../../domain/repositories/order_repository.dart';
import 'pemeta_dasar.dart';
import 'pemeta_order.dart';

/// Akses order lewat API .NET.
///
/// ## Bagaimana aliran dibuat dari API yang bukan aliran
///
/// Kontraknya berbentuk `Stream`, sementara API-nya tanya-jawab biasa. Jembatannya
/// dua hal, dan keduanya sengaja sederhana:
///
///   - Setiap perubahan yang **dibuat aplikasi ini sendiri** menabuh [_perubahan],
///     dan setiap aliran yang sedang dibuka langsung mengambil ulang. Jadi menekan
///     TERIMA atau mengirim pesan terlihat hasilnya seketika, tanpa menunggu.
///   - Perubahan yang dibuat **orang lain** (runner lain mengirim penawaran atau
///     mengambil order, uang masuk) datang lewat [perubahanLuar], kalau
///     terpasang, yaitu aliran [OrderHubClient.perubahan]. Selain itu ada
///     pengambilan berkala sebagai jaring pengaman.
///
/// Pengambilan berkala tetap dipertahankan sebagai jaring pengaman, sekalipun
/// [perubahanLuar] terpasang: hub yang putus sesaat (jaringan kampus yang goyah,
/// tab lama tidak difokuskan) tidak boleh membuat layar diam-diam basi selamanya
/// menunggu koneksi pulih. Yang berubah begitu hub tersambung cuma seberapa cepat
/// perubahan orang lain terlihat, bukan hilangnya jaring pengaman itu.
class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository({
    required KlienApi klien,
    Duration? jedaSegarkan,
    Stream<void>? perubahanLuar,
  }) : _klien = klien,
       _jedaSegarkan = jedaSegarkan ?? KonfigurasiApi.jedaSegarkan {
    // Kabar dari hub SignalR diperlakukan sama seperti perubahan yang dibuat
    // aplikasi ini sendiri: menabuh [_perubahan] supaya aliran yang sedang
    // dibuka langsung mengambil ulang. Isi pesannya sendiri tidak pernah dibaca
    // di sini, lihat alasannya di [OrderHubClient.perubahan].
    _langgananLuar = perubahanLuar?.listen((_) => _tandaiBerubah());
  }

  final KlienApi _klien;
  final Duration _jedaSegarkan;
  final StreamController<void> _perubahan = StreamController<void>.broadcast();
  StreamSubscription<void>? _langgananLuar;

  /// Mengubah satu pengambilan jadi aliran yang menyegarkan diri.
  ///
  /// Berlangganan pemicunya lebih dulu, baru mengambil. Kalau urutannya terbalik,
  /// perubahan yang terjadi selagi pengambilan pertama masih berjalan akan hilang
  /// tanpa jejak, dan layarnya diam di keadaan sebelum perubahan itu sampai
  /// penyegaran berkala berikutnya.
  Stream<T> _amati<T>(Future<T> Function() ambil) {
    late StreamController<T> kendali;
    StreamSubscription<void>? langganan;
    Timer? pewaktu;

    var sedangAmbil = false;
    var mintaLagi = false;
    var berhenti = false;

    Future<void> segarkan() async {
      // Permintaan yang datang saat pengambilan sedang jalan tidak menumpuk jadi
      // permintaan kedua yang berbarengan, tapi juga tidak dibuang: ia ditunda
      // sampai yang sekarang selesai, lalu dijalankan sekali.
      if (sedangAmbil) {
        mintaLagi = true;
        return;
      }
      if (berhenti) return;
      sedangAmbil = true;
      try {
        do {
          mintaLagi = false;
          final hasil = await ambil();
          if (!kendali.isClosed) kendali.add(hasil);
          // Susulan yang terlanjur diminta tepat sebelum layarnya ditutup tidak
          // ikut dijalankan. Hasilnya memang tidak akan sampai ke siapa-siapa,
          // tapi permintaannya tetap berangkat ke server, dan jumlah permintaan
          // yang terbang setelah layar ditutup seharusnya nol.
        } while (mintaLagi && !berhenti);
      } catch (galat, jejak) {
        if (!kendali.isClosed) kendali.addError(galat, jejak);
      } finally {
        sedangAmbil = false;
      }
    }

    kendali = StreamController<T>(
      onListen: () {
        langganan = _perubahan.stream.listen((_) => segarkan());
        pewaktu = Timer.periodic(_jedaSegarkan, (_) => segarkan());
        segarkan();
      },
      onCancel: () async {
        // Pewaktu yang tertinggal hidup setelah layarnya ditutup akan terus
        // menembak permintaan sepanjang aplikasi terbuka.
        berhenti = true;
        pewaktu?.cancel();
        await langganan?.cancel();
      },
    );

    return kendali.stream;
  }

  void _tandaiBerubah() {
    if (!_perubahan.isClosed) _perubahan.add(null);
  }

  // --- Membaca ---

  @override
  Stream<Halaman<Order>> watchOrderKlien({required int ukuran}) =>
      _amati(() => _daftar('/api/orders/saya', ukuran));

  @override
  Stream<Halaman<Order>> watchOrderTersiar({required int ukuran}) =>
      _amati(() => _daftar('/api/orders/tersiar', ukuran));

  @override
  Stream<Halaman<Order>> watchOrderRunner({required int ukuran}) =>
      _amati(() => _daftar('/api/orders/runner-saya', ukuran));

  @override
  Stream<Order?> watchOrder(String orderId, {int ukuranPesan = BatasHalaman.bawaan}) =>
      _amati(() => getOrder(orderId, ukuranPesan: ukuranPesan));

  @override
  Future<Order?> getOrder(String orderId, {int ukuranPesan = BatasHalaman.bawaan}) async {
    // Ordernya dan percakapannya diambil bersamaan, bukan berurutan. Layar yang
    // menampilkan salah satunya hampir selalu menampilkan keduanya, dan menunggu
    // dua perjalanan bolak-balik berturut-turut terasa dua kali lebih lambat.
    final hasil = await Future.wait([
      _klien.get('/api/orders/$orderId'),
      _klien.get(
        '/api/orders/$orderId/pesan',
        kueri: {'ukuran': '${ukuranPesan.clamp(1, BatasHalaman.maksimal)}'},
      ),
    ]);

    final isi = hasil[0];
    // Berapa pesan seluruhnya sudah ikut di jawaban ordernya sebagai jumlahPesan, jadi
    // total pada halaman ini tidak perlu dibaca lagi: layar membandingkan panjang yang
    // terbawa dengan angka itu untuk tahu masih ada yang lebih lama atau tidak.
    final pesan = PemetaDasar.halaman(hasil[1], PemetaOrder.pesanChat).isi;

    return PemetaOrder.order(isi, pesan: pesan);
  }

  /// Satu jendela dari sebuah daftar order.
  ///
  /// Selalu halaman pertama, dengan ukuran sebesar jendela yang sedang diminta layar.
  /// Bukan penumpukan halaman satu per satu, dan itu disengaja: daftar ini diambil
  /// ulang setiap lima belas detik, dan halaman yang ditumpuk sendiri akan tertimpa
  /// setiap kali pengambilan ulang itu datang. Meminta jendela yang lebih lebar
  /// membuat setiap pengambilan tetap menghasilkan satu potret yang utuh.
  Future<Halaman<Order>> _daftar(String jalur, int ukuran) async {
    final jawaban = await _klien.get(
      jalur,
      kueri: {'ukuran': '${ukuran.clamp(1, BatasHalaman.maksimal)}'},
    );

    return PemetaDasar.halaman(jawaban, PemetaOrder.order);
  }

  // --- Membuat ---

  @override
  Future<Order> buatOrderJalurA({
    required ServiceType serviceType,
    double? jarakKm,
    String? deskripsi,
    String? alamatJemput,
    String? alamatTujuan,
  }) async {
    final jawaban = await _klien.post(
      '/api/orders/jalur-a',
      badan: {
        'serviceType': _namaServer(serviceType.name),
        'jarakKm': ?jarakKm,
        'deskripsi': ?deskripsi,
        'alamatJemput': ?alamatJemput,
        'alamatTujuan': ?alamatTujuan,
      },
    );

    _tandaiBerubah();
    // Jawabannya membungkus ordernya bersama rincian harga, karena layar
    // pembayaran menampilkan rincian itu.
    return PemetaOrder.order(jawaban['order'] as Map<String, dynamic>);
  }

  @override
  Future<Order> buatPermintaanJalurB({
    required ServiceType serviceType,
    required String deskripsi,
    required DateTime jadwalMulai,
    required int hargaUsulan,
    String? alamatTujuan,
    int jumlahRunnerDibutuhkan = 1,
  }) async {
    final jawaban = await _klien.post(
      '/api/orders/jalur-b',
      badan: {
        'serviceType': _namaServer(serviceType.name),
        'deskripsi': deskripsi,
        'jadwalMulai': jadwalMulai.toUtc().toIso8601String(),
        'alamatTujuan': ?alamatTujuan,
        'jumlahRunnerDibutuhkan': jumlahRunnerDibutuhkan,
        'hargaUsulan': hargaUsulan,
      },
    );

    _tandaiBerubah();
    return PemetaOrder.order(jawaban);
  }

  // --- Menawar (runner) & menjawab penawaran (klien) ---

  @override
  Future<Order> buatPenawaran({
    required String orderId,
    required int harga,
    required Duration estimasiDurasi,
    required DateTime jadwalMulai,
    String? catatan,
  }) => _tindakan(
    '/api/orders/$orderId/penawaran',
    badan: {
      'harga': harga,
      'estimasiDurasiMenit': estimasiDurasi.inMinutes,
      'jadwalMulai': jadwalMulai.toUtc().toIso8601String(),
      'catatan': ?catatan,
    },
  );

  @override
  Future<Order> setujuiPenawaran({
    required String orderId,
    required String penawaranId,
  }) => _tindakan('/api/orders/$orderId/penawaran/$penawaranId/setujui');

  @override
  Future<Order> tolakPenawaran({
    required String orderId,
    required String penawaranId,
  }) => _tindakan('/api/orders/$orderId/penawaran/$penawaranId/tolak');

  @override
  Future<Order> ajukanNego({
    required String orderId,
    required String penawaranId,
    required String alasan,
  }) => _tindakan(
    '/api/orders/$orderId/penawaran/$penawaranId/nego',
    badan: {'alasan': alasan},
  );

  // --- Runner ---

  @override
  Future<bool> terimaOrder({required String orderId}) async {
    final jawaban = await _klien.post('/api/orders/$orderId/terima');
    _tandaiBerubah();
    // Kalah cepat bukan galat, jadi server menjawab 200 dengan penanda di badan.
    return jawaban['dapat'] == true;
  }

  @override
  Future<Order> selesaikanOrder({
    required String orderId,
    required String fotoBuktiUrl,
    String? catatanSerahTerima,
  }) => _tindakan(
    '/api/orders/$orderId/selesai',
    badan: {
      'fotoBuktiUrl': fotoBuktiUrl,
      'catatanSerahTerima': ?catatanSerahTerima,
    },
  );

  @override
  Future<Order> lepasOrder({required String orderId, required String alasan}) =>
      _tindakan('/api/orders/$orderId/lepas', badan: {'alasan': alasan.trim()});

  @override
  Future<Order> batalkanOrder(String orderId) =>
      _tindakan('/api/orders/$orderId/batal');

  // --- Chat ---

  @override
  Future<Order> kirimPesan({
    required String orderId,
    required String isi,
    String? runnerId,
  }) async {
    await _klien.post(
      '/api/orders/$orderId/pesan',
      badan: {'isi': isi, 'runnerId': ?runnerId},
    );
    _tandaiBerubah();

    // Server menjawab dengan pesannya, bukan ordernya, sementara kontrak ini
    // menjanjikan order yang sudah diperbarui. Diambil ulang, bukan ditambal
    // dengan menyisipkan pesan itu ke salinan lama: salinan yang ditambal akan
    // benar sekarang lalu perlahan menyimpang dari keadaan sebenarnya.
    final order = await getOrder(orderId);
    if (order == null) {
      throw StateError('Order $orderId hilang setelah pesan terkirim');
    }
    return order;
  }

  Future<Order> _tindakan(String jalur, {Object? badan}) async {
    final jawaban = await _klien.post(jalur, badan: badan);
    _tandaiBerubah();
    return PemetaOrder.order(jawaban);
  }

  /// Nama enum sebagaimana server menuliskannya: huruf pertama kapital.
  ///
  /// Nama anggotanya sengaja sama persis di kedua sisi, jadi yang perlu diubah
  /// cuma huruf pertamanya, bukan tabel pemetaan yang harus dijaga tetap sinkron.
  static String _namaServer(String nama) =>
      nama[0].toUpperCase() + nama.substring(1);

  void dispose() {
    _langgananLuar?.cancel();
    _perubahan.close();
  }
}
