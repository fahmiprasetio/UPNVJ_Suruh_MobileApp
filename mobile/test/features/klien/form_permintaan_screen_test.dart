import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';

import '../../support/tiruan.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding
        .ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding
        .ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<FakeOrderRepository> bukaForm(
    WidgetTester tester, {
    required String namaLayanan,
  }) async {
    final repo = FakeOrderRepository(orderAwal: const []);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          orderRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(namaLayanan));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> isiForm(
    WidgetTester tester, {
    String kebutuhan =
        'Pindah dari Kos Melati ke Kos Anggrek, sekitar 2 km. Barang: lemari '
        'plastik, 2 koper, dan sekardus buku. Maunya Sabtu pagi.',
    String alamat = 'Kos Anggrek, Jl. RS Fatmawati',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ceritakan kebutuhanmu'),
      kebutuhan,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Alamat'),
      alamat,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pintu Permintaan Lain sekarang membuka formnya', (tester) async {
    await bukaForm(tester, namaLayanan: 'Permintaan Lain');

    expect(find.widgetWithText(AppBar, 'Permintaan Lain'), findsOneWidget);
    expect(find.text('Kirim Permintaan'), findsOneWidget);
  });

  testWidgets('layanan Jalur B berkatalog memakai form yang sama', (
    tester,
  ) async {
    await bukaForm(tester, namaLayanan: 'Bantu Pindah Kos');

    expect(find.widgetWithText(AppBar, 'Bantu Pindah Kos'), findsOneWidget);
  });

  testWidgets('form Jalur B tidak menjanjikan harga apa pun', (tester) async {
    await bukaForm(tester, namaLayanan: 'Bersih-Bersih Kos');

    // Tidak ada total, tidak ada tombol bayar. Harga baru ada setelah admin
    // mengirim penawaran.
    expect(find.textContaining('Total'), findsNothing);
    expect(find.textContaining('Rp'), findsNothing);
    expect(
      find.textContaining('admin membacanya, lalu mengirim penawaran harga'),
      findsOneWidget,
    );
  });

  testWidgets('cerita yang terlalu pendek ditolak', (tester) async {
    await bukaForm(tester, namaLayanan: 'Permintaan Lain');
    await isiForm(tester, kebutuhan: 'tolong bantu');

    await tester.tap(find.widgetWithText(FilledButton, 'Kirim Permintaan'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ceritakan lebih lengkap'),
      findsOneWidget,
    );
  });

  testWidgets('permintaan terkirim jadi order berstatus Permintaan', (
    tester,
  ) async {
    final repo = await bukaForm(tester, namaLayanan: 'Bantu Pindah Kos');
    await isiForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Kirim Permintaan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tunggu penawaran admin'), findsOneWidget);

    final orders = (await repo.watchOrderKlienUntuk('u-klien-1').first).isi;
    expect(orders, hasLength(1));
    expect(orders.single.status, OrderStatus.permintaan);
    expect(orders.single.serviceType, ServiceType.bantuPindahKos);
    expect(orders.single.harga, isNull);
    expect(orders.single.jumlahRunnerDibutuhkan, 1);
  });

  testWidgets('jumlah runner yang dipilih ikut terkirim', (tester) async {
    final repo = await bukaForm(tester, namaLayanan: 'Bantu Pindah Kos');
    await isiForm(tester);

    await tester.tap(find.text('3 orang'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Kirim Permintaan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final orders = (await repo.watchOrderKlienUntuk('u-klien-1').first).isi;
    expect(orders.single.jumlahRunnerDibutuhkan, 3);
  });
}
