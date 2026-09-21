import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/core/api/galat_api.dart';
import 'package:upnvj_suruh/core/config/batas_halaman.dart';
import 'package:upnvj_suruh/core/theme/app_theme.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/domain/models/order_offer.dart';
import 'package:upnvj_suruh/features/runner/ajukan_tawaran/ajukan_tawaran_screen.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

import '../../support/tiruan.dart';

/// Tawaran yang sudah dikirim runner, dan cara menariknya kembali.
///
/// Sebelum bagian ini ada, runner menekan kirim lalu tidak punya apa-apa: ordernya
/// keluar dari Order Masuk begitu ia menawar, dan tidak pernah masuk ke daftar order
/// yang ia pegang. Tawarannya lenyap dari pandangannya, termasuk kabar bahwa klien
/// meminta harganya dihitung ulang.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// Permintaan Jalur B yang sudah ditawar runner contoh, dengan status yang diminta.
  Order permintaanDitawar({OfferStatus status = OfferStatus.pending}) {
    final sekarang = DateTime.now();

    return Order(
      id: 'o-tawar',
      kodeOrder: 'SRH-9101',
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.bersihKos,
      status: OrderStatus.permintaan,
      dibuatPada: sekarang.subtract(const Duration(minutes: 5)),
      deskripsi: 'Kos dua kamar.',
      hargaUsulan: 150000,
      offers: [
        OrderOffer(
          id: 'f-1',
          orderId: 'o-tawar',
          runnerId: SeedData.runner.id,
          namaRunner: SeedData.runner.nama,
          noHpRunner: SeedData.runner.noHp,
          harga: 50000,
          estimasiDurasi: const Duration(hours: 3),
          jadwalMulai: sekarang.add(const Duration(days: 2)),
          dibuatPada: sekarang,
          status: status,
        ),
      ],
    );
  }

  Future<void> bukaOrderSaya(
    WidgetTester tester, {
    required List<Order> orderAwal,
  }) async {
    final orderRepo = FakeOrderRepository(
      pemanggil: () => SeedData.runner.id,
      orderAwal: orderAwal,
    );
    addTearDown(orderRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          orderRepositoryProvider.overrideWith((ref) => orderRepo),
          authRepositoryProvider.overrideWith((ref) {
            final repo = FakeAuthRepository(userAwal: SeedData.runner);
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Order Saya').last);
    await tester.pumpAndSettle();
  }

  testWidgets('tawaran yang sudah dikirim muncul di Order Saya', (
    tester,
  ) async {
    await bukaOrderSaya(tester, orderAwal: [permintaanDitawar()]);

    expect(find.text('Tawaranku (1)'), findsOneWidget);
    expect(find.text('SRH-9101'), findsOneWidget);
  });

  /// Angka terbesar di kartu ini harga yang RUNNER tawarkan, bukan harga order:
  /// permintaan Jalur B yang masih menerima tawaran memang belum punya harga.
  testWidgets('kartunya menyorot harga yang ditawarkan runner', (tester) async {
    await bukaOrderSaya(tester, orderAwal: [permintaanDitawar()]);

    expect(find.text('Kamu menawar'), findsOneWidget);
    expect(find.textContaining('50.000'), findsWidgets);
  });

  /// Satu-satunya petunjuk bahwa ada pesan menunggu di chatnya.
  testWidgets('tawaran yang diminta dihitung ulang mengatakannya', (
    tester,
  ) async {
    await bukaOrderSaya(
      tester,
      orderAwal: [permintaanDitawar(status: OfferStatus.dinegoUlang)],
    );

    expect(find.textContaining('Klien minta dihitung ulang'), findsOneWidget);
  });

  /// Harga ordernya sudah ditetapkan dari tawaran ini dan klien mungkin sedang
  /// membayarnya, jadi tombolnya tidak ada sama sekali — bukan ada lalu dijawab galat.
  testWidgets('tawaran yang sudah disetujui tidak menawarkan tarik', (
    tester,
  ) async {
    await bukaOrderSaya(
      tester,
      orderAwal: [permintaanDitawar(status: OfferStatus.disetujui)],
    );

    expect(find.textContaining('Tawaranmu dipilih'), findsOneWidget);
    expect(find.text('Tarik tawaran'), findsNothing);
  });

  testWidgets('menarik tawaran boleh tanpa menulis alasan', (tester) async {
    await bukaOrderSaya(tester, orderAwal: [permintaanDitawar()]);

    await tester.tap(find.text('Tarik tawaran'));
    await tester.pumpAndSettle();

    // Tombolnya hidup sejak awal, tidak menunggu kolomnya diisi. Alasan yang paling
    // sering sebenarnya cuma "salah ketik"; memaksanya diketik tidak menolong siapa pun.
    final tombol = find.widgetWithText(TextButton, 'Tarik tawaran').last;
    expect(tester.widget<TextButton>(tombol).onPressed, isNotNull);

    await tester.tap(tombol);
    await tester.pumpAndSettle();

    expect(find.text('Tawaranku (1)'), findsNothing);
  });

  testWidgets('tombol tarik terkunci selama request berjalan', (tester) async {
    await bukaOrderSaya(tester, orderAwal: [permintaanDitawar()]);

    await tester.tap(find.text('Tarik tawaran'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Tarik tawaran').last);
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextButton && widget.onPressed == null,
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  });

  // Keadaan tersimpannya -- statusnya jadi Dicabut, dan alasannya masuk chat -- diuji di
  // `test/data/cabut_penawaran_test.dart`, bukan di sini. Menunggu aliran repository di
  // dalam tes widget menggantung sampai batas waktu: jam di lingkungan itu tidak maju
  // sendiri, dan repository tiruan menirukan jeda jaringan. Pelajaran yang sama dengan
  // saat runner melepas order.

  testWidgets('runner tanpa tawaran tidak melihat bagian itu sama sekali', (
    tester,
  ) async {
    await bukaOrderSaya(tester, orderAwal: const []);

    expect(find.textContaining('Tawaranku'), findsNothing);
  });

  Future<void> bukaLayarAjukanTawaran(
    WidgetTester tester, {
    required FakeOrderRepository orderRepo,
    String orderId = 'o-tawar-uji',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          orderRepositoryProvider.overrideWith((ref) => orderRepo),
          authRepositoryProvider.overrideWith((ref) {
            final repo = FakeAuthRepository(userAwal: SeedData.runner);
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.terang(),
          home: AjukanTawaranScreen(orderId: orderId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan formulir penawaran dengan harga usulan klien', (
    tester,
  ) async {
    final order = permintaanDitawar();
    final repo = FakeOrderRepository(
      pemanggil: () => SeedData.runner.id,
      orderAwal: [order],
    );
    addTearDown(repo.dispose);

    await bukaLayarAjukanTawaran(tester, orderRepo: repo, orderId: order.id);

    expect(find.text('Ajukan Tawaran'), findsOneWidget);
    expect(find.text('Bersih-Bersih Kos'), findsOneWidget);
    expect(find.text('Kos dua kamar.'), findsOneWidget);
    expect(find.text('150000'), findsOneWidget);
    expect(find.text('Kirim Tawaran'), findsOneWidget);
  });

  testWidgets('menampilkan pesan kosong dan tombol coba lagi saat pemuatan gagal', (
    tester,
  ) async {
    final order = permintaanDitawar();
    final repo = _RepoGagalSekaliTawar(
      pemanggil: () => SeedData.runner.id,
      orderAwal: [order],
    );
    addTearDown(repo.dispose);

    await bukaLayarAjukanTawaran(tester, orderRepo: repo, orderId: order.id);

    expect(find.text('Order gagal dimuat'), findsOneWidget);
    expect(
      find.text('Tidak bisa menghubungi server. Periksa koneksimu.'),
      findsOneWidget,
    );
    expect(find.text('Coba lagi'), findsOneWidget);

    repo.gagal = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Bersih-Bersih Kos'), findsOneWidget);
    expect(find.text('Kirim Tawaran'), findsOneWidget);
  });

  testWidgets('menampilkan pesan fallback ketika error bukan GalatApi', (
    tester,
  ) async {
    final order = permintaanDitawar();
    final repo = _RepoGagalNonApiTawar(
      pemanggil: () => SeedData.runner.id,
      orderAwal: [order],
    );
    addTearDown(repo.dispose);

    await bukaLayarAjukanTawaran(tester, orderRepo: repo, orderId: order.id);

    expect(find.text('Order gagal dimuat'), findsOneWidget);
    expect(find.text('Sambungan ke server terputus.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('menampilkan pesan kosong saat order tidak ditemukan', (
    tester,
  ) async {
    final repo = FakeOrderRepository(
      pemanggil: () => SeedData.runner.id,
      orderAwal: const [],
    );
    addTearDown(repo.dispose);

    await bukaLayarAjukanTawaran(tester, orderRepo: repo, orderId: 'tidak-ada');

    expect(find.text('Order tidak ditemukan'), findsOneWidget);
    expect(
      find.text('Permintaan ini mungkin sudah ditutup atau dibatalkan.'),
      findsOneWidget,
    );
  });

  testWidgets('menyembunyikan exception mentah saat kirim tawaran gagal', (
    tester,
  ) async {
    final order = permintaanDitawar();
    final repo = _RepoGagalKirimTawar(
      pemanggil: () => SeedData.runner.id,
      orderAwal: [order],
    );
    addTearDown(repo.dispose);

    await bukaLayarAjukanTawaran(tester, orderRepo: repo, orderId: order.id);

    await tester.tap(find.widgetWithText(FilledButton, 'Kirim Tawaran'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Tawaran gagal dikirim. Terjadi kendala sambungan atau server.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('RAHASIA_INTERNAL'), findsNothing);
  });
}

class _RepoGagalSekaliTawar extends FakeOrderRepository {
  _RepoGagalSekaliTawar({
    required super.pemanggil,
    required super.orderAwal,
  });

  bool gagal = true;

  @override
  Stream<Order?> watchOrder(
    String orderId, {
    int ukuranPesan = BatasHalaman.bawaan,
  }) {
    if (gagal) {
      return Stream<Order?>.error(const GalatJaringan());
    }
    return super.watchOrder(orderId, ukuranPesan: ukuranPesan);
  }
}

class _RepoGagalNonApiTawar extends FakeOrderRepository {
  _RepoGagalNonApiTawar({
    required super.pemanggil,
    required super.orderAwal,
  });

  @override
  Stream<Order?> watchOrder(
    String orderId, {
    int ukuranPesan = BatasHalaman.bawaan,
  }) {
    return Stream<Order?>.error(Exception('SOCKET_ERROR'));
  }
}

class _RepoGagalKirimTawar extends FakeOrderRepository {
  _RepoGagalKirimTawar({
    required super.pemanggil,
    required super.orderAwal,
  });

  @override
  Future<Order> buatPenawaran({
    required String orderId,
    required int harga,
    required Duration estimasiDurasi,
    required DateTime jadwalMulai,
    String? catatan,
  }) async {
    throw Exception('RAHASIA_INTERNAL_DATABASE_TIMEOUT');
  }
}

