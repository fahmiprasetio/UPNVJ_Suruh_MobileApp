import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order_message.dart';
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

  /// Membuka aplikasi sebagai runner, masuk ke tab Order Saya, lalu membuka
  /// ruang chat order yang kodenya diberikan.
  Future<FakeOrderRepository> bukaChatRunner(
    WidgetTester tester,
    String kodeOrder,
  ) async {
    final orderRepo = FakeOrderRepository(pemanggil: () => SeedData.runner.id);
    addTearDown(orderRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

    await tester.tap(find.widgetWithText(NavigationBar, 'Order Saya'));
    await tester.pumpAndSettle();

    final kartu = find.ancestor(
      of: find.textContaining(kodeOrder),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: kartu, matching: find.textContaining('Chat Klien')),
    );
    await tester.pumpAndSettle();

    return orderRepo;
  }

  testWidgets('runner bisa membuka chat order yang sedang dikerjakan', (
    tester,
  ) async {
    await bukaChatRunner(tester, 'SRH-0410');

    expect(find.text('Chat Order'), findsOneWidget);
    expect(find.textContaining('SRH-0410'), findsWidgets);
    expect(find.text('Belum ada percakapan'), findsOneWidget);
    // Kalimat pembukanya ditulis untuk runner, bukan disalin dari sisi klien.
    expect(find.textContaining('Kabari klien'), findsOneWidget);
  });

  testWidgets('pesan runner tercatat atas nama runner, bukan klien', (
    tester,
  ) async {
    final repo = await bukaChatRunner(tester, 'SRH-0410');

    await tester.enterText(
      find.byType(TextField),
      'Ayamnya habis, saya ganti level 1 ya',
    );
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Ayamnya habis, saya ganti level 1 ya'), findsOneWidget);

    final order = await repo.watchOrder('o-2').first;
    expect(order!.messages.single.pengirim, MessageSender.runner);
  });

  testWidgets('chat order yang sudah selesai tetap bisa dibaca, tidak dibalas', (
    tester,
  ) async {
    await bukaChatRunner(tester, 'SRH-0398');

    expect(
      find.text('Order ini sudah ditutup, jadi chatnya ikut ditutup.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('jumlah pesan terbaca dari kartu order runner', (tester) async {
    // Pesannya ditanam lewat data awal, bukan lewat kirimPesan: jeda jaringan
    // palsu di repository tidak pernah jalan di luar pompa tester.
    final orders = SeedData.orderAwal()
        .map(
          (order) => order.id != 'o-2'
              ? order
              : order.copyWith(
                  messages: [
                    OrderMessage(
                      id: 'm-uji',
                      orderId: order.id,
                      pengirim: MessageSender.klien,
                      isi: 'Titip sendok plastik ya',
                      dikirimPada: DateTime.now(),
                    ),
                  ],
                ),
        )
        .toList();

    final repo = FakeOrderRepository(
      pemanggil: () => SeedData.runner.id,
      orderAwal: orders);
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWith((ref) => repo),
          authRepositoryProvider.overrideWith((ref) {
            final auth = FakeAuthRepository(userAwal: SeedData.runner);
            ref.onDispose(auth.dispose);
            return auth;
          }),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationBar, 'Order Saya'));
    await tester.pumpAndSettle();

    expect(find.text('Chat Klien (1)'), findsOneWidget);
  });
}
