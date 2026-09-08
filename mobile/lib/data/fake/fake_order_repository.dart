import 'dart:async';
import 'dart:math';

import '../../core/config/batas_masukan.dart';
import '../../domain/enums.dart';
import '../../core/config/batas_halaman.dart';
import '../../domain/models/halaman.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_message.dart';
import '../../domain/models/order_offer.dart';
import '../../domain/models/runner_ringkas.dart';
import '../../domain/models/tarif.dart';
import '../../domain/pricing/kalkulator_tarif.dart';
import '../../domain/repositories/order_repository.dart';
import 'seed_data.dart';

/// Implementasi [OrderRepository] yang menyimpan semuanya di memori.
///
/// Dipakai supaya seluruh antarmuka bisa dibangun dan diuji sebelum backend
/// tersambung. Setiap operasi diberi jeda kecil agar layar benar-benar melewati
/// keadaan memuat, bug "lupa menangani loading" jadi ketahuan sekarang.
///
/// Karena kontraknya tidak lagi menerima identitas pemanggil, tiruan ini butuh
/// cara lain mengetahuinya, dan itu [pemanggil]. Di aplikasi ia dipasang ke user
/// yang sedang masuk; di tes ia diisi langsung. Beberapa method punya kembaran
/// berakhiran `Sebagai` yang menerima id secara eksplisit, khusus untuk tes yang
/// perlu menirukan lebih dari satu orang sekaligus, misalnya dua runner yang
/// menekan TERIMA pada saat yang sama.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({List<Order>? orderAwal, String Function()? pemanggil})
    : _orders = List.of(orderAwal ?? SeedData.orderAwal()),
      _pemanggil = pemanggil ?? (() => SeedData.klien.id);

  static const Duration _jedaJaringan = Duration(milliseconds: 350);

  final List<Order> _orders;
  final String Function() _pemanggil;
  final StreamController<List<Order>> _controller =
      StreamController<List<Order>>.broadcast();
  final Random _random = Random();

  int _nomorUrut = 412;

  /// Snapshot sekarang lalu setiap perubahan sesudahnya.
  Stream<List<Order>> get _stream async* {
    yield List.unmodifiable(_orders);
    yield* _controller.stream;
  }

  void _pancarkan() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_orders));
    }
  }

  void _ganti(Order baru) {
    final indeks = _orders.indexWhere((o) => o.id == baru.id);
    if (indeks == -1) {
      throw StateError('Order ${baru.id} tidak ditemukan');
    }
    _orders[indeks] = baru;
    _pancarkan();
  }

  /// Memeriksa panjang satu isian teks bebas.
  ///
  /// Dipanggil dari repository, bukan dari layar, karena kolom yang dibatasi
  /// `maxLength` tetap bisa diisi lewat tempel, dan lewat pemanggilan API
  /// langsung. Mengembalikan teks yang sudah dirapikan supaya pemanggil tidak
  /// perlu memangkas dua kali.
  static String? _batasi(String? nilai, int batas, String namaIsian) {
    if (nilai == null) return null;
    final bersih = nilai.trim();
    if (bersih.length > batas) {
      throw StateError('$namaIsian maksimal $batas karakter');
    }
    return bersih;
  }

  Order _wajibAda(String orderId) {
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) {
      throw StateError('Order $orderId tidak ditemukan');
    }
    return order;
  }

  /// Order yang pemanggilnya memang pemesannya.
  ///
  /// Order milik orang lain diperlakukan sebagai tidak ada, mengikuti server yang
  /// menjawab 404 untuk keduanya.
  Order _wajibMilikPemanggil(String orderId) {
    final order = _wajibAda(orderId);
    if (order.klienId != _pemanggil()) {
      throw StateError('Order $orderId tidak ditemukan');
    }
    return order;
  }

  static List<Order> _terbaruDiAtas(List<Order> orders) =>
      List.of(orders)..sort((a, b) => b.dibuatPada.compareTo(a.dibuatPada));

  @override
  Stream<Halaman<Order>> watchOrderKlien({required int ukuran}) =>
      watchOrderKlienUntuk(_pemanggil(), ukuran: ukuran);

  /// [watchOrderKlien] untuk klien yang disebutkan langsung, untuk tes.
  Stream<Halaman<Order>> watchOrderKlienUntuk(
    String klienId, {
    int ukuran = BatasHalaman.maksimal,
  }) => _stream.map(
    (orders) => _jendela(
      _terbaruDiAtas(orders.where((o) => o.klienId == klienId).toList()),
      ukuran,
    ),
  );

  @override
  Stream<Halaman<Order>> watchOrderTersiar({required int ukuran}) =>
      watchOrderTersiarUntuk(_pemanggil(), ukuran: ukuran);

  /// [watchOrderTersiar] untuk runner yang disebutkan langsung, untuk tes.
  Stream<Halaman<Order>> watchOrderTersiarUntuk(
    String runnerId, {
    int ukuran = BatasHalaman.maksimal,
  }) => _stream.map((orders) {
    return _jendela(
      _terbaruDiAtas(
        orders.where((o) => _tersiarUntuk(o, runnerId)).toList(),
      ),
      ukuran,
    );
  });

  /// Order ini pantas muncul di daftar siaran runner tersebut.
  ///
  /// Dua jenis siaran berbeda tercampur di sini. Jalur A (dan sisa kuota
  /// Jalur B setelah pemenang tawaran mengisi satu slot) disiarkan begitu
  /// dibayar, siapa cepat dia dapat. Jalur B yang masih menunggu penawaran
  /// disiarkan sejak permintaan dibuat, dan yang "diklaim" runner di sana
  /// kesempatan menawar, bukan pekerjaan siap kerja.
  static bool _tersiarUntuk(Order o, String runnerId) {
    // Ordernya sendiri tidak pernah sampai ke matanya.
    if (o.klienId == runnerId) return false;

    if (o.track == OrderTrack.jalurB && o.status == OrderStatus.permintaan) {
      // Runner yang penawarannya masih menunggu tidak perlu ditawarkan lagi.
      // Yang sudah ditolak/ditutup/dinego boleh menawar ulang.
      final miliknya = o.penawaranMilikRunner(runnerId);
      return miliknya == null || miliknya.status != OfferStatus.pending;
    }

    return o.status == OrderStatus.mencariRunner &&
        !o.kuotaRunnerPenuh &&
        // Order yang sudah dipegang runner ini tidak perlu ditawarkan lagi.
        // Pada order multi-runner kuotanya bisa saja masih terbuka, tapi
        // slot keduanya bukan untuk orang yang sama.
        !o.runnerIds.contains(runnerId);
  }

  @override
  Stream<Halaman<Order>> watchOrderRunner({required int ukuran}) =>
      watchOrderRunnerUntuk(_pemanggil(), ukuran: ukuran);

  @override
  Stream<Halaman<Order>> watchTawaranSaya({required int ukuran}) =>
      watchTawaranUntuk(_pemanggil(), ukuran: ukuran);

  /// [watchTawaranSaya] untuk runner yang disebutkan langsung, untuk tes.
  ///
  /// Yang dihitung "masih hidup" sama dengan aturan di server: menunggu jawaban,
  /// diminta dihitung ulang, atau sudah disetujui tapi ordernya belum dibayar. Yang
  /// sudah punya penugasan dikeluarkan, karena order itu sudah pindah ke daftar order
  /// yang dipegang.
  Stream<Halaman<Order>> watchTawaranUntuk(
    String runnerId, {
    int ukuran = BatasHalaman.maksimal,
  }) => _stream.map(
    (orders) => _jendela(
      _terbaruDiAtas(
        orders
            .where(
              (o) =>
                  !o.runnerIds.contains(runnerId) &&
                  o.offers.any(
                    (f) =>
                        f.runnerId == runnerId &&
                        (f.status == OfferStatus.pending ||
                            f.status == OfferStatus.dinegoUlang ||
                            f.status == OfferStatus.disetujui),
                  ),
            )
            .toList(),
      ),
      ukuran,
    ),
  );

  /// [watchOrderRunner] untuk runner yang disebutkan langsung, untuk tes.
  Stream<Halaman<Order>> watchOrderRunnerUntuk(
    String runnerId, {
    int ukuran = BatasHalaman.maksimal,
  }) => _stream.map(
    (orders) => _jendela(
      _terbaruDiAtas(
        orders.where((o) => o.runnerIds.contains(runnerId)).toList(),
      ),
      ukuran,
    ),
  );

  /// Memotong daftar sepanjang jendela yang diminta, sambil menyimpan jumlah utuhnya.
  ///
  /// Ditirukan, bukan diabaikan, walaupun data karangan tidak akan pernah sepanjang
  /// itu. Tiruan yang selalu mengirim semuanya membuat layar dibangun dan diuji di
  /// atas asumsi yang tidak berlaku di server, dan tombol muat lagi adalah bagian
  /// layar yang paling mungkin salah karenanya.
  static Halaman<Order> _jendela(List<Order> semua, int ukuran) =>
      Halaman(isi: semua.take(ukuran).toList(), total: semua.length);

  @override
  Stream<Order?> watchOrder(String orderId, {int ukuranPesan = BatasHalaman.bawaan}) =>
      _stream.map(
        (orders) => _jendelaPesan(
          orders.where((o) => o.id == orderId).firstOrNull,
          ukuranPesan,
        ),
      );

  /// Memotong percakapan sepanjang jendelanya, terbaru yang dipertahankan.
  ///
  /// Ditirukan seperti pemotongan daftar order, dengan alasan yang sama: tiruan yang
  /// selalu mengirim semuanya membuat layar diuji di atas asumsi yang tidak berlaku
  /// di server. `jumlahPesan` sengaja tidak ikut dipotong, karena angka itu memang
  /// menyebut seluruhnya, dan dari selisih itulah layar tahu masih ada yang lebih lama.
  static Order? _jendelaPesan(Order? order, int ukuran) {
    if (order == null || order.messages.length <= ukuran) return order;

    return order.copyWith(
      messages: order.messages.sublist(order.messages.length - ukuran),
    );
  }

  @override
  Future<Order?> getOrder(String orderId, {int ukuranPesan = BatasHalaman.bawaan}) async {
    await Future<void>.delayed(_jedaJaringan);
    return _jendelaPesan(
      _orders.where((o) => o.id == orderId).firstOrNull,
      ukuranPesan,
    );
  }

  @override
  Future<Order> buatOrderJalurA({
    required ServiceType serviceType,
    double? jarakKm,
    String? deskripsi,
    String? alamatJemput,
    String? alamatTujuan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);

    if (serviceType.track != OrderTrack.jalurA) {
      throw StateError('${serviceType.name} bukan layanan Jalur A');
    }

    final deskripsiBersih = _batasi(
      deskripsi,
      BatasMasukan.deskripsi,
      'Deskripsi',
    );
    final jemputBersih = _batasi(
      alamatJemput,
      BatasMasukan.alamat,
      'Alamat jemput',
    );
    final tujuanBersih = _batasi(
      alamatTujuan,
      BatasMasukan.alamat,
      'Alamat tujuan',
    );

    // Harganya dihitung di sini, bukan diterima dari pemanggil, sama seperti di
    // server. Tiruan yang menerima harga jadi akan membuat layar dibangun dengan
    // asumsi yang tidak berlaku di sana.
    final tarif = KalkulatorTarif.hitung(serviceType, jarakKm, Tarif.bawaan);

    final klienId = _pemanggil();
    final order = Order(
      id: _idBaru(),
      kodeOrder: _kodeOrderBaru(),
      klienId: klienId,
      namaKlien: _namaKlien(klienId),
      serviceType: serviceType,
      // Jalur A melewati dua status pertama, harga sudah pasti sejak awal.
      status: OrderStatus.menungguPembayaran,
      dibuatPada: DateTime.now(),
      deskripsi: deskripsiBersih,
      alamatJemput: jemputBersih,
      alamatTujuan: tujuanBersih,
      harga: tarif.total,
    );
    _orders.add(order);
    _pancarkan();
    return order;
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
    await Future<void>.delayed(_jedaJaringan);

    if (serviceType.track != OrderTrack.jalurB) {
      throw StateError('${serviceType.name} bukan layanan Jalur B');
    }
    if (hargaUsulan <= 0) {
      throw StateError('Harga usulan harus lebih dari nol');
    }

    final deskripsiBersih = _batasi(
      deskripsi,
      BatasMasukan.deskripsi,
      'Deskripsi',
    )!;
    final tujuanBersih = _batasi(
      alamatTujuan,
      BatasMasukan.alamat,
      'Alamat tujuan',
    );

    final klienId = _pemanggil();
    final order = Order(
      id: _idBaru(),
      kodeOrder: _kodeOrderBaru(),
      klienId: klienId,
      namaKlien: _namaKlien(klienId),
      serviceType: serviceType,
      status: OrderStatus.permintaan,
      dibuatPada: DateTime.now(),
      deskripsi: deskripsiBersih,
      alamatTujuan: tujuanBersih,
      jadwalMulai: jadwalMulai,
      jumlahRunnerDibutuhkan: jumlahRunnerDibutuhkan,
      hargaUsulan: hargaUsulan,
    );
    _orders.add(order);
    _pancarkan();
    return order;
  }

  @override
  Future<Order> buatPenawaran({
    required String orderId,
    required int harga,
    required Duration estimasiDurasi,
    required DateTime jadwalMulai,
    String? catatan,
  }) => buatPenawaranSebagai(
    orderId: orderId,
    runnerId: _pemanggil(),
    harga: harga,
    estimasiDurasi: estimasiDurasi,
    jadwalMulai: jadwalMulai,
    catatan: catatan,
  );

  /// [buatPenawaran] dengan runner yang disebutkan langsung, untuk tes.
  ///
  /// Untuk tes yang perlu menirukan beberapa runner menawar order yang sama
  /// dari satu instance repository, yang tidak bisa dinyatakan lewat satu
  /// pemanggil tunggal.
  Future<Order> buatPenawaranSebagai({
    required String orderId,
    required String runnerId,
    required int harga,
    required Duration estimasiDurasi,
    required DateTime jadwalMulai,
    String? catatan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);

    if (order.track != OrderTrack.jalurB) {
      throw StateError(
        'Order ${order.kodeOrder} bukan Jalur B, harganya sudah pasti sejak '
        'order dibuat',
      );
    }
    // Klien yang akun yang sama juga menyandang peran runner tidak boleh
    // menawar ordernya sendiri.
    if (order.klienId == runnerId) {
      throw StateError('Tidak bisa menawar order sendiri');
    }
    // Order yang masih menerima penawaran selalu berstatus Permintaan, tidak
    // peduli sudah ada berapa banyak penawaran pending di dalamnya. Status
    // berubah hanya ketika klien sudah memilih satu.
    if (order.status != OrderStatus.permintaan) {
      throw StateError(
        'Order ${order.kodeOrder} sedang ${order.status.label}, '
        'bukan permintaan yang menerima penawaran',
      );
    }
    if (harga <= 0) {
      throw StateError('Harga penawaran harus lebih dari nol');
    }
    // Satu runner tidak boleh punya dua penawaran yang sama-sama menunggu
    // jawaban pada order yang sama. Runner LAIN tetap boleh punya penawaran
    // pending miliknya sendiri pada saat bersamaan, itu bukan tabrakan, itu
    // memang tawar-menawar.
    if (order.offers.any(
      (o) => o.runnerId == runnerId && o.status == OfferStatus.pending,
    )) {
      throw StateError(
        'Anda sudah punya penawaran yang menunggu jawaban untuk order ini',
      );
    }

    final identitasRunner = _runnerRingkas(runnerId);
    final penawaran = OrderOffer(
      id: 'p-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}',
      orderId: orderId,
      runnerId: runnerId,
      namaRunner: identitasRunner.nama,
      noHpRunner: identitasRunner.noHp,
      harga: harga,
      estimasiDurasi: estimasiDurasi,
      jadwalMulai: jadwalMulai,
      dibuatPada: DateTime.now(),
      status: OfferStatus.pending,
      catatan: catatan,
    );
    // Status ordernya sengaja tidak berubah: runner lain masih boleh menawar
    // selama klien belum memilih siapa pun.
    final diperbarui = order.copyWith(offers: [...order.offers, penawaran]);
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> setujuiPenawaran({
    required String orderId,
    required String penawaranId,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibMilikPemanggil(orderId);
    final penawaran = _penawaranPendingById(order, penawaranId);

    final diperbarui = order.copyWith(
      status: OrderStatus.menungguPembayaran,
      harga: penawaran.harga,
      estimasiDurasi: penawaran.estimasiDurasi,
      jadwalMulai: penawaran.jadwalMulai,
      // Penawaran yang dipilih jadi disetujui, sisanya yang masih menunggu
      // otomatis ditutup: runner yang tidak terpilih tidak menggantung tanpa
      // kabar.
      offers: [
        for (final o in order.offers)
          if (o.id == penawaran.id)
            o.copyWith(status: OfferStatus.disetujui)
          else if (o.status == OfferStatus.pending)
            o.copyWith(status: OfferStatus.ditutup)
          else
            o,
      ],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> tolakPenawaran({
    required String orderId,
    required String penawaranId,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibMilikPemanggil(orderId);
    final penawaran = _penawaranPendingById(order, penawaranId);

    // Beda dari alur admin lama: menolak satu penawaran tidak mengakhiri
    // ordernya, dan tidak menyentuh penawaran runner lain yang masih
    // menunggu.
    final diperbarui = order.copyWith(
      offers: _gantiPenawaran(order, penawaran, OfferStatus.ditolak),
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> ajukanNego({
    required String orderId,
    required String penawaranId,
    required String alasan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibMilikPemanggil(orderId);
    final penawaran = _penawaranPendingById(order, penawaranId);

    final bersih = _batasi(alasan, BatasMasukan.alasanNego, 'Alasan nego')!;
    if (bersih.isEmpty) {
      throw StateError(
        'Nego tanpa alasan tidak bisa dikirim, runner tidak punya bahan '
        'untuk menghitung ulang',
      );
    }

    // Alasannya masuk ke jalur obrolan pribadi runner ini, bukan ke kolom
    // tersembunyi di penawaran, supaya runner menjawabnya di tempat yang sama
    // dengan pertanyaan lain tentang tawarannya. Runner ini bebas mengirim
    // penawaran baru sesudahnya, karena yang lama sudah tidak Pending lagi.
    final diperbarui = order.copyWith(
      offers: _gantiPenawaran(order, penawaran, OfferStatus.dinegoUlang),
      messages: [
        ...order.messages,
        _pesanBaru(
          orderId,
          MessageSender.klien,
          bersih,
          runnerId: penawaran.runnerId,
        ),
      ],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  /// Satu penawaran tertentu yang masih menunggu jawaban, atau galat kalau
  /// tidak ada/sudah dijawab.
  ///
  /// Pemeriksaannya di sini, bukan di layar, karena tombol yang disembunyikan
  /// tidak menghentikan siapa pun yang memanggil langsung.
  static OrderOffer _penawaranPendingById(Order order, String penawaranId) {
    final penawaran = order.offers
        .where((o) => o.id == penawaranId && o.status == OfferStatus.pending)
        .firstOrNull;
    if (penawaran == null) {
      throw StateError(
        'Order ${order.kodeOrder} tidak punya penawaran menunggu dengan id '
        'itu; mungkin sudah dijawab atau ditutup',
      );
    }
    return penawaran;
  }

  static List<OrderOffer> _gantiPenawaran(
    Order order,
    OrderOffer penawaran,
    OfferStatus status,
  ) {
    return [
      for (final o in order.offers)
        if (o.id == penawaran.id) o.copyWith(status: status) else o,
    ];
  }

  /// Menandai order lunas lalu menyiarkannya ke runner.
  ///
  /// SENGAJA BUKAN BAGIAN DARI [OrderRepository]. Uang yang masuk adalah kejadian
  /// di luar aplikasi, jadi yang boleh mengabarkannya adalah pihak yang menerima
  /// uangnya. Di server ini webhook gateway, dan aplikasi tidak punya jalan ke
  /// sana. Yang memanggilnya di sini cuma tiruan gateway, yang hilang sendiri di
  /// build rilis.
  Future<Order> tandaiSudahDibayar(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);
    if (order.status != OrderStatus.menungguPembayaran) {
      throw StateError(
        'Order ${order.kodeOrder} tidak sedang menunggu pembayaran '
        '(status sekarang: ${order.status.label})',
      );
    }

    if (order.track == OrderTrack.jalurB) {
      // Jalur B sudah punya pemenang tawaran pertamanya sejak klien
      // menyetujui satu penawaran runner, jauh sebelum pembayaran ini. Runner
      // itu langsung diberi satu slot penugasan di sini, tanpa rebutan.
      final disetujui = order.offers
          .where((o) => o.status == OfferStatus.disetujui)
          .firstOrNull;
      if (disetujui == null) {
        throw StateError(
          'Order ${order.kodeOrder} lunas tapi tidak ada penawaran yang '
          'disetujui',
        );
      }

      final runnerBaru = [
        ...order.runners,
        RunnerRingkas(
          id: disetujui.runnerId,
          nama: disetujui.namaRunner,
          noHp: disetujui.noHpRunner,
        ),
      ];
      final kuotaPenuh = runnerBaru.length >= order.jumlahRunnerDibutuhkan;
      final diperbarui = order.copyWith(
        runners: runnerBaru,
        // Satu slot yang dibutuhkan sudah terisi oleh pemenang tawaran itu
        // sendiri kalau kuotanya cuma satu orang. Kalau butuh lebih (misal
        // pindahan kos), sisa slotnya tetap disiarkan persis seperti Jalur A.
        status: kuotaPenuh ? OrderStatus.dikerjakan : OrderStatus.mencariRunner,
        dibayarPada: DateTime.now(),
      );
      _ganti(diperbarui);
      return diperbarui;
    }

    final diperbarui = order.copyWith(
      status: OrderStatus.mencariRunner,
      dibayarPada: DateTime.now(),
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<bool> terimaOrder({required String orderId}) =>
      terimaOrderSebagai(orderId: orderId, runnerId: _pemanggil());

  /// [terimaOrder] dengan runner yang disebutkan langsung.
  ///
  /// Untuk tes yang perlu menirukan dua runner menekan TERIMA pada saat yang
  /// sama, yang tidak bisa dinyatakan lewat satu pemanggil tunggal.
  Future<bool> terimaOrderSebagai({
    required String orderId,
    required String runnerId,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);

    // Pemesan tidak boleh menjadi runner ordernya sendiri. Melempar, bukan
    // mengembalikan `false`, karena ini bukan kalah cepat: hasilnya tidak akan
    // berubah walau dicoba seribu kali.
    if (order.klienId == runnerId) {
      throw StateError(
        'Pemesan order ${order.kodeOrder} tidak bisa menerima ordernya sendiri',
      );
    }

    // Cerminan dari UPDATE ... WHERE status = MENCARI_RUNNER di basis data:
    // kalau syaratnya tidak lagi terpenuhi, runner ini kalah cepat.
    if (order.status != OrderStatus.mencariRunner) return false;
    if (order.kuotaRunnerPenuh) return false;
    if (order.runnerIds.contains(runnerId)) return false;

    final runnerBaru = [...order.runners, _runnerRingkas(runnerId)];
    final kuotaPenuh = runnerBaru.length >= order.jumlahRunnerDibutuhkan;
    _ganti(
      order.copyWith(
        runners: runnerBaru,
        status: kuotaPenuh ? OrderStatus.dikerjakan : OrderStatus.mencariRunner,
      ),
    );
    return true;
  }

  @override
  Future<Order> selesaikanOrder({
    required String orderId,
    required String fotoBuktiUrl,
    String? catatanSerahTerima,
  }) => selesaikanOrderSebagai(
    orderId: orderId,
    runnerId: _pemanggil(),
    fotoBuktiUrl: fotoBuktiUrl,
    catatanSerahTerima: catatanSerahTerima,
  );

  /// [selesaikanOrder] dengan runner yang disebutkan langsung, untuk tes.
  Future<Order> selesaikanOrderSebagai({
    required String orderId,
    required String runnerId,
    required String fotoBuktiUrl,
    String? catatanSerahTerima,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);

    // Yang berhak menutup order hanya runner yang memegangnya. Pemeriksaan itu
    // tempatnya di sini, bukan di layar: tombol yang disembunyikan tidak
    // menghentikan siapa pun yang memanggil langsung.
    if (!order.runnerIds.contains(runnerId)) {
      throw StateError(
        'Runner $runnerId tidak memegang order ${order.kodeOrder}',
      );
    }
    if (order.status != OrderStatus.dikerjakan) {
      throw StateError(
        'Order ${order.kodeOrder} belum dikerjakan, tidak bisa diselesaikan',
      );
    }
    if (fotoBuktiUrl.trim().isEmpty) {
      throw StateError(
        'Foto bukti wajib ada, itu yang membedakan pekerjaan selesai dari '
        'pengakuan selesai',
      );
    }
    final catatanBersih = _batasi(
      catatanSerahTerima,
      BatasMasukan.catatanSerahTerima,
      'Catatan serah terima',
    );

    // Pada order multi-runner, runner mana pun yang ditugaskan boleh menutup
    // order. Ini keputusan sementara: siapa yang berhak menekan selesai kalau
    // pekerjaannya dibagi tiga orang masih menunggu jawaban mitra (bagian
    // 14.7d).
    final diperbarui = order.copyWith(
      status: OrderStatus.selesai,
      fotoBuktiUrl: fotoBuktiUrl.trim(),
      catatanSerahTerima: catatanBersih,
      selesaiPada: DateTime.now(),
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> cabutPenawaran({
    required String orderId,
    required String penawaranId,
    String? alasan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);
    final runnerId = _pemanggil();

    final penawaran = order.offers
        .where((f) => f.id == penawaranId && f.runnerId == runnerId)
        .firstOrNull;

    if (penawaran == null) {
      throw StateError('Penawaran itu bukan milikmu');
    }

    // Yang sudah disetujui tidak bisa ditarik: harga ordernya sudah ditetapkan dari
    // tawaran itu dan klien mungkin sedang membayarnya.
    if (penawaran.status != OfferStatus.pending &&
        penawaran.status != OfferStatus.dinegoUlang) {
      throw StateError('Penawaran ini sudah ${penawaran.status.label}');
    }

    final bersih = alasan?.trim();

    final diperbarui = order.copyWith(
      offers: _gantiPenawaran(order, penawaran, OfferStatus.dicabut),
      messages: bersih == null || bersih.isEmpty
          ? order.messages
          : [
              ...order.messages,
              _pesanBaru(
                orderId,
                MessageSender.runner,
                bersih,
                runnerId: runnerId,
              ),
            ],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> lepasOrder({
    required String orderId,
    required String alasan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);
    final runnerId = _pemanggil();

    if (!order.runnerIds.contains(runnerId)) {
      throw StateError('Order ${order.kodeOrder} bukan pekerjaanmu');
    }

    // Order yang sudah selesai atau batal tidak bisa dilepas: mengembalikannya ke
    // mencari runner berarti pekerjaan yang sudah diserahkan disiarkan ulang untuk
    // dikerjakan kedua kalinya.
    if (order.status != OrderStatus.mencariRunner &&
        order.status != OrderStatus.dikerjakan) {
      throw StateError('Order ${order.kodeOrder} sudah ${order.status.label}');
    }

    if (alasan.trim().isEmpty) {
      throw StateError('Alasan melepas order wajib diisi');
    }

    final diperbarui = order.copyWith(
      status: OrderStatus.mencariRunner,
      runners: [...order.runners]..removeWhere((r) => r.id == runnerId),
      messages: [
        ...order.messages,
        _pesanBaru(orderId, MessageSender.runner, alasan.trim()),
      ],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> mintaBatalOrder({
    required String orderId,
    required String alasan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibMilikPemanggil(orderId);

    if (!order.status.isAktif) {
      throw StateError('Order ${order.kodeOrder} sudah ${order.status.label}');
    }

    // Order yang belum dibayar bisa dibatalkan sendiri saat itu juga, jadi tidak ada
    // yang perlu diminta ke admin.
    if (order.dibayarPada == null) {
      throw StateError(
        'Order ${order.kodeOrder} belum dibayar, batalkan saja sendiri',
      );
    }

    if (order.mintaBatalPada != null) {
      throw StateError(
        'Permintaan pembatalan order ${order.kodeOrder} sedang menunggu admin',
      );
    }

    if (alasan.trim().isEmpty) {
      throw StateError('Alasan permintaan pembatalan wajib diisi');
    }

    // Statusnya sengaja tidak digeser: ordernya tetap berjalan sampai admin
    // memutuskan, sama seperti di server.
    final diperbarui = order.copyWith(
      mintaBatalPada: DateTime.now(),
      messages: [
        ...order.messages,
        _pesanBaru(orderId, MessageSender.klien, alasan.trim()),
      ],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> batalkanOrder(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibMilikPemanggil(orderId);

    if (!order.status.isAktif) {
      throw StateError('Order ${order.kodeOrder} sudah ${order.status.label}');
    }
    // Pembatalan setelah pembayaran menyangkut pengembalian uang, dan itu tidak
    // boleh terjadi sebagai efek samping satu tombol.
    if (order.dibayarPada != null) {
      throw StateError(
        'Order ${order.kodeOrder} sudah dibayar, pembatalannya lewat admin',
      );
    }

    final diperbarui = order.copyWith(status: OrderStatus.batal);
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<void> tandaiPesanDibaca({required String orderId, String? runnerId}) async {
    // Tanpa efek: data contoh tidak pernah mengisi jumlahPesanBelumDibaca sama
    // sekali, jadi tidak ada apa pun yang perlu ditandai di sini.
  }

  @override
  Future<Order> kirimPesan({
    required String orderId,
    required String isi,
    String? runnerId,
  }) => kirimPesanSebagai(
    orderId: orderId,
    pengirimId: _pemanggil(),
    isi: isi,
    runnerId: runnerId,
  );

  /// [kirimPesan] dengan pengirim yang disebutkan langsung, untuk tes.
  Future<Order> kirimPesanSebagai({
    required String orderId,
    required String pengirimId,
    required String isi,
    String? runnerId,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibAda(orderId);

    final peran = _peranPada(order, pengirimId);
    if (peran == null) {
      throw StateError('Order $orderId tidak ditemukan');
    }

    final bersih = _batasi(isi, BatasMasukan.pesanChat, 'Pesan')!;
    if (bersih.isEmpty) {
      throw StateError('Pesan kosong tidak bisa dikirim');
    }
    // Order yang sudah selesai atau batal tidak boleh dihidupkan lagi lewat
    // chat. Kalau masih ada urusan, urusan itu butuh order baru atau campur
    // tangan admin, bukan percakapan yang menempel pada pekerjaan yang sudah
    // ditutup.
    if (!order.status.isAktif) {
      throw StateError(
        'Order ${order.kodeOrder} sudah ${order.status.label}, '
        'chatnya ikut ditutup',
      );
    }

    final jalur = _jalurObrolan(order, pengirimId, peran, runnerId);
    final diperbarui = order.copyWith(
      messages: [
        ...order.messages,
        _pesanBaru(orderId, peran, bersih, runnerId: jalur),
      ],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  /// Jalur obrolan mana yang berlaku untuk satu pemanggil pada satu order:
  /// `null` untuk obrolan umum, atau id runner pemilik jalur obrolan pribadi
  /// Jalur B.
  ///
  /// Runner yang belum diterima (masih menawar) selalu memakai jalurnya
  /// sendiri, dan [diminta] tidak pernah dipercaya untuknya. Klien memakai
  /// jalur yang diminta, karena ialah satu-satunya pihak yang boleh bicara di
  /// lebih dari satu jalur pada order yang sama (satu per runner yang
  /// menawar). Runner yang sudah diterima dan admin selalu memakai obrolan
  /// umum.
  static String? _jalurObrolan(
    Order order,
    String pengirimId,
    MessageSender peran,
    String? diminta,
  ) {
    final sudahDiterima = order.runnerIds.contains(pengirimId);
    final sedangMenawar =
        !sudahDiterima &&
        order.offers.any((o) => o.runnerId == pengirimId);

    if (sedangMenawar) return pengirimId;
    if (peran == MessageSender.klien) return diminta;
    return null;
  }

  /// Peran seseorang pada satu order, atau `null` kalau ia bukan siapa-siapa di
  /// sana.
  ///
  /// Diturunkan dari hubungannya dengan ordernya, tidak pernah disebutkan
  /// pemanggil. Penugasan runner diperiksa sebelum peran admin: founder mitra
  /// memegang keduanya, dan kalau ia yang mengambil ordernya, ia sedang bekerja
  /// sebagai runner di sana. Runner yang belum diterima tapi sudah mengajukan
  /// penawaran juga dianggap runner di order ini, supaya ia bisa bertanya
  /// lewat chat sebelum klien memutuskan.
  MessageSender? _peranPada(Order order, String pengirimId) {
    if (order.klienId == pengirimId) return MessageSender.klien;
    if (order.runnerIds.contains(pengirimId)) return MessageSender.runner;
    if (order.offers.any((o) => o.runnerId == pengirimId)) {
      return MessageSender.runner;
    }

    final user = SeedData.semuaUser
        .where((u) => u.id == pengirimId)
        .firstOrNull;
    if (user != null && user.isAdmin) return MessageSender.admin;
    return null;
  }

  OrderMessage _pesanBaru(
    String orderId,
    MessageSender pengirim,
    String isi, {
    String? runnerId,
  }) => OrderMessage(
    id: 'm-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}',
    orderId: orderId,
    runnerId: runnerId,
    pengirim: pengirim,
    isi: isi,
    dikirimPada: DateTime.now(),
  );

  void dispose() => _controller.close();

  String _idBaru() =>
      'o-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}';

  String _kodeOrderBaru() => 'SRH-${(_nomorUrut++).toString().padLeft(4, '0')}';

  String _namaKlien(String klienId) =>
      SeedData.semuaUser.where((u) => u.id == klienId).firstOrNull?.nama ??
      'Klien';

  RunnerRingkas _runnerRingkas(String runnerId) {
    final user = SeedData.semuaUser.where((u) => u.id == runnerId).firstOrNull;
    return RunnerRingkas(
      id: runnerId,
      nama: user?.nama ?? 'Runner',
      noHp: user?.noHp,
    );
  }
}
