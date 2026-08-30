import 'dart:async';
import 'dart:math';

import '../../core/config/batas_masukan.dart';
import '../../domain/enums.dart';
import '../../core/config/batas_halaman.dart';
import '../../domain/models/halaman.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_message.dart';
import '../../domain/models/order_offer.dart';
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
        orders
            .where(
              (o) =>
                  o.status == OrderStatus.mencariRunner &&
                  !o.kuotaRunnerPenuh &&
                  // Order yang sudah dipegang runner ini tidak perlu ditawarkan
                  // lagi. Pada order multi-runner kuotanya bisa saja masih
                  // terbuka, tapi slot keduanya bukan untuk orang yang sama.
                  !o.runnerIds.contains(runnerId) &&
                  // Dan ordernya sendiri tidak pernah sampai ke matanya.
                  o.klienId != runnerId,
            )
            .toList(),
      ),
      ukuran,
    );
  });

  @override
  Stream<Halaman<Order>> watchOrderRunner({required int ukuran}) =>
      watchOrderRunnerUntuk(_pemanggil(), ukuran: ukuran);

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
  Stream<Order?> watchOrder(String orderId) =>
      _stream.map((orders) => orders.where((o) => o.id == orderId).firstOrNull);

  @override
  Future<Order?> getOrder(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    return _orders.where((o) => o.id == orderId).firstOrNull;
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
    final tarif = KalkulatorTarif.hitung(serviceType, jarakKm);

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
    String? alamatTujuan,
    int jumlahRunnerDibutuhkan = 1,
  }) async {
    await Future<void>.delayed(_jedaJaringan);

    if (serviceType.track != OrderTrack.jalurB) {
      throw StateError('${serviceType.name} bukan layanan Jalur B');
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
    );
    _orders.add(order);
    _pancarkan();
    return order;
  }

  /// Admin mengirim penawaran harga untuk satu permintaan Jalur B.
  ///
  /// SENGAJA BUKAN BAGIAN DARI [OrderRepository]. Menawar adalah pekerjaan admin,
  /// dan admin bekerja lewat dashboard web; aplikasi ini tidak punya permukaan
  /// admin, jadi tidak punya alasan bisa menawar. Yang memanggilnya cuma panel
  /// alat penguji yang berdiri di tempat dashboard itu, dan panel itu hilang
  /// sendiri di build rilis.
  Future<Order> buatPenawaran({
    required String orderId,
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
    // Hanya permintaan yang belum punya penawaran menunggu yang boleh ditawari.
    // Tanpa syarat ini, penawaran kedua akan diam-diam menimpa penawaran yang
    // sedang dibaca klien, dan klien menekan setuju untuk harga yang berbeda
    // dari yang tampil di layarnya.
    if (order.status != OrderStatus.permintaan) {
      throw StateError(
        'Order ${order.kodeOrder} sedang ${order.status.label}, '
        'bukan permintaan yang menunggu penawaran',
      );
    }
    if (harga <= 0) {
      throw StateError('Harga penawaran harus lebih dari nol');
    }

    final penawaran = OrderOffer(
      id: 'p-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}',
      orderId: orderId,
      harga: harga,
      estimasiDurasi: estimasiDurasi,
      jadwalMulai: jadwalMulai,
      dibuatPada: DateTime.now(),
      status: OfferStatus.pending,
      catatan: catatan,
    );
    // Harga ordernya sengaja tidak diisi di sini: angka itu masih usulan sampai
    // klien menyetujuinya.
    final diperbarui = order.copyWith(
      status: OrderStatus.menungguPersetujuanKlien,
      offers: [...order.offers, penawaran],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> setujuiPenawaran(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibMilikPemanggil(orderId);
    final penawaran = _penawaranMenunggu(order);

    final diperbarui = order.copyWith(
      status: OrderStatus.menungguPembayaran,
      harga: penawaran.harga,
      estimasiDurasi: penawaran.estimasiDurasi,
      jadwalMulai: penawaran.jadwalMulai,
      offers: _gantiPenawaran(order, penawaran, OfferStatus.disetujui),
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> tolakPenawaran(String orderId) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibMilikPemanggil(orderId);
    final penawaran = _penawaranMenunggu(order);

    final diperbarui = order.copyWith(
      status: OrderStatus.batal,
      offers: _gantiPenawaran(order, penawaran, OfferStatus.ditolak),
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  @override
  Future<Order> ajukanNego({
    required String orderId,
    required String alasan,
  }) async {
    await Future<void>.delayed(_jedaJaringan);
    final order = _wajibMilikPemanggil(orderId);
    final penawaran = _penawaranMenunggu(order);

    final bersih = _batasi(alasan, BatasMasukan.alasanNego, 'Alasan nego')!;
    if (bersih.isEmpty) {
      throw StateError(
        'Nego tanpa alasan tidak bisa dikirim, admin tidak punya bahan untuk '
        'menghitung ulang',
      );
    }

    // Alasannya masuk ke chat ordernya, bukan ke kolom tersembunyi di
    // penawaran, supaya admin menjawabnya di tempat yang sama dengan
    // pertanyaan lain tentang order ini.
    final diperbarui = order.copyWith(
      // Kembali ke antrean admin, bukan batal: klien masih berminat.
      status: OrderStatus.permintaan,
      offers: _gantiPenawaran(order, penawaran, OfferStatus.dinegoUlang),
      messages: [
        ...order.messages,
        _pesanBaru(orderId, MessageSender.klien, bersih),
      ],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  /// Penawaran yang sedang menunggu jawaban, atau galat kalau tidak ada.
  ///
  /// Pemeriksaannya di sini, bukan di layar, karena tombol yang disembunyikan
  /// tidak menghentikan siapa pun yang memanggil langsung.
  OrderOffer _penawaranMenunggu(Order order) {
    final penawaran = order.penawaranMenunggu;
    if (penawaran == null) {
      throw StateError(
        'Order ${order.kodeOrder} tidak punya penawaran yang menunggu jawaban',
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

    final runnerBaru = [...order.runnerIds, runnerId];
    final kuotaPenuh = runnerBaru.length >= order.jumlahRunnerDibutuhkan;
    _ganti(
      order.copyWith(
        runnerIds: runnerBaru,
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
  Future<Order> kirimPesan({required String orderId, required String isi}) =>
      kirimPesanSebagai(orderId: orderId, pengirimId: _pemanggil(), isi: isi);

  /// [kirimPesan] dengan pengirim yang disebutkan langsung, untuk tes.
  Future<Order> kirimPesanSebagai({
    required String orderId,
    required String pengirimId,
    required String isi,
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

    final diperbarui = order.copyWith(
      messages: [...order.messages, _pesanBaru(orderId, peran, bersih)],
    );
    _ganti(diperbarui);
    return diperbarui;
  }

  /// Peran seseorang pada satu order, atau `null` kalau ia bukan siapa-siapa di
  /// sana.
  ///
  /// Diturunkan dari hubungannya dengan ordernya, tidak pernah disebutkan
  /// pemanggil. Penugasan runner diperiksa sebelum peran admin: founder mitra
  /// memegang keduanya, dan kalau ia yang mengambil ordernya, ia sedang bekerja
  /// sebagai runner di sana.
  MessageSender? _peranPada(Order order, String pengirimId) {
    if (order.klienId == pengirimId) return MessageSender.klien;
    if (order.runnerIds.contains(pengirimId)) return MessageSender.runner;

    final user = SeedData.semuaUser
        .where((u) => u.id == pengirimId)
        .firstOrNull;
    if (user != null && user.isAdmin) return MessageSender.admin;
    return null;
  }

  OrderMessage _pesanBaru(
    String orderId,
    MessageSender pengirim,
    String isi,
  ) => OrderMessage(
    id: 'm-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(999)}',
    orderId: orderId,
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
}
