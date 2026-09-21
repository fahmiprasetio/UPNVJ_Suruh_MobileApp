import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/core/api/galat_api.dart';
import 'package:upnvj_suruh/core/config/batas_halaman.dart';
import 'package:upnvj_suruh/core/theme/app_theme.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/features/runner/ajukan_tawaran/ajukan_tawaran_screen.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

import '../../support/tiruan.dart';

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

  Order permintaanJalurB({
    String id = 'o-tawar-uji',
    String kodeOrder = 'SRH-9901',
    int hargaUsulan = 75000,
  }) {
    return Order(
      id: id,
      kodeOrder: kodeOrder,
      klienId: SeedData.klien.id,
      namaKlien: SeedData.klien.nama,
      serviceType: ServiceType.bersihKos,
      status: OrderStatus.permintaan,
      dibuatPada: DateTime.now(),
      deskripsi: 'Bantu bersihkan kos lantai 2.',
      hargaUsulan: hargaUsulan,
      jumlahRunnerDibutuhkan: 1,
    );
  }

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
    final order = permintaanJalurB();
    final repo = FakeOrderRepository(
      pemanggil: () => SeedData.runner.id,
      orderAwal: [order],
    );
    addTearDown(repo.dispose);

    await bukaLayarAjukanTawaran(tester, orderRepo: repo, orderId: order.id);

    expect(find.text('Ajukan Tawaran'), findsOneWidget);
    expect(find.text('Bersih-Bersih Kos'), findsOneWidget);
    expect(find.text('Bantu bersihkan kos lantai 2.'), findsOneWidget);
    expect(find.text('75000'), findsOneWidget);
    expect(find.text('Kirim Tawaran'), findsOneWidget);
  });

  testWidgets('menampilkan pesan kosong dan tombol coba lagi saat pemuatan gagal', (
    tester,
  ) async {
    final order = permintaanJalurB();
    final repo = _RepoGagalSekali(
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
    final order = permintaanJalurB();
    final repo = _RepoGagalNonApi(
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
    final order = permintaanJalurB();
    final repo = _RepoGagalKirim(
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

class _RepoGagalSekali extends FakeOrderRepository {
  _RepoGagalSekali({
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

class _RepoGagalKirim extends FakeOrderRepository {
  _RepoGagalKirim({
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

class _RepoGagalNonApi extends FakeOrderRepository {
  _RepoGagalNonApi({
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

