import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/domain/enums.dart';

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

  Future<void> bukaChat(WidgetTester tester, String kodeOrder) async {
    await tester.pumpWidget(const ProviderScope(child: UpnvjSuruhApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Order Saya'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(kodeOrder));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat Order'));
    await tester.pumpAndSettle();
  }

  testWidgets('percakapan order Jalur B terbaca lengkap', (tester) async {
    await bukaChat(tester, 'SRH-0409');

    expect(find.textContaining('kosnya di lantai berapa'), findsOneWidget);
    expect(
      find.text('Kos lama lantai 2, tangga. Kos baru lantai 1.'),
      findsOneWidget,
    );
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('chat menempel pada ordernya, bukan berdiri sendiri', (
    tester,
  ) async {
    await bukaChat(tester, 'SRH-0409');

    // Kode order ikut tertulis di kepala layar supaya percakapan tidak pernah
    // kehilangan konteks.
    expect(find.textContaining('SRH-0409'), findsWidgets);
  });

  testWidgets('order tanpa percakapan menjelaskan gunanya', (tester) async {
    await bukaChat(tester, 'SRH-0411');

    expect(find.text('Belum ada percakapan'), findsOneWidget);
  });

  testWidgets('pesan terkirim langsung muncul di daftar', (tester) async {
    await bukaChat(tester, 'SRH-0411');

    await tester.enterText(
      find.byType(TextField),
      'Tolong tunggu di gerbang depan ya',
    );
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Tolong tunggu di gerbang depan ya'), findsOneWidget);
    expect(find.text('Belum ada percakapan'), findsNothing);
  });

  testWidgets('order yang sudah selesai tidak bisa dibalas lagi', (
    tester,
  ) async {
    await bukaChat(tester, 'SRH-0398');

    expect(
      find.text('Order ini sudah ditutup, jadi chatnya ikut ditutup.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  group('FakeOrderRepository.kirimPesan', () {
    test('pesan kosong ditolak', () async {
      final repo = FakeOrderRepository();
      addTearDown(repo.dispose);

      await expectLater(
        repo.kirimPesan(
          orderId: 'o-1',
          pengirim: MessageSender.klien,
          isi: '   ',
        ),
        throwsStateError,
      );
    });

    test('order yang sudah selesai menolak pesan baru', () async {
      final repo = FakeOrderRepository();
      addTearDown(repo.dispose);

      await expectLater(
        repo.kirimPesan(
          orderId: 'o-4',
          pengirim: MessageSender.klien,
          isi: 'Masih boleh nanya?',
        ),
        throwsStateError,
      );
    });

    test('pesan tersimpan urut sesuai waktu kirim', () async {
      final repo = FakeOrderRepository();
      addTearDown(repo.dispose);

      await repo.kirimPesan(
        orderId: 'o-1',
        pengirim: MessageSender.klien,
        isi: 'Pesan pertama',
      );
      final order = await repo.kirimPesan(
        orderId: 'o-1',
        pengirim: MessageSender.admin,
        isi: 'Pesan kedua',
      );

      expect(order.messages.map((m) => m.isi), [
        'Pesan pertama',
        'Pesan kedua',
      ]);
      expect(order.messages.last.pengirim, MessageSender.admin);
      expect(order.messages.every((m) => m.orderId == 'o-1'), isTrue);
    });
  });
}
