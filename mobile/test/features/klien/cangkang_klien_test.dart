import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';

import '../../support/tiruan.dart';

/// Permukaan klien punya tiga tempat, dijangkau dari bilah bawah: Beranda,
/// Pesanan, Chat. Profil bukan tab di sini (bagian 83) -- pintunya pindah ke
/// pojok kanan atas beranda.
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

  Future<void> buka(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [sumberTiruan], child: const UpnvjSuruhApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('terbuka di beranda, dengan bilah bawah tiga tujuan', (
    tester,
  ) async {
    await buka(tester);

    expect(find.text('Mau disuruh apa hari ini?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Pesanan'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
  });

  testWidgets('tab Pesanan membuka riwayat', (tester) async {
    await buka(tester);

    await tester.tap(find.byTooltip('Pesanan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SRH-'), findsWidgets);
  });

  testWidgets('tab Chat membuka daftar percakapan', (tester) async {
    await buka(tester);

    await tester.tap(find.byTooltip('Chat'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Chat'), findsOneWidget);
  });

  testWidgets('beranda tidak dibuang saat berpindah tab', (tester) async {
    // Dipasang di IndexedStack, bukan ditukar. Berpindah tab yang membuang layar
    // berarti daftar dimuat ulang dari awal dan posisi gulungnya lompat ke atas
    // setiap kali pengguna mengintip sebelah.
    await buka(tester);

    await tester.tap(find.byTooltip('Pesanan'));
    await tester.pumpAndSettle();

    expect(find.text('Mau disuruh apa hari ini?', skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('order yang masih berjalan terhitung di tab Pesanan', (
    tester,
  ) async {
    // Yang paling sering terlupakan justru yang paling mendesak: order yang
    // menunggu dibayar berhenti di situ sampai ada yang membukanya lagi.
    await buka(tester);

    expect(find.byType(Badge), findsWidgets);
  });
}
